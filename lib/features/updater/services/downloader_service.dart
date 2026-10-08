import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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

/// Servicio de descarga de paquetes y parches con soporte para reanudación HTTP (Range) y métricas.
class DownloaderService {
  final Dio _dio;

  DownloaderService({Dio? dio}) : _dio = dio ?? Dio();

  /// Descarga un archivo con soporte para reanudación automática si se interrumpe la conexión.
  Future<File> downloadFile({
    required String url,
    required String destinationPath,
    required void Function(DownloadProgress progress) onProgress,
    CancelToken? cancelToken,
    bool allowResume = true,
    int maxRetries = 3,
  }) async {
    final destFile = File(destinationPath);
    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      try {
        int existingLength = 0;
        if (allowResume && await destFile.exists()) {
          existingLength = await destFile.length();
        }

        final stopwatch = Stopwatch()..start();
        int lastReceived = existingLength;
        double lastSpeed = 0.0;
        int lastCheckTime = 0;

        final options = Options(
          responseType: ResponseType.stream,
          headers: (allowResume && existingLength > 0)
              ? {'Range': 'bytes=$existingLength-'}
              : null,
        );

        final response = await _dio.get<ResponseBody>(
          url,
          options: options,
          cancelToken: cancelToken,
        );

        final responseStream = response.data?.stream;
        if (responseStream == null) {
          throw const FileSystemException('Respuesta de descarga vacía');
        }

        final statusCode = response.statusCode ?? 200;
        final isPartial = statusCode == 206;

        // Si el servidor devolvió 200 normal en lugar de 206, significa que no soporta Range o reinició
        final isAppending = isPartial && existingLength > 0;
        final fileMode = isAppending ? FileMode.append : FileMode.write;

        // Determinar tamaño total
        int totalLength = 0;
        final contentRange = response.headers.value('content-range');
        if (contentRange != null && contentRange.contains('/')) {
          final totalStr = contentRange.split('/').last.trim();
          totalLength = int.tryParse(totalStr) ?? 0;
        } else {
          final contentLength = response.headers.value('content-length');
          final length = int.tryParse(contentLength ?? '') ?? 0;
          totalLength = isAppending ? (existingLength + length) : length;
        }

        final sink = destFile.openWrite(mode: fileMode);
        int currentReceived = isAppending ? existingLength : 0;

        await for (final chunk in responseStream) {
          sink.add(chunk);
          currentReceived += chunk.length;

          final elapsedMs = stopwatch.elapsedMilliseconds;
          if (elapsedMs - lastCheckTime > 500) {
            final timeDiffSec = (elapsedMs - lastCheckTime) / 1000.0;
            final bytesDiff = currentReceived - lastReceived;
            lastSpeed = bytesDiff / timeDiffSec;
            lastReceived = currentReceived;
            lastCheckTime = elapsedMs;
          }

          final fraction = totalLength > 0
              ? (currentReceived / totalLength).clamp(0.0, 1.0)
              : 0.0;

          onProgress(
            DownloadProgress(
              receivedBytes: currentReceived,
              totalBytes: totalLength,
              progress: fraction,
              speedBytesPerSec: lastSpeed,
              statusText: totalLength > 0
                  ? '${(currentReceived / 1048576).toStringAsFixed(1)} MB de ${(totalLength / 1048576).toStringAsFixed(1)} MB'
                  : '${(currentReceived / 1048576).toStringAsFixed(1)} MB descargados',
            ),
          );
        }

        await sink.flush();
        await sink.close();

        return destFile;
      } catch (e) {
        if (cancelToken?.isCancelled ?? false) {
          rethrow;
        }
        debugPrint('Intento $attempt de descarga falló: $e');
        if (attempt >= maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    return destFile;
  }
}
