import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/l10n_scanner.dart';

void main() {
  group('Localization Guard - Automated Prevention', () {
    test('lib should have 0 hardcoded user-facing strings', () {
      final libDir = Directory('lib');
      expect(
        libDir.existsSync(),
        isTrue,
        reason: 'lib directory should exist',
      );

      final violations = L10nScanner.scanDirectory(
        libDir,
        excludePaths: ['core/localization'],
      );

      if (violations.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln(
          'Found ${violations.length} untranslated user-facing string(s) in lib:\n',
        );

        final grouped = <String, List<L10nViolation>>{};
        for (final v in violations) {
          grouped.putIfAbsent(v.filePath, () => []).add(v);
        }

        for (final entry in grouped.entries) {
          buffer.writeln('📁 ${entry.key}:');
          for (final v in entry.value) {
            buffer.writeln('   Line ${v.line} [${v.contextDescription}]: "${v.text}"');
          }
        }

        buffer.writeln(
          '\nTo fix this:\n'
          '1. Add Swedish and English translations to lib/core/localization/app_localizations.dart\n'
          '2. Use context.l10n.<getterOrMethod> in your widget\n'
          '3. If a string is strictly non-user-facing (e.g. constant id/brand), add "// l10n-ignore" to that line.',
        );

        fail(buffer.toString());
      }

      expect(violations, isEmpty);
    });
  });
}
