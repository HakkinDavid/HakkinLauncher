import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';
import 'package:hakkin_launcher/features/catalog/presentation/controllers/catalog_controller.dart';
import 'package:hakkin_launcher/features/library/data/models/installed_app.dart';
import 'package:hakkin_launcher/features/library/data/repositories/library_repository.dart';
import 'package:hakkin_launcher/features/library/presentation/controllers/library_controller.dart';
import 'package:hakkin_launcher/features/updater/services/downloader_service.dart';
import 'package:hakkin_launcher/features/updater/services/patch_engine.dart';

class FakeDownloaderService extends DownloaderService {
  @override
  Stream<DownloadProgress> downloadFileStream({
    required String url,
    required String destinationPath,
    CancelToken? cancelToken,
    bool allowResume = true,
    int maxRetries = 3,
  }) async* {
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    // Escribir un archivo binario simple (no ZIP) para prueba
    await file.writeAsString('dummy binary content for target release');
    yield const DownloadProgress(
      receivedBytes: 35,
      totalBytes: 35,
      progress: 1.0,
      speedBytesPerSec: 1000,
      statusText: 'Completado',
    );
  }
}

class FakeLibraryRepository extends LibraryRepository {
  final Map<String, InstalledApp> _installed = {};

  @override
  Future<List<InstalledApp>> getInstalledApps() async => _installed.values.toList();

  @override
  Future<InstalledApp?> getInstalledApp(String id) async => _installed[id];

  @override
  Future<void> saveInstalledApp(InstalledApp app) async {
    _installed[app.id] = app;
  }

  @override
  Future<bool> uninstallApp(String id, {bool deleteUserData = false}) async {
    return _installed.remove(id) != null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockBaseDir;

  setUpAll(() {
    mockBaseDir = Directory.systemTemp.createTempSync('hakkin_anomaly_mock_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return mockBaseDir.path;
    });
  });

  tearDownAll(() {
    if (mockBaseDir.existsSync()) {
      try {
        mockBaseDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Pruebas de Detección de Anomalías y Versiones Huérfanas en Cliente', () {
    late AppEntry testApp;
    late PlatformRelease winRelease;

    setUp(() {
      winRelease = PlatformRelease(
        latestVersion: '2.0.0',
        protectedUserPaths: ['userData.json'],
        versions: [
          const AppVersionRelease(
            version: '2.0.0',
            changelog: 'Versión 2.0.0 estable',
            executableRelativePath: 'test_app.exe',
            package: PackageArtifact(
              url: 'https://github.com/test/app/releases/download/v2.0.0/app.zip',
              sizeBytes: 1024,
              sha256: '', // Sin hash estricto para simulación
            ),
            deltaPatches: [
              DeltaUpdate(
                fromVersion: '1.0.0',
                toVersion: '2.0.0',
                patchFormat: 'hdiff',
                url: 'https://github.com/test/app/releases/download/v2.0.0/patch_1_to_2.hdiff',
                sizeBytes: 100,
                patchSha256: '',
                targetSha256: '',
              ),
            ],
            scripts: Scripts(),
          ),
          const AppVersionRelease(
            version: '1.0.0',
            changelog: 'Versión 1.0.0 inicial',
            executableRelativePath: 'test_app.exe',
            package: PackageArtifact(
              url: 'https://github.com/test/app/releases/download/v1.0.0/app.zip',
              sizeBytes: 900,
              sha256: '',
            ),
            deltaPatches: [],
            scripts: Scripts(),
          ),
        ],
      );

      testApp = AppEntry(
        id: 'com.test.anomalous_app',
        slug: 'anomalous-app',
        title: 'Anomalous Test App',
        category: 'app',
        developer: 'Hakkin',
        summary: 'App de prueba para anomalías',
        descriptionMarkdown: 'Descripción',
        tags: const ['test'],
        assets: const AppAssets(),
        latestVersion: '2.0.0',
        platforms: {
          'windows-x64': winRelease,
        },
      );
    });

    test('PlatformRelease detecta versiones válidas y anómalas correctamente', () {
      expect(winRelease.hasVersion('2.0.0'), isTrue);
      expect(winRelease.hasVersion('1.0.0'), isTrue);
      expect(winRelease.isAnomalousVersion('2.0.0'), isFalse);
      expect(winRelease.isAnomalousVersion('1.0.0'), isFalse);

      // Versión huérfana / inexistente en el catálogo
      expect(winRelease.hasVersion('0.0.1'), isFalse);
      expect(winRelease.isAnomalousVersion('0.0.1'), isTrue);
      expect(winRelease.isAnomalousVersion('64.0.0'), isTrue);
      expect(winRelease.isAnomalousVersion('ghost-version'), isTrue);
    });

    test('AppEntry.isAnomalousInstalledVersion y needsUpdate detectan anomalías', () {
      // Si la versión instalada es la última y válida, no necesita actualización
      expect(
        testApp.isAnomalousInstalledVersion('windows-x64', '2.0.0'),
        isFalse,
      );
      expect(
        testApp.needsUpdate(platformKey: 'windows-x64', installedVersion: '2.0.0'),
        isFalse,
      );

      // Si la versión instalada es válida pero anterior, necesita actualización pero no es anómala
      expect(
        testApp.isAnomalousInstalledVersion('windows-x64', '1.0.0'),
        isFalse,
      );
      expect(
        testApp.needsUpdate(platformKey: 'windows-x64', installedVersion: '1.0.0'),
        isTrue,
      );

      // Si la versión instalada no existe en el catálogo (anomalía / huérfana):
      expect(
        testApp.isAnomalousInstalledVersion('windows-x64', '0.0.1'),
        isTrue,
      );
      expect(
        testApp.needsUpdate(platformKey: 'windows-x64', installedVersion: '0.0.1'),
        isTrue,
      );
    });

    test('PatchEngine detecta versión huérfana/anómala y fuerza actualización completa', () async {
      final fakeLib = FakeLibraryRepository();
      final fakeDownloader = FakeDownloaderService();
      final tempDir = await Directory.systemTemp.createTemp('hakkin_anomaly_test_');

      try {
        final installDir = Directory('${tempDir.path}/app_dir');
        await installDir.create(recursive: true);
        final exeFile = File('${installDir.path}/test_app.exe');
        await exeFile.writeAsString('old executable code');

        // Archivo de usuario protegido
        final userFile = File('${installDir.path}/userData.json');
        await userFile.writeAsString('{"player": "Alice", "score": 100}');

        // Registrar app instalada con versión huérfana '0.0.1' (no existe en catálogo)
        final orphanInstalled = InstalledApp(
          id: testApp.id,
          title: testApp.title,
          installedVersion: '0.0.1',
          executablePath: exeFile.path,
          installDirectory: installDir.path,
          installedAt: DateTime.now(),
          platformKey: 'windows-x64',
        );
        await fakeLib.saveInstalledApp(orphanInstalled);

        final patchEngine = PatchEngine(
          downloader: fakeDownloader,
          libraryRepository: fakeLib,
        );

        final statuses = <UpdateStatus>[];
        await for (final status in patchEngine.installOrUpdate(
          app: testApp,
          platformKey: 'windows-x64',
          customInstallPath: installDir.path,
        )) {
          statuses.add(status);
        }

        // 1. Debe haber emitido etapa de preservación indicando la anomalía
        final anomalyStatus = statuses.firstWhere(
          (s) => s.message.contains('Anomalía detectada') || s.message.contains('huérfana'),
          orElse: () => const UpdateStatus(stage: UpdateStage.failed, message: 'no anomaly'),
        );
        expect(anomalyStatus.message, contains('Anomalía detectada'));
        expect(anomalyStatus.message, contains('actualización completa'));

        // 2. No debe haber emitido stage de applyingDelta
        final hasDelta = statuses.any((s) => s.stage == UpdateStage.applyingDelta);
        expect(hasDelta, isFalse, reason: 'Jamás debe aplicarse delta a una versión huérfana');

        // 3. La actualización debe haber completado con éxito
        final lastStatus = statuses.last;
        expect(lastStatus.stage, UpdateStage.completed);

        // 4. Los datos de usuario protegidos deben haberse preservado
        expect(await userFile.exists(), isTrue);
        final preservedContent = await userFile.readAsString();
        expect(preservedContent, contains('Alice'));

        // 5. La app instalada en la biblioteca debe reflejar la nueva versión válida
        final updatedApp = await fakeLib.getInstalledApp(testApp.id);
        expect(updatedApp, isNotNull);
        expect(updatedApp!.installedVersion, '2.0.0');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('LibraryController.verifyAppIntegrity reporta anomalía si versión no está en catálogo', () async {
      final fakeLib = FakeLibraryRepository();
      final tempDir = await Directory.systemTemp.createTemp('hakkin_integrity_test_');

      try {
        final exeFile = File('${tempDir.path}/test_app.exe');
        await exeFile.writeAsString('content');

        final orphanApp = InstalledApp(
          id: testApp.id,
          title: testApp.title,
          installedVersion: '99.9.9-ghost', // Versión huérfana
          executablePath: exeFile.path,
          installDirectory: tempDir.path,
          installedAt: DateTime.now(),
          platformKey: 'windows-x64',
        );
        await fakeLib.saveInstalledApp(orphanApp);

        final container = ProviderContainer(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(fakeLib),
            catalogManifestProvider.overrideWith(
              (ref) => CatalogManifest(
                version: '2.0.0',
                catalogTimestamp: '2026-10-09T00:00:00Z',
                apps: [testApp],
              ),
            ),
          ],
        );

        final notifier = container.read(installedAppsProvider.notifier);
        final result = await notifier.verifyAppIntegrity(orphanApp.id);

        expect(result['isValid'], isFalse);
        expect(result['isAnomalous'], isTrue);
        expect(result['message'], contains('Anomalía'));
        expect(result['message'], contains('actualización completa'));
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
