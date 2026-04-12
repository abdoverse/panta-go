// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panta/app.dart';
import 'package:panta/providers/panta_provider.dart';

void main() {
  testWidgets('renders login screen shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PantaProvider(),
        child: const PantaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Panta'), findsWidgets);
  });
}
