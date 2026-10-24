import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';
import 'package:hakkin_launcher/features/library/data/models/installed_app.dart';
import 'package:hakkin_launcher/features/library/data/repositories/library_repository.dart';
import 'package:hakkin_launcher/features/updater/services/downloader_service.dart';
import 'package:hakkin_launcher/features/updater/services/patch_engine.dart';

class MockDownloaderService extends DownloaderService {
  final List<String> downloadedUrls = [];
  bool simulateDownloadFailure = false;

  @override
  Stream<DownloadProgress> downloadFileStream({
    required String url,
    required String destinationPath,
    CancelToken? cancelToken,
    bool allowResume = true,
    int maxRetries = 3,
  }) async* {
    if (simulateDownloadFailure) {
      throw Exception('Simulated network error during download');
    }
    downloadedUrls.add(url);
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('mock package or patch content for $url');
    yield const DownloadProgress(
      receivedBytes: 100,
      totalBytes: 100,
      progress: 1.0,
      speedBytesPerSec: 1000,
      statusText: 'Completado',
    );
  }
}

class MockLibraryRepository extends LibraryRepository {
  final Map<String, InstalledApp> installedApps = {};

  @override
  Future<List<InstalledApp>> getInstalledApps() async => installedApps.values.toList();

  @override
  Future<InstalledApp?> getInstalledApp(String id) async => installedApps[id];

  @override
  Future<void> saveInstalledApp(InstalledApp app) async {
    installedApps[app.id] = app;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('hakkin_delta_chain_test_');
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

  group('findOptimalDeltaChain Algorithmic Tests', () {
    late PlatformRelease platformRelease;

    setUp(() {
      // Configuramos versiones:
      // v1.0.0 (paquete: 1000)
      // v1.1.0 (paquete: 1100), deltas: 1.0.0 -> 1.1.0 (size: 100)
      // v1.2.0 (paquete: 1200), deltas: 1.1.0 -> 1.2.0 (size: 150), 1.0.0 -> 1.2.0 (size: 400)
      // v1.3.0 (paquete: 1500), deltas: 1.2.0 -> 1.3.0 (size: 200)
      platformRelease = const PlatformRelease(
        latestVersion: '1.3.0',
        versions: [
          AppVersionRelease(
            version: '1.3.0',
            entryPoint: 'app.exe',
            package: PackageArtifact(
              url: 'https://example.com/v1.3.0.zip',
              sizeBytes: 1500,
              sha256: '',
            ),
            deltaPatches: [
              DeltaUpdate(
                fromVersion: '1.2.0',
                toVersion: '1.3.0',
                patchFormat: 'hdiff',
                url: 'https://example.com/patch_1.2.0_to_1.3.0.hdiff',
                sizeBytes: 200,
                patchSha256: '',
                targetSha256: '',
              ),
            ],
          ),
          AppVersionRelease(
            version: '1.2.0',
            entryPoint: 'app.exe',
            package: PackageArtifact(
              url: 'https://example.com/v1.2.0.zip',
              sizeBytes: 1200,
              sha256: '',
            ),
            deltaPatches: [
              DeltaUpdate(
                fromVersion: '1.1.0',
                toVersion: '1.2.0',
                patchFormat: 'hdiff',
                url: 'https://example.com/patch_1.1.0_to_1.2.0.hdiff',
                sizeBytes: 150,
                patchSha256: '',
                targetSha256: '',
              ),
              DeltaUpdate(
                fromVersion: '1.0.0',
                toVersion: '1.2.0',
                patchFormat: 'hdiff',
                url: 'https://example.com/patch_1.0.0_to_1.2.0.hdiff',
                sizeBytes: 400,
                patchSha256: '',
                targetSha256: '',
              ),
            ],
          ),
          AppVersionRelease(
            version: '1.1.0',
            entryPoint: 'app.exe',
            package: PackageArtifact(
              url: 'https://example.com/v1.1.0.zip',
              sizeBytes: 1100,
              sha256: '',
            ),
            deltaPatches: [
              DeltaUpdate(
                fromVersion: '1.0.0',
                toVersion: '1.1.0',
                patchFormat: 'hdiff',
                url: 'https://example.com/patch_1.0.0_to_1.1.0.hdiff',
                sizeBytes: 100,
                patchSha256: '',
                targetSha256: '',
              ),
            ],
          ),
          AppVersionRelease(
            version: '1.0.0',
            entryPoint: 'app.exe',
            package: PackageArtifact(
              url: 'https://example.com/v1.0.0.zip',
              sizeBytes: 1000,
              sha256: '',
            ),
            deltaPatches: [],
          ),
        ],
      );
    });

    test('Selecciona el parche directo de un solo salto si es el camino óptimo', () {
      final chain = platformRelease.findOptimalDeltaChain('1.0.0', '1.1.0');
      expect(chain, isNotNull);
      expect(chain!.length, 1);
      expect(chain.first.fromVersion, '1.0.0');
      expect(chain.first.toVersion, '1.1.0');
      expect(chain.first.sizeBytes, 100);
    });

    test('Prefiere encadenar parches cuando la suma de la cadena es menor al parche directo', () {
      // De 1.0.0 a 1.2.0:
      // Parche directo: 400 bytes
      // Cadena 1.0.0 -> 1.1.0 (100) + 1.1.0 -> 1.2.0 (150) = 250 bytes
      // Como 250 < 400, debe seleccionar la cadena de 2 pasos
      final chain = platformRelease.findOptimalDeltaChain(
        '1.0.0',
        '1.2.0',
        maxTransferBytes: 1200,
      );

      expect(chain, isNotNull);
      expect(chain!.length, 2);
      expect(chain[0].fromVersion, '1.0.0');
      expect(chain[0].toVersion, '1.1.0');
      expect(chain[1].fromVersion, '1.1.0');
      expect(chain[1].toVersion, '1.2.0');

      final totalBytes = chain.fold<int>(0, (sum, d) => sum + d.sizeBytes);
      expect(totalBytes, 250);
      expect(totalBytes < 400, isTrue);
    });

    test('Encadena múltiples saltos (3 pasos) cuando no existe parche directo hacia la más reciente', () {
      // De 1.0.0 a 1.3.0:
      // No existe parche directo 1.0.0 -> 1.3.0 ni 1.1.0 -> 1.3.0.
      // Camino: 1.0.0 -> 1.1.0 (100) -> 1.2.0 (150) -> 1.3.0 (200) = 450 bytes.
      // Camino alternativo usando directo 1.0.0 -> 1.2.0 (400) + 1.2.0 -> 1.3.0 (200) = 600 bytes.
      // Debe seleccionar el de menor costo total: 450 bytes.
      final chain = platformRelease.findOptimalDeltaChain(
        '1.0.0',
        '1.3.0',
        maxTransferBytes: 1500,
      );

      expect(chain, isNotNull);
      expect(chain!.length, 3);
      expect(chain[0].fromVersion, '1.0.0');
      expect(chain[0].toVersion, '1.1.0');
      expect(chain[1].fromVersion, '1.1.0');
      expect(chain[1].toVersion, '1.2.0');
      expect(chain[2].fromVersion, '1.2.0');
      expect(chain[2].toVersion, '1.3.0');

      final totalBytes = chain.fold<int>(0, (sum, d) => sum + d.sizeBytes);
      expect(totalBytes, 450);
      expect(totalBytes < 1500, isTrue);
    });

    test('Rechaza la estrategia de parches si el tamaño de transferencia total no es menor al paquete completo', () {
      // Supongamos que el paquete completo de 1.3.0 mide sólo 400 bytes.
      // La cadena óptima mide 450 bytes.
      // Como 450 >= 400, no resulta en menor transferencia; debe retornar null.
      final chain = platformRelease.findOptimalDeltaChain(
        '1.0.0',
        '1.3.0',
        maxTransferBytes: 400,
      );

      expect(chain, isNull);
    });

    test('Rechaza la estrategia si el tamaño de la cadena es exactamente igual al paquete completo', () {
      final chain = platformRelease.findOptimalDeltaChain(
        '1.0.0',
        '1.3.0',
        maxTransferBytes: 450,
      );

      expect(chain, isNull);
    });

    test('Retorna lista vacía si la versión instalada es idéntica a la objetivo', () {
      final chain = platformRelease.findOptimalDeltaChain('1.3.0', '1.3.0');
      expect(chain, isEmpty);
    });

    test('Retorna null si la versión instalada es huérfana o no existe en el catálogo', () {
      final chain = platformRelease.findOptimalDeltaChain('0.9.9-orphan', '1.3.0');
      expect(chain, isNull);
    });

    test('Maneja ciclos en el grafo sin caer en bucles infinitos y selecciona el camino óptimo', () {
      const releaseWithCycle = PlatformRelease(
        latestVersion: '2.0.0',
        versions: [
          AppVersionRelease(
            version: '2.0.0',
            entryPoint: 'app',
            package: PackageArtifact(url: '', sizeBytes: 1000, sha256: ''),
            deltaPatches: [
              DeltaUpdate(
                fromVersion: '1.5.0',
                toVersion: '2.0.0',
                patchFormat: 'hdiff',
                url: '',
                sizeBytes: 100,
                patchSha256: '',
                targetSha256: '',
              ),
            ],
          ),
          AppVersionRelease(
            version: '1.5.0',
            entryPoint: 'app',
            package: PackageArtifact(url: '', sizeBytes: 800, sha256: ''),
            deltaPatches: [
              DeltaUpdate(
                fromVersion: '1.0.0',
                toVersion: '1.5.0',
                patchFormat: 'hdiff',
                url: '',
                sizeBytes: 200,
                patchSha256: '',
                targetSha256: '',
              ),
              // Ciclo de regreso: 1.5.0 -> 1.0.0
              DeltaUpdate(
                fromVersion: '1.5.0',
                toVersion: '1.0.0',
                patchFormat: 'hdiff',
                url: '',
                sizeBytes: 50,
                patchSha256: '',
                targetSha256: '',
              ),
            ],
          ),
          AppVersionRelease(
            version: '1.0.0',
            entryPoint: 'app',
            package: PackageArtifact(url: '', sizeBytes: 500, sha256: ''),
            deltaPatches: [],
          ),
        ],
      );

      final chain = releaseWithCycle.findOptimalDeltaChain('1.0.0', '2.0.0');
      expect(chain, isNotNull);
      expect(chain!.length, 2);
      expect(chain[0].fromVersion, '1.0.0');
      expect(chain[0].toVersion, '1.5.0');
      expect(chain[1].fromVersion, '1.5.0');
      expect(chain[1].toVersion, '2.0.0');
    });

    test('Retorna null cuando las versiones están desconectadas sin camino de parches', () {
      const releaseDisconnected = PlatformRelease(
        latestVersion: '3.0.0',
        versions: [
          AppVersionRelease(
            version: '3.0.0',
            entryPoint: 'app',
            package: PackageArtifact(url: '', sizeBytes: 1000, sha256: ''),
            deltaPatches: [], // Sin parches hacia 3.0.0
          ),
          AppVersionRelease(
            version: '1.0.0',
            entryPoint: 'app',
            package: PackageArtifact(url: '', sizeBytes: 500, sha256: ''),
            deltaPatches: [],
          ),
        ],
      );

      final chain = releaseDisconnected.findOptimalDeltaChain('1.0.0', '3.0.0');
      expect(chain, isNull);
    });
  });

  group('PatchEngine Patch Chaining Execution Tests', () {
    late AppEntry testApp;
    late MockDownloaderService mockDownloader;
    late MockLibraryRepository mockRepo;
    late PatchEngine patchEngine;

    setUp(() {
      mockDownloader = MockDownloaderService();
      mockRepo = MockLibraryRepository();
      patchEngine = PatchEngine(
        downloader: mockDownloader,
        libraryRepository: mockRepo,
        patchApplier: ({
          required File patchFile,
          required Directory targetDirectory,
          required String entryPoint,
        }) async {
          final exe = File('${targetDirectory.path}/$entryPoint');
          await exe.parent.create(recursive: true);
          await exe.writeAsString('patched binary content');
          return true;
        },
      );

      // Creamos una app con versiones 1.0.0 -> 1.1.0 -> 1.2.0
      // Paquete 1.2.0: 50000 bytes
      // Parche 1.0.0 -> 1.1.0: 2000 bytes
      // Parche 1.1.0 -> 1.2.0: 3000 bytes
      // Total cadena: 5000 bytes (< 50000 bytes)
      testApp = const AppEntry(
        id: 'dev.bonsanbec.chain-app',
        slug: 'chain-app',
        title: 'Aplicación de prueba encadenada',
        category: 'app',
        developer: 'Bonsanbec',
        summary: 'Resumen',
        descriptionMarkdown: '',
        tags: [],
        assets: AppAssets(),
        latestVersion: '1.2.0',
        platforms: {
          'windows-x64': PlatformRelease(
            latestVersion: '1.2.0',
            versions: [
              AppVersionRelease(
                version: '1.2.0',
                entryPoint: 'chain_app.exe',
                package: PackageArtifact(
                  url: 'https://example.com/full_1.2.0.zip',
                  sizeBytes: 50000,
                  sha256: '',
                ),
                deltaPatches: [
                  DeltaUpdate(
                    fromVersion: '1.1.0',
                    toVersion: '1.2.0',
                    patchFormat: 'hdiff',
                    url: 'https://example.com/patch_1.1.0_to_1.2.0.hdiff',
                    sizeBytes: 3000,
                    patchSha256: '',
                    targetSha256: '',
                  ),
                ],
              ),
              AppVersionRelease(
                version: '1.1.0',
                entryPoint: 'chain_app.exe',
                package: PackageArtifact(
                  url: 'https://example.com/full_1.1.0.zip',
                  sizeBytes: 48000,
                  sha256: '',
                ),
                deltaPatches: [
                  DeltaUpdate(
                    fromVersion: '1.0.0',
                    toVersion: '1.1.0',
                    patchFormat: 'hdiff',
                    url: 'https://example.com/patch_1.0.0_to_1.1.0.hdiff',
                    sizeBytes: 2000,
                    patchSha256: '',
                    targetSha256: '',
                  ),
                ],
              ),
              AppVersionRelease(
                version: '1.0.0',
                entryPoint: 'chain_app.exe',
                package: PackageArtifact(
                  url: 'https://example.com/full_1.0.0.zip',
                  sizeBytes: 45000,
                  sha256: '',
                ),
                deltaPatches: [],
              ),
            ],
          ),
        },
      );
    });

    test('Ejecuta la actualización descargando los parches encadenados en lugar del paquete completo', () async {
      // Simulamos que la app está instalada en v1.0.0
      await mockRepo.saveInstalledApp(InstalledApp(
        id: testApp.id,
        title: testApp.title,
        installedVersion: '1.0.0',
        executablePath: '${tempDir.path}/chain_app.exe',
        installDirectory: tempDir.path,
        installedAt: DateTime.now(),
        platformKey: 'windows-x64',
      ));

      final statuses = <UpdateStatus>[];
      await for (final status in patchEngine.installOrUpdate(
        app: testApp,
        platformKey: 'windows-x64',
        targetVersion: '1.2.0',
      )) {
        statuses.add(status);
      }

      // Verificamos que se descargaron los 2 parches de la cadena
      expect(mockDownloader.downloadedUrls, contains('https://example.com/patch_1.0.0_to_1.1.0.hdiff'));
      expect(mockDownloader.downloadedUrls, contains('https://example.com/patch_1.1.0_to_1.2.0.hdiff'));
      // No debe haberse descargado el paquete completo de 50 KB
      expect(mockDownloader.downloadedUrls, isNot(contains('https://example.com/full_1.2.0.zip')));

      final finalStatus = statuses.last;
      expect(finalStatus.stage, UpdateStage.completed);

      final updatedApp = await mockRepo.getInstalledApp(testApp.id);
      expect(updatedApp?.installedVersion, '1.2.0');
    });

    test('Descarga paquete completo si la cadena de parches superaría el tamaño del paquete', () async {
      // Modificamos el paquete de 1.2.0 para que pese sólo 4000 bytes (menor que la suma de 5000 bytes de la cadena)
      final tinyPackageApp = AppEntry(
        id: testApp.id,
        slug: testApp.slug,
        title: testApp.title,
        category: testApp.category,
        developer: testApp.developer,
        summary: testApp.summary,
        descriptionMarkdown: testApp.descriptionMarkdown,
        tags: testApp.tags,
        assets: testApp.assets,
        latestVersion: testApp.latestVersion,
        platforms: {
          'windows-x64': PlatformRelease(
            latestVersion: '1.2.0',
            versions: [
              const AppVersionRelease(
                version: '1.2.0',
                entryPoint: 'chain_app.exe',
                package: PackageArtifact(
                  url: 'https://example.com/full_1.2.0.zip',
                  sizeBytes: 4000, // Menor que 2000 + 3000 = 5000 bytes de los parches
                  sha256: '',
                ),
                deltaPatches: [
                  DeltaUpdate(
                    fromVersion: '1.1.0',
                    toVersion: '1.2.0',
                    patchFormat: 'hdiff',
                    url: 'https://example.com/patch_1.1.0_to_1.2.0.hdiff',
                    sizeBytes: 3000,
                    patchSha256: '',
                    targetSha256: '',
                  ),
                ],
              ),
              testApp.platforms['windows-x64']!.versions[1],
              testApp.platforms['windows-x64']!.versions[2],
            ],
          ),
        },
      );

      await mockRepo.saveInstalledApp(InstalledApp(
        id: testApp.id,
        title: testApp.title,
        installedVersion: '1.0.0',
        executablePath: '${tempDir.path}/chain_app.exe',
        installDirectory: tempDir.path,
        installedAt: DateTime.now(),
        platformKey: 'windows-x64',
      ));

      final statuses = <UpdateStatus>[];
      await for (final status in patchEngine.installOrUpdate(
        app: tinyPackageApp,
        platformKey: 'windows-x64',
        targetVersion: '1.2.0',
      )) {
        statuses.add(status);
      }

      // Al no resultar en menor transferencia, debió descargar directamente el paquete completo
      expect(mockDownloader.downloadedUrls, contains('https://example.com/full_1.2.0.zip'));
      expect(mockDownloader.downloadedUrls, isNot(contains('https://example.com/patch_1.0.0_to_1.1.0.hdiff')));
      expect(mockDownloader.downloadedUrls, isNot(contains('https://example.com/patch_1.1.0_to_1.2.0.hdiff')));

      final finalStatus = statuses.last;
      expect(finalStatus.stage, UpdateStage.completed);

      final updatedApp = await mockRepo.getInstalledApp(testApp.id);
      expect(updatedApp?.installedVersion, '1.2.0');
    });

    test('Activa respaldo de descarga completa si la descarga de algún parche de la cadena falla', () async {
      await mockRepo.saveInstalledApp(InstalledApp(
        id: testApp.id,
        title: testApp.title,
        installedVersion: '1.0.0',
        executablePath: '${tempDir.path}/chain_app.exe',
        installDirectory: tempDir.path,
        installedAt: DateTime.now(),
        platformKey: 'windows-x64',
      ));

      // Simulamos que la primera descarga (del parche) arroja error, pero la siguiente funciona
      var attempt = 0;
      mockDownloader = MockDownloaderWithFirstFailure(onAttempt: () => attempt++);
      patchEngine = PatchEngine(
        downloader: mockDownloader,
        libraryRepository: mockRepo,
      );

      final statuses = <UpdateStatus>[];
      await for (final status in patchEngine.installOrUpdate(
        app: testApp,
        platformKey: 'windows-x64',
        targetVersion: '1.2.0',
      )) {
        statuses.add(status);
      }

      // Debe haberse recurrido al paquete completo como respaldo
      expect(mockDownloader.downloadedUrls, contains('https://example.com/full_1.2.0.zip'));
      expect(statuses.last.stage, UpdateStage.completed);
    });
  });
}

class MockDownloaderWithFirstFailure extends MockDownloaderService {
  final VoidCallback onAttempt;
  int calls = 0;

  MockDownloaderWithFirstFailure({required this.onAttempt});

  @override
  Stream<DownloadProgress> downloadFileStream({
    required String url,
    required String destinationPath,
    CancelToken? cancelToken,
    bool allowResume = true,
    int maxRetries = 3,
  }) async* {
    calls++;
    onAttempt();
    if (calls == 1) {
      throw Exception('Network glitch on first patch');
    }
    yield* super.downloadFileStream(
      url: url,
      destinationPath: destinationPath,
      cancelToken: cancelToken,
      allowResume: allowResume,
      maxRetries: maxRetries,
    );
  }
}
