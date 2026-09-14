import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/shared/profile_screen.dart';
import 'package:panta/providers/panta_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget(PantaProvider provider, {bool isHelper = false}) {
    return ChangeNotifierProvider<PantaProvider>.value(
      value: provider,
      child: Consumer<PantaProvider>(
        builder: (context, prov, _) => MaterialApp(
          locale: prov.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileScreen(isHelper: isHelper),
        ),
      ),
    );
  }

  group('ProfileScreen Layout & Platform-Specific Tests', () {
    testWidgets('renders app-specific items and hides website-specific items on mobile',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final provider = PantaProvider();
      await provider.setLocale(const Locale('en', 'US'));

      await tester.pumpWidget(buildTestWidget(provider));
      await tester.pumpAndSettle();

      // App-specific items MUST be rendered on mobile (!kIsWeb)
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Manage app preferences'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Stay updated on activity'), findsOneWidget);

      // Common items MUST be rendered
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Feedback'), findsOneWidget);

      // Website-specific item (Cookie preferences) MUST NOT be rendered on mobile (!kIsWeb)
      expect(find.text('Cookie preferences'), findsNothing);
      expect(find.text('Manage cookie preferences'), findsNothing);
    });

    testWidgets('places About Panta furthest down after Log out', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final provider = PantaProvider();
      await provider.setLocale(const Locale('en', 'US'));

      await tester.pumpWidget(buildTestWidget(provider));
      await tester.pumpAndSettle();

      // Find the position of Log Out and About Panta
      final logOutFinder = find.text('Log out');
      final aboutPantaFinder = find.text('About Panta');

      expect(logOutFinder, findsOneWidget);
      expect(aboutPantaFinder, findsWidgets);

      // Verify that About Panta appears lower on the Y-axis than Log out
      final logOutCenter = tester.getCenter(logOutFinder);
      final aboutPantaCenter = tester.getCenter(aboutPantaFinder.first);
      expect(aboutPantaCenter.dy, greaterThan(logOutCenter.dy));
    });

    testWidgets('displays each language in its native name in language picker (item 19)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final provider = PantaProvider();
      // Set initial language to English
      await provider.setLocale(const Locale('en', 'US'));

      await tester.pumpWidget(buildTestWidget(provider));
      await tester.pumpAndSettle();

      // Subtitle on profile screen shows native language name 'English'
      expect(find.text('English'), findsOneWidget);

      // Open language picker
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      // In the picker sheet, Swedish should be "Svenska" (not "Swedish")
      expect(find.text('Svenska'), findsOneWidget);
      // In the picker sheet, English should be "English"
      expect(find.text('English'), findsWidgets);

      // Tap on "Svenska"
      await tester.tap(find.text('Svenska'));
      await tester.pumpAndSettle();

      // Verify locale changed to sv
      expect(provider.locale.languageCode, 'sv');

      // Profile screen should now reflect Swedish
      expect(find.text('Språk'), findsOneWidget);
      expect(find.text('Svenska'), findsOneWidget);

      // Open language picker again while in Swedish
      await tester.tap(find.text('Språk'));
      await tester.pumpAndSettle();

      // Both native names still present in the list
      expect(find.text('Svenska'), findsWidgets);
      expect(find.text('English'), findsOneWidget);
    });
  });
}
