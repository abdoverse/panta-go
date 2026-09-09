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
  });
}
