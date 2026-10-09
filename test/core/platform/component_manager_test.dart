import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/core/platform/component_manager.dart';
import 'package:hakkin_launcher/core/platform/os_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('hakkin_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('OsPaths - Tools & Component Paths', () {
    test('getToolsDirectory returns a subfolder named Tools inside app base directory', () async {
      final baseDir = await OsPaths.getAppBaseDirectory();
      final toolsDir = await OsPaths.getToolsDirectory();

      expect(toolsDir.path, p.join(baseDir.path, 'Tools'));
      expect(await toolsDir.exists(), isTrue);
    });

    test('getToolFile returns correct executable extension for tool name', () async {
      final file = await OsPaths.getToolFile('hpatchz');
      final expectedExt = Platform.isWindows ? '.exe' : '';
      expect(p.basename(file.path), 'hpatchz$expectedExt');
    });
  });

  group('ComponentManager - URL & Platform Resolution', () {
    test('getHpatchzDownloadUrl generates valid GitHub release download URL', () {
      final url = ComponentManager.getHpatchzDownloadUrl();
      expect(url, isNotEmpty);
      expect(url, startsWith('https://github.com/sisong/HDiffPatch/releases/download/'));
      expect(url, endsWith('.zip'));
    });
  });

  group('ComponentManager - Local Discovery & Extraction', () {
    test('findExistingHpatchz returns tool path if local binary exists', () async {
      final toolFile = await OsPaths.getToolFile('hpatchz');
      await toolFile.parent.create(recursive: true);
      await toolFile.writeAsString('dummy binary content');

      final found = await ComponentManager.instance.findExistingHpatchz();
      expect(found, isNotNull);
      expect(found, toolFile.path);

      // Limpieza
      await toolFile.delete();
    });

    test('getComponentStatus returns descriptive string', () async {
      final status = await ComponentManager.instance.getComponentStatus();
      expect(status, isNotEmpty);
      expect(status, anyOf(contains('Disponible'), contains('No instalado')));
    });

    test('downloadAndInstallHpatchz extracts binary from zip archive correctly with mock Dio', () async {
      final toolsDir = await OsPaths.getToolsDirectory();
      final targetExt = Platform.isWindows ? '.exe' : '';
      final targetFile = File(p.join(toolsDir.path, 'hpatchz$targetExt'));
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // Crear un archivo zip en memoria con un hpatchz dummy
      final archive = Archive();
      final binaryBytes = [0x7f, 0x45, 0x4c, 0x46, 0x01]; // ELF-like header
      final fileName = 'hpatchz$targetExt';
      archive.addFile(ArchiveFile(fileName, binaryBytes.length, binaryBytes));
      final zipBytes = ZipEncoder().encode(archive);

      // Crear mock adapter de Dio
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter(zipBytes);

      final manager = ComponentManager(dio: dio);
      final success = await manager.downloadAndInstallHpatchz();

      expect(success, isTrue);
      expect(await targetFile.exists(), isTrue);
      final readBytes = await targetFile.readAsBytes();
      expect(readBytes, binaryBytes);

      // Limpiar archivo de prueba
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final List<int> responseBytes;
  _MockHttpClientAdapter(this.responseBytes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      responseBytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/zip'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
