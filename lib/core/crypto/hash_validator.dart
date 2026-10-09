import 'dart:io';
import 'package:crypto/crypto.dart';

/// Validador de integridad criptográfica mediante SHA-256.
class HashValidator {
  HashValidator._();

  /// Calcula el hash SHA-256 de un archivo en disco de forma asíncrona mediante streaming.
  static Future<String> calculateSha256(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('El archivo no existe', file.path);
    }

    final output = await sha256.bind(file.openRead()).first;
    return output.toString().toLowerCase();
  }

  /// Verifica si el archivo coincide con el hash esperado.
  static Future<bool> verifySha256(File file, String expectedSha256) async {
    final actual = await calculateSha256(file);
    return actual.trim().toLowerCase() == expectedSha256.trim().toLowerCase();
  }

  /// Calcula el hash de una cadena de texto.
  static String hashString(String input) {
    return sha256.convert(input.codeUnits).toString().toLowerCase();
  }
}
