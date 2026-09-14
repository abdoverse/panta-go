import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/admin/admin_dashboard_page.dart';
import 'package:panta/providers/panta_provider.dart';
import 'package:panta/services/admin_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserBlockModel Tests', () {
    test('deserializes JSON payload correctly', () {
      final json = {
        'userId': 'user-123',
        'email': 'user@example.com',
        'status': 'BLOCKED',
        'reason': 'Suspicious receipt activity',
        'caseReferenceId': 'CASE-2026-999',
        'blockedAt': '2026-09-14T20:00:00Z',
        'blockedBy': 'Admin Operator',
        'expiresAt': '2026-10-14T20:00:00Z',
      };

      final model = UserBlockModel.fromJson(json);

      expect(model.userId, 'user-123');
      expect(model.email, 'user@example.com');
      expect(model.status, 'BLOCKED');
      expect(model.reason, 'Suspicious receipt activity');
      expect(model.caseReferenceId, 'CASE-2026-999');
      expect(model.blockedAt, '2026-09-14T20:00:00Z');
      expect(model.blockedBy, 'Admin Operator');
      expect(model.expiresAt, '2026-10-14T20:00:00Z');
    });
  });

  group('Admin Dashboard User Suspensions Widget Tests', () {
    Widget buildDashboard(PantaProvider provider) {
      return ChangeNotifierProvider<PantaProvider>.value(
        value: provider,
        child: const MaterialApp(
          locale: Locale('sv', 'SE'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminDashboardPage(),
        ),
      );
    }

    testWidgets('renders User Suspensions section and buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final provider = PantaProvider();

      await tester.runAsync(() async {
        while (provider.isRestoringSession) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await tester.pumpWidget(buildDashboard(provider));
      await tester.pumpAndSettle();

      expect(find.text('Användaravstängningar & Juridiska ärenden'), findsOneWidget);
      expect(find.text('Stäng av användare'), findsOneWidget);
      expect(find.text('Inga aktiva användaravstängningar'), findsOneWidget);
    });
  });
}
