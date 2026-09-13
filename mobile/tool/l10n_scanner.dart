import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class L10nViolation {
  final String filePath;
  final int line;
  final int column;
  final String text;
  final String contextDescription;

  L10nViolation({
    required this.filePath,
    required this.line,
    required this.column,
    required this.text,
    required this.contextDescription,
  });

  @override
  String toString() => '$filePath:$line:$column [$contextDescription] "$text"';
}

class L10nScanner {
  static const Set<String> defaultAllowlist = {
    '', ' ', ':', '-', '|', '•', '/', '+', '(', ')',
    'SEK', 'kr', 'BankID', 'Panta', '🔥', '🛎️', '✓',
    'en', 'sv', 'en_US', 'sv_SE',
    '0', '0.00', '1', '2', '3', '4', '5', '10', '100',
  };

  static const List<String> datePatternSubstrings = [
    'd MMM', 'HH:mm', 'yyyy-MM-dd', 'MM/dd', 'HH:mm:ss',
  ];

  static bool isAllowed(String val) {
    final trimmed = val.trim();
    if (defaultAllowlist.contains(trimmed)) return true;

    // Assets, URLs, packages
    if (trimmed.startsWith('assets/') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('package:') ||
        trimmed.startsWith('mailto:')) {
      return true;
    }

    // Date/time formatting patterns
    for (final pattern in datePatternSubstrings) {
      if (trimmed == pattern || trimmed == '$pattern, $pattern') return true;
    }

    // Purely numbers, symbols, punctuation
    if (RegExp(r'^[\d\s.,:;!?%&*+=\-/\\|()\[\]{}#@^~_]+$').hasMatch(trimmed)) {
      return true;
    }

    // If string has no alphabet characters (e.g. only emojis or numbers)
    if (!RegExp(r'[a-zA-ZåäöÅÄÖ]').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Scan a single Dart file content
  static List<L10nViolation> scanSource(String filePath, String source) {
    final result = parseString(content: source);
    final visitor = _L10nAstVisitor(filePath, source);
    result.unit.accept(visitor);
    return visitor.violations;
  }

  /// Scan a directory for all .dart files
  static List<L10nViolation> scanDirectory(
    Directory dir, {
    List<String> excludePaths = const [],
  }) {
    final violations = <L10nViolation>[];
    if (!dir.existsSync()) return violations;

    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;

      var shouldExclude = false;
      for (final exclude in excludePaths) {
        if (file.path.contains(exclude)) {
          shouldExclude = true;
          break;
        }
      }
      if (shouldExclude) continue;

      final content = file.readAsStringSync();
      violations.addAll(scanSource(file.path, content));
    }
    return violations;
  }
}

class _L10nAstVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final String source;
  final List<L10nViolation> violations = [];

  _L10nAstVisitor(this.filePath, this.source);

  int _getLine(int offset) {
    var line = 1;
    for (var i = 0; i < offset && i < source.length; i++) {
      if (source[i] == '\n') line++;
    }
    return line;
  }

  int _getColumn(int offset) {
    var col = 1;
    for (var i = offset - 1; i >= 0 && source[i] != '\n'; i--) {
      col++;
    }
    return col;
  }

  bool _isIgnoredLine(int offset) {
    final lineStart = source.lastIndexOf('\n', offset);
    final lineEnd = source.indexOf('\n', offset);
    final line = source.substring(
      lineStart == -1 ? 0 : lineStart + 1,
      lineEnd == -1 ? source.length : lineEnd,
    );
    return line.contains('// l10n-ignore') || line.contains('// l10n-allow');
  }

  /// Check if the string literal is used in a non-user-facing comparison, key, format pattern, or exception
  bool _isTechnicalOrNonUi(AstNode node) {
    AstNode? curr = node.parent;
    while (curr != null) {
      if (curr is BinaryExpression) {
        // e.g. mode == 'test' or role != 'admin'
        final op = curr.operator.lexeme;
        if (op == '==' || op == '!=') return true;
      }
      if (curr is SwitchCase || curr is SwitchPatternCase) {
        return true;
      }
      if (curr is IndexExpression) {
        // e.g. json['key']
        return true;
      }
      if (curr is MapLiteralEntry && curr.key == node) {
        return true;
      }
      // DateFormat('...') or NumberFormat('...')
      if (curr is MethodInvocation &&
          ['DateFormat', 'NumberFormat'].contains(curr.methodName.name)) {
        return true;
      }
      if (curr is InstanceCreationExpression &&
          ['DateFormat', 'NumberFormat'].contains(curr.constructorName.type.toSource())) {
        return true;
      }
      // String manipulation methods (patterns / search tokens)
      if (curr is MethodInvocation &&
          [
            'replaceFirst',
            'replaceAll',
            'split',
            'startsWith',
            'endsWith',
            'contains',
            'indexOf',
            'lastIndexOf',
          ].contains(curr.methodName.name)) {
        return true;
      }
      // Arguments to l10n methods, e.g. l10n.roleLabel('Helper') or context.l10n.format('SEK')
      if (curr is MethodInvocation &&
          (curr.target?.toSource().endsWith('l10n') == true ||
           curr.target?.toSource() == 'AppLocalizations')) {
        return true;
      }
      // Assertions or Throw expressions
      if (curr is Assertion || curr is ThrowExpression) {
        return true;
      }
      // Debug prints or logging
      if (curr is MethodInvocation &&
          ['debugPrint', 'print', 'log'].contains(curr.methodName.name)) {
        return true;
      }
      // Key('...'), RegExp('...'), Uri.parse('...')
      if (curr is InstanceCreationExpression &&
          ['Key', 'ValueKey', 'RegExp', 'Uri'].contains(curr.constructorName.type.toSource())) {
        return true;
      }
      if (curr is MethodInvocation &&
          curr.target?.toSource() == 'Uri' &&
          ['parse', 'https', 'http'].contains(curr.methodName.name)) {
        return true;
      }
      // Stop traversing if we hit a statement boundary
      if (curr is Statement || curr is FunctionDeclaration || curr is MethodDeclaration) {
        break;
      }
      curr = curr.parent;
    }
    return false;
  }

  void _checkString(AstNode node, String value) {
    if (L10nScanner.isAllowed(value)) return;
    if (_isIgnoredLine(node.offset)) return;
    if (_isTechnicalOrNonUi(node)) return;

    var curr = node.parent;
    while (curr != null) {
      // 1. Check for Text / SelectableText / RichText widgets
      String? widgetName;
      if (curr is InstanceCreationExpression) {
        widgetName = curr.constructorName.type.toSource();
      } else if (curr is MethodInvocation) {
        widgetName = curr.methodName.name;
      }

      if (widgetName != null &&
          (widgetName == 'Text' ||
              widgetName == 'SelectableText' ||
              widgetName == 'RichText')) {
        violations.add(L10nViolation(
          filePath: filePath,
          line: _getLine(node.offset),
          column: _getColumn(node.offset),
          text: value,
          contextDescription: '$widgetName widget',
        ));
        return;
      }

      // 2. Named arguments: labelText, hintText, errorText, helperText, tooltip, message, title, subtitle, roleBadge, buttonText
      if (curr is NamedExpression) {
        final paramName = curr.name.label.name;
        if (const [
          'hintText',
          'labelText',
          'errorText',
          'helperText',
          'message',
          'tooltip',
          'title',
          'subtitle',
          'roleBadge',
          'buttonText',
        ].contains(paramName)) {
          violations.add(L10nViolation(
            filePath: filePath,
            line: _getLine(node.offset),
            column: _getColumn(node.offset),
            text: value,
            contextDescription: '$paramName parameter',
          ));
          return;
        }
      }

      // 3. Tab(text: '...')
      if (curr is InstanceCreationExpression &&
          curr.constructorName.type.toSource() == 'Tab') {
        violations.add(L10nViolation(
          filePath: filePath,
          line: _getLine(node.offset),
          column: _getColumn(node.offset),
          text: value,
          contextDescription: 'Tab text',
        ));
        return;
      }

      // 4. Assignment to errorMessage or _errorMessage
      if (curr is AssignmentExpression) {
        final targetName = curr.leftHandSide.toSource().toLowerCase();
        if (targetName.contains('errormessage') || targetName.contains('statusmessage')) {
          violations.add(L10nViolation(
            filePath: filePath,
            line: _getLine(node.offset),
            column: _getColumn(node.offset),
            text: value,
            contextDescription: 'Error/status message assignment',
          ));
          return;
        }
      }

      curr = curr.parent;
    }
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _checkString(node, node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    final fullText = node.elements.map((e) {
      if (e is InterpolationString) return e.value;
      return '\${...}';
    }).join();
    _checkString(node, fullText);
    super.visitStringInterpolation(node);
  }
}

void main(List<String> args) {
  var targetPath = 'lib';
  var checkOnly = false;
  for (final arg in args) {
    if (arg == '--check') {
      checkOnly = true;
    } else if (!arg.startsWith('-')) {
      targetPath = arg;
    }
  }
  final targetDir = Directory(targetPath);

  print('🔍 Scanning ${targetDir.path} for untranslated UI strings...\n');

  final violations = L10nScanner.scanDirectory(
    targetDir,
    excludePaths: ['core/localization'],
  );

  if (violations.isEmpty) {
    print('✅ No untranslated UI strings found!');
    exit(0);
  }

  print('❌ Found ${violations.length} untranslated UI string(s):\n');

  // Group by file
  final grouped = <String, List<L10nViolation>>{};
  for (final v in violations) {
    grouped.putIfAbsent(v.filePath, () => []).add(v);
  }

  for (final entry in grouped.entries) {
    print('📁 ${entry.key} (${entry.value.length} issue(s)):');
    for (final v in entry.value) {
      print('   Line ${v.line.toString().padLeft(4)} [${v.contextDescription}]: "${v.text}"');
    }
    print('');
  }

  if (checkOnly) {
    exit(1);
  }
}
