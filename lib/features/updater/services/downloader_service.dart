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

/// Servicio de descarga de paquetes y parches con soporte para reanudación HTTP y métricas.
class DownloaderService {
  final Dio _dio;

  DownloaderService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  /// Transmite el progreso de la descarga en tiempo real como Stream.
  Stream<DownloadProgress> downloadFileStream({
    required String url,
    required String destinationPath,
    CancelToken? cancelToken,
    bool allowResume = true,
    int maxRetries = 3,
  }) async* {
    final destFile = File(destinationPath);
    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      IOSink? sink;
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
          followRedirects: true,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        );

        final response = await _dio.get<ResponseBody>(
          url,
          options: options,
          cancelToken: cancelToken,
        );

        final statusCode = response.statusCode ?? 200;
        if (statusCode == 416) {
          // Rango no satisfecho; reiniciar archivo limpio
          if (await destFile.exists()) {
            await destFile.delete();
          }
          existingLength = 0;
          continue;
        }

        final responseStream = response.data?.stream;
        if (responseStream == null) {
          throw const FileSystemException('Respuesta de descarga vacía');
        }

        final isPartial = statusCode == 206;

        // Si el servidor devolvió 200 normal en lugar de 206, reinicia desde cero
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

        sink = destFile.openWrite(mode: fileMode);
        int currentReceived = isAppending ? existingLength : 0;

        // Emitir progreso inicial al comenzar
        yield DownloadProgress(
          receivedBytes: currentReceived,
          totalBytes: totalLength,
          progress: totalLength > 0
              ? (currentReceived / totalLength).clamp(0.0, 1.0)
              : 0.0,
          speedBytesPerSec: 0.0,
          statusText: totalLength > 0
              ? '${(currentReceived / 1048576).toStringAsFixed(1)} MB de ${(totalLength / 1048576).toStringAsFixed(1)} MB'
              : '${(currentReceived / 1048576).toStringAsFixed(1)} MB descargados',
        );

        await for (final chunk in responseStream) {
          sink.add(chunk);
          currentReceived += chunk.length;

          final elapsedMs = stopwatch.elapsedMilliseconds;
          if (elapsedMs - lastCheckTime >= 250) {
            final timeDiffSec = (elapsedMs - lastCheckTime) / 1000.0;
            final bytesDiff = currentReceived - lastReceived;
            lastSpeed = timeDiffSec > 0 ? (bytesDiff / timeDiffSec) : 0.0;
            lastReceived = currentReceived;
            lastCheckTime = elapsedMs;

            final fraction = totalLength > 0
                ? (currentReceived / totalLength).clamp(0.0, 1.0)
                : 0.0;

            yield DownloadProgress(
              receivedBytes: currentReceived,
              totalBytes: totalLength,
              progress: fraction,
              speedBytesPerSec: lastSpeed,
              statusText: totalLength > 0
                  ? '${(currentReceived / 1048576).toStringAsFixed(1)} MB de ${(totalLength / 1048576).toStringAsFixed(1)} MB'
                  : '${(currentReceived / 1048576).toStringAsFixed(1)} MB descargados',
            );
          }
        }

        await sink.flush();
        await sink.close();
        sink = null;

        // Emitir progreso final completo
        yield DownloadProgress(
          receivedBytes: currentReceived,
          totalBytes: totalLength > 0 ? totalLength : currentReceived,
          progress: 1.0,
          speedBytesPerSec: lastSpeed,
          statusText: totalLength > 0
              ? '${(totalLength / 1048576).toStringAsFixed(1)} MB de ${(totalLength / 1048576).toStringAsFixed(1)} MB'
              : '${(currentReceived / 1048576).toStringAsFixed(1)} MB completados',
        );

        return;
      } catch (e) {
        if (sink != null) {
          try {
            await sink.close();
          } catch (_) {}
          sink = null;
        }

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
  }

  /// Descarga un archivo con soporte para reanudación automática si se interrumpe la conexión.
  Future<File> downloadFile({
    required String url,
    required String destinationPath,
    required void Function(DownloadProgress progress) onProgress,
    CancelToken? cancelToken,
    bool allowResume = true,
    int maxRetries = 3,
  }) async {
    await for (final progress in downloadFileStream(
      url: url,
      destinationPath: destinationPath,
      cancelToken: cancelToken,
      allowResume: allowResume,
      maxRetries: maxRetries,
    )) {
      onProgress(progress);
    }
    return File(destinationPath);
  }
}
