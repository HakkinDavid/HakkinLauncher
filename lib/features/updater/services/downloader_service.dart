import 'dart:io';
import 'package:dio/dio.dart';

/// Estado de progreso de una descarga activa.
class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress; // 0.0 a 1.0
  final double speedBytesPerSec;
  final String statusText;

  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
    required this.speedBytesPerSec,
    required this.statusText,
  });

  String get speedFormatted {
    if (speedBytesPerSec <= 0) return '';
    final mb = speedBytesPerSec / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB/s';
  }

  String get percentageFormatted => '${(progress * 100).toStringAsFixed(1)}%';
}

/// Servicio de descarga de paquetes y parches con soporte para métricas y cancelación.
class DownloaderService {
  final Dio _dio;

  DownloaderService({Dio? dio}) : _dio = dio ?? Dio();

  Future<File> downloadFile({
    required String url,
    required String destinationPath,
    required void Function(DownloadProgress progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final destFile = File(destinationPath);
    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    final stopwatch = Stopwatch()..start();
    int lastReceived = 0;
    double lastSpeed = 0.0;
    int lastCheckTime = 0;

    await _dio.download(
      url,
      destinationPath,
      cancelToken: cancelToken,
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        final elapsedMs = stopwatch.elapsedMilliseconds;
        if (elapsedMs - lastCheckTime > 500) {
          final timeDiffSec = (elapsedMs - lastCheckTime) / 1000.0;
          final bytesDiff = received - lastReceived;
          lastSpeed = bytesDiff / timeDiffSec;
          lastReceived = received;
          lastCheckTime = elapsedMs;
        }

        final fraction = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

        onProgress(
          DownloadProgress(
            receivedBytes: received,
            totalBytes: total,
            progress: fraction,
            speedBytesPerSec: lastSpeed,
            statusText: total > 0
                ? '${(received / 1048576).toStringAsFixed(1)} MB de ${(total / 1048576).toStringAsFixed(1)} MB'
                : '${(received / 1048576).toStringAsFixed(1)} MB descargados',
          ),
        );
      },
    );

    return destFile;
  }
}
