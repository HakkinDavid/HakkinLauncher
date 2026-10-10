import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Anti-Hardcoded Strings Audit Test', () {
    test('audits lib/ for uncentralized hardcoded strings', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final violations = <String>[];
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in dartFiles) {
        final normalizedPath = file.path.replaceAll(r'\', '/');

        // Skip constants definition files and generated files
        if (normalizedPath.endsWith('lib/core/constants/app_strings.dart') ||
            normalizedPath.endsWith('lib/core/constants/app_technical_strings.dart') ||
            normalizedPath.endsWith('.g.dart') ||
            normalizedPath.endsWith('.freezed.dart')) {
          continue;
        }

        final content = file.readAsStringSync();
        final fileViolations = _scanForStringLiterals(content, normalizedPath);
        violations.addAll(fileViolations);
      }

      if (violations.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln('Found ${violations.length} hardcoded string literal(s) in lib/:');
        for (final v in violations) {
          buffer.writeln('  • $v');
        }
        buffer.writeln('\nPlease move these strings to AppStrings or AppTechnicalStrings.');
        fail(buffer.toString());
      }
    });
  });
}

List<String> _scanForStringLiterals(String source, String filePath) {
  final violations = <String>[];
  final length = source.length;
  var i = 0;
  var lineNumber = 1;
  var inDirective = false; // import, export, part

  while (i < length) {
    final char = source[i];

    // Handle newlines
    if (char == '\n') {
      lineNumber++;
      i++;
      continue;
    }

    // Handle single-line comments
    if (i + 1 < length && source[i] == '/' && source[i + 1] == '/') {
      i += 2;
      while (i < length && source[i] != '\n') {
        i++;
      }
      continue;
    }

    // Handle multi-line comments
    if (i + 1 < length && source[i] == '/' && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < length && !(source[i] == '*' && source[i + 1] == '/')) {
        if (source[i] == '\n') lineNumber++;
        i++;
      }
      if (i + 1 < length) i += 2;
      continue;
    }

    // Handle directives (import, export, part)
    if (!inDirective) {
      if (_matchesWord(source, i, 'import') ||
          _matchesWord(source, i, 'export') ||
          _matchesWord(source, i, 'part')) {
        inDirective = true;
      }
    }

    if (inDirective && char == ';') {
      inDirective = false;
      i++;
      continue;
    }

    // Check for string literals
    final stringLiteral = _extractStringLiteral(source, i);
    if (stringLiteral != null) {
      final (literalText, endIndex, linesCrossed) = stringLiteral;

      if (!inDirective) {
        violations.add('$filePath:$lineNumber -> $literalText');
      }

      lineNumber += linesCrossed;
      i = endIndex;
      continue;
    }

    i++;
  }

  return violations;
}

bool _matchesWord(String source, int index, String word) {
  if (index + word.length > source.length) return false;
  if (source.substring(index, index + word.length) != word) return false;

  // Check word boundaries
  final beforeIndex = index - 1;
  if (beforeIndex >= 0) {
    final prev = source[beforeIndex];
    if (_isIdentifierChar(prev)) return false;
  }

  final afterIndex = index + word.length;
  if (afterIndex < source.length) {
    final next = source[afterIndex];
    if (_isIdentifierChar(next)) return false;
  }

  return true;
}

bool _isIdentifierChar(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 65 && code <= 90) || // A-Z
      (code >= 97 && code <= 122) || // a-z
      (code >= 48 && code <= 57) || // 0-9
      code == 95 || // _
      code == 36; // $
}

(String, int, int)? _extractStringLiteral(String source, int index) {
  final length = source.length;
  if (index >= length) return null;

  var isRaw = false;
  var cursor = index;

  if (source[cursor] == 'r' && cursor + 1 < length) {
    final next = source[cursor + 1];
    if (next == "'" || next == '"') {
      isRaw = true;
      cursor++;
    }
  }

  final startQuote = source[cursor];
  if (startQuote != "'" && startQuote != '"') return null;

  var isTriple = false;

  if (cursor + 2 < length &&
      source[cursor + 1] == startQuote &&
      source[cursor + 2] == startQuote) {
    isTriple = true;
    cursor += 3;
  } else {
    cursor += 1;
  }

  var linesCrossed = 0;

  while (cursor < length) {
    if (source[cursor] == '\n') {
      linesCrossed++;
    }

    if (!isRaw && source[cursor] == r'\') {
      cursor += 2; // skip escape character and the escaped char
      continue;
    }

    if (isTriple) {
      if (cursor + 2 < length &&
          source[cursor] == startQuote &&
          source[cursor + 1] == startQuote &&
          source[cursor + 2] == startQuote) {
        final literalText = source.substring(index, cursor + 3);
        return (literalText, cursor + 3, linesCrossed);
      }
    } else {
      if (source[cursor] == startQuote) {
        final literalText = source.substring(index, cursor + 1);
        return (literalText, cursor + 1, linesCrossed);
      }
    }

    cursor++;
  }

  // Unterminated string literal
  final literalText = source.substring(index, length);
  return (literalText, length, linesCrossed);
}
