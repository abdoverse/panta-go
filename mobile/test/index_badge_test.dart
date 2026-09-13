import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panta/core/theme/app_theme.dart';
import 'package:panta/features/dashboard/widgets/index_badge.dart';

void main() {
  group('IndexBadge Tests', () {
    testWidgets('renders 1-based index in circular badge without #', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IndexBadge(index: 0),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('#1'), findsNothing);

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('renders double-digit indices correctly in circular badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IndexBadge(index: 9),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.text('#10'), findsNothing);
    });

    testWidgets('applies primaryGreen styling to text and circular background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IndexBadge(index: 2),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('3'));
      expect(textWidget.style?.fontSize, 14);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.color, AppTheme.primaryGreen);
    });
  });
}
