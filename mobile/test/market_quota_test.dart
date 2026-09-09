import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/dashboard/create_request_page.dart';
import 'package:panta/models/request_model.dart';
import 'package:panta/providers/panta_provider.dart';

void main() {
  group('Market Quota & Active Request Limit Tests (plan-74)', () {
    test('PantaProvider calculates active requests count and creation eligibility (20 recycler / 30 helper)', () async {
      SharedPreferences.setMockInitialValues(const {});
      final provider = PantaProvider();
      await provider.restoreSession();

      expect(provider.activeRequestsCount, 0);
      expect(provider.maxActiveRequests, 20);
      expect(provider.maxActiveHelperJobs, 30);
      expect(provider.canCreateRequest, isTrue);

      final now = DateTime.now();
      final reqs = [
        RecyclingRequest(
          id: 'req-1',
          title: 'Bottles 1',
          scheduledFrom: now,
          scheduledTo: now.add(const Duration(hours: 1)),
          location: 'Stockholm',
          status: RequestStatus.pending,
        ),
        RecyclingRequest(
          id: 'req-2',
          title: 'Bottles 2',
          scheduledFrom: now,
          scheduledTo: now.add(const Duration(hours: 1)),
          location: 'Stockholm',
          status: RequestStatus.accepted,
        ),
        RecyclingRequest(
          id: 'req-3',
          title: 'Bottles 3',
          scheduledFrom: now,
          scheduledTo: now.add(const Duration(hours: 1)),
          location: 'Stockholm',
          status: RequestStatus.pickedUp,
        ),
      ];

      provider.requests.addAll(reqs);

      // Only pending and accepted count towards active market quota
      expect(provider.activeRequestsCount, 2);
      expect(provider.canCreateRequest, isTrue);

      // Add 18 more active requests to reach limit of 20
      for (int i = 4; i <= 21; i++) {
        provider.requests.add(
          RecyclingRequest(
            id: 'req-$i',
            title: 'Bottles $i',
            scheduledFrom: now,
            scheduledTo: now.add(const Duration(hours: 1)),
            location: 'Stockholm',
            status: RequestStatus.pending,
          ),
        );
      }

      expect(provider.activeRequestsCount, 20);
      expect(provider.canCreateRequest, isFalse);
    });

    testWidgets('CreateRequestPage shows quota banner and disables button when limit of 20 is reached', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(const {});
      final provider = PantaProvider();
      await tester.runAsync(() async {
        while (provider.isRestoringSession) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      final now = DateTime.now();

      // Seed 20 active requests
      for (int i = 1; i <= 20; i++) {
        provider.requests.add(
          RecyclingRequest(
            id: 'quota-req-$i',
            title: 'Request $i',
            scheduledFrom: now,
            scheduledTo: now.add(const Duration(hours: 1)),
            location: 'Stockholm',
            status: RequestStatus.pending,
          ),
        );
      }

      expect(provider.activeRequestsCount, 20);
      expect(provider.canCreateRequest, isFalse);

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
            home: CreateRequestPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Active Market Limit Reached (20/20)'), findsOneWidget);
      expect(find.text('Market limit reached'), findsOneWidget);

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Market limit reached');
      expect(buttonFinder, findsOneWidget);
      final ElevatedButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);
    });
  });
}
