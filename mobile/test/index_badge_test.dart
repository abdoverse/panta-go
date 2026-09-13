import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panta/features/dashboard/widgets/index_badge.dart';

void main() {
  group('IndexBadge Tests', () {
    testWidgets('renders correct 1-based index prefixed with #', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IndexBadge(index: 0),
          ),
        ),
      );

      expect(find.text('#1'), findsOneWidget);
    });

    testWidgets('renders double-digit indices correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IndexBadge(index: 9),
          ),
        ),
      );

      expect(find.text('#10'), findsOneWidget);
    });

    testWidgets('applies systematic bold grey styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IndexBadge(index: 2),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('#3'));
      expect(textWidget.style?.fontSize, 18);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.color, Colors.grey[400]);
    });
  });
}
