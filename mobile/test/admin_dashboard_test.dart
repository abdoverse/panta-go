import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/admin/admin_dashboard_page.dart';
import 'package:panta/providers/panta_provider.dart';

void main() {
  group('Admin Dashboard & Market Oversight Tests', () {
    testWidgets('renders AdminDashboardPage with KPIs, map visualization, city trends, and simulate button', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(const {});
      final provider = PantaProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: AdminDashboardPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and quota banner
      expect(find.text('Panta Operations & Market Oversight'), findsOneWidget);
      expect(find.textContaining('Personal Caps: 20 Recycler / 30 Helper'), findsWidgets);
      expect(find.text('Anti-Spam & Anti-Hoarding Protection Active'), findsOneWidget);

      // Verify KPI Cards
      expect(find.text('Recycler Limit'), findsOneWidget);
      expect(find.text('Helper Limit'), findsOneWidget);
      expect(find.textContaining('20 / user'), findsOneWidget);
      expect(find.textContaining('30 / helper'), findsOneWidget);
      expect(find.text('Active Pickups'), findsOneWidget);

      // Verify Sweden Map Section
      expect(find.text('Sweden Country & City Map Visualization'), findsOneWidget);
      expect(find.text('Stockholm'), findsWidgets);
      expect(find.text('Göteborg'), findsWidgets);
      expect(find.text('Malmö'), findsWidgets);

      // Verify Simulate Button
      final simulateFinder = find.byType(FloatingActionButton);
      expect(simulateFinder, findsOneWidget);
      expect(find.text('Simulate Market Event'), findsOneWidget);

      // Tap simulate button
      await tester.tap(simulateFinder);
      await tester.pumpAndSettle();

      // Verify simulation triggered
      expect(find.text('Live System & Audit Logs'), findsOneWidget);
    });

    testWidgets('AdminDashboardPage can change language dynamically', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(const {});
      final provider = PantaProvider();
      await provider.setLocale(const Locale('en', 'US'));

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: Consumer<PantaProvider>(
            builder: (context, p, _) => MaterialApp(
              locale: p.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AdminDashboardPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially in English
      expect(find.text('Panta Operations & Market Oversight'), findsOneWidget);
      expect(find.byKey(const Key('admin_language_button')), findsOneWidget);

      // Scroll to language section
      final languageFinder = find.byKey(const Key('admin_language_segmented_button'));
      await tester.scrollUntilVisible(
        languageFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(languageFinder, findsOneWidget);
      expect(find.text('Language'), findsOneWidget);

      // Switch to Swedish via SegmentedButton
      await tester.tap(find.text('Svenska').first);
      await tester.pumpAndSettle();

      // Verify UI updated to Swedish
      expect(provider.locale.languageCode, 'sv');
      expect(find.text('Drift och marknadsöversikt'), findsOneWidget);
      expect(find.text('Språk'), findsOneWidget);

      // Switch back to English via AppBar language popup menu
      await tester.tap(find.byKey(const Key('admin_language_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      // Verify UI updated back to English
      expect(provider.locale.languageCode, 'en');
      expect(find.text('Panta Operations & Market Oversight'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('AdminDashboardPage displays suspension history and provides dropdown lists for suspend and lift actions', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(const {});
      final provider = PantaProvider();
      await provider.setLocale(const Locale('en', 'US'));

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: Consumer<PantaProvider>(
            builder: (context, p, _) => MaterialApp(
              locale: p.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AdminDashboardPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to suspension section
      final tabSelectorFinder = find.byKey(const Key('suspension_tab_selector'));
      await tester.scrollUntilVisible(
        tabSelectorFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tabSelectorFinder, findsOneWidget);

      // Verify Suspend user action button is visible
      expect(find.byKey(const Key('suspend_user_action_button')), findsOneWidget);

      // Switch to History tab
      await tester.tap(find.textContaining('History'));
      await tester.pumpAndSettle();

      // Verify history card is displayed with case reference and Lifted status
      expect(find.textContaining('CASE-2026-SE-0012'), findsOneWidget);
      expect(find.text('Lifted'), findsOneWidget);

      // Open Suspend User dialog
      await tester.tap(find.byKey(const Key('suspend_user_action_button')));
      await tester.pumpAndSettle();

      // Verify dropdowns appear in the dialog
      expect(find.byKey(const Key('suspend_user_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('suspend_reason_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('suspend_duration_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('confirm_suspend_button')), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
