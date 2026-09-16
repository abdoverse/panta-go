import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/shared/market_notification_banner.dart';
import 'package:panta/models/market_notification.dart';
import 'package:panta/providers/panta_provider.dart';
import 'package:panta/services/market_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MarketNotification Model Tests', () {
    test('MarketNotification fromJson and toJson roundtrip', () {
      final jsonMap = {
        'id': 'test-notice-1',
        'market': 'SE',
        'title': 'Technical Issue',
        'titleSv': 'Tekniskt fel',
        'message':
            'We are experiencing some technical issues and are looking into it.',
        'messageSv':
            'Vi upplever för närvarande tekniska problem och undersöker detta.',
        'severity': 'warning',
        'active': true,
        'dismissible': true,
        'actionUrl': 'https://status.panta.se',
        'actionLabel': 'Status',
        'createdAt': '2026-09-16T12:00:00.000Z',
        'updatedAt': '2026-09-16T12:05:00.000Z',
      };

      final notif = MarketNotification.fromJson(jsonMap);
      expect(notif.id, 'test-notice-1');
      expect(notif.market, 'SE');
      expect(notif.title, 'Technical Issue');
      expect(notif.titleSv, 'Tekniskt fel');
      expect(notif.message,
          'We are experiencing some technical issues and are looking into it.');
      expect(notif.severity, MarketNotificationSeverity.warning);
      expect(notif.active, isTrue);
      expect(notif.dismissible, isTrue);
      expect(notif.actionUrl, 'https://status.panta.se');
      expect(notif.actionLabel, 'Status');

      final serialized = notif.toJson();
      expect(serialized['id'], 'test-notice-1');
      expect(serialized['market'], 'SE');
      expect(serialized['severity'], 'warning');
      expect(serialized['active'], isTrue);
    });

    test('MarketNotification localizedTitle and localizedMessage respect locale',
        () {
      const notif = MarketNotification(
        id: 'test-2',
        market: 'ALL',
        title: 'Outage',
        titleSv: 'Driftstörning',
        message:
            'We are experiencing some technical issues and are looking into it.',
        messageSv:
            'Vi upplever för närvarande tekniska problem och undersöker detta.',
      );

      expect(notif.localizedTitle(false), 'Outage');
      expect(notif.localizedTitle(true), 'Driftstörning');
      expect(notif.localizedMessage(false),
          'We are experiencing some technical issues and are looking into it.');
      expect(notif.localizedMessage(true),
          'Vi upplever för närvarande tekniska problem och undersöker detta.');
    });

    test('MarketNotification fallback to English when Swedish string is absent',
        () {
      const notif = MarketNotification(
        id: 'test-3',
        market: 'ALL',
        title: 'Global Notice',
        message: 'Server update in progress.',
      );

      expect(notif.localizedTitle(true), 'Global Notice');
      expect(notif.localizedMessage(true), 'Server update in progress.');
    });

    test('MarketNotificationSeverity parses various severity levels correctly',
        () {
      expect(MarketNotificationSeverity.fromString('critical'),
          MarketNotificationSeverity.critical);
      expect(MarketNotificationSeverity.fromString('incident'),
          MarketNotificationSeverity.incident);
      expect(MarketNotificationSeverity.fromString('info'),
          MarketNotificationSeverity.info);
      expect(MarketNotificationSeverity.fromString('warning'),
          MarketNotificationSeverity.warning);
      expect(MarketNotificationSeverity.fromString(null),
          MarketNotificationSeverity.warning);
    });
  });

  group('MarketNotificationService Tests', () {
    test('fetchMarketNotifications retrieves list of active notifications',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/market/notifications') {
          return http.Response(
            json.encode({
              'market': 'SE',
              'notifications': [
                {
                  'id': 'notice-101',
                  'market': 'ALL',
                  'title': 'Technical Issues',
                  'message':
                      'We are experiencing some technical issues and are looking into it.',
                  'severity': 'warning',
                  'active': true,
                  'dismissible': true,
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final service = MarketNotificationService(client: mockClient);
      final notices = await service.fetchMarketNotifications(market: 'SE');

      expect(notices.length, 1);
      expect(notices.first.id, 'notice-101');
      expect(notices.first.message,
          'We are experiencing some technical issues and are looking into it.');
    });

    test('dismissNotification persists ID and getDismissedNotificationIds loads it',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final service = MarketNotificationService(prefs: prefs);

      expect(await service.getDismissedNotificationIds(), isEmpty);

      await service.dismissNotification('notice-101');
      final dismissed = await service.getDismissedNotificationIds();
      expect(dismissed.contains('notice-101'), isTrue);

      await service.clearDismissed();
      expect(await service.getDismissedNotificationIds(), isEmpty);
    });
  });

  group('PantaProvider Market Notification Integration Tests', () {
    test('fetchMarketNotifications updates provider state and active notice',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'market': 'SE',
            'notifications': [
              {
                'id': 'tech-issue-banner-1',
                'market': 'SE',
                'title': 'System Notice',
                'message':
                    'We are experiencing some technical issues and are looking into it.',
                'severity': 'warning',
                'active': true,
                'dismissible': true,
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final prefs = await SharedPreferences.getInstance();
      final service =
          MarketNotificationService(client: mockClient, prefs: prefs);

      final provider = PantaProvider(
        marketNotificationService: service,
      );

      await provider.fetchMarketNotifications(marketCode: 'SE');

      expect(provider.marketNotifications.length, 1);
      expect(provider.hasActiveMarketNotification, isTrue);
      expect(provider.activeMarketNotification?.id, 'tech-issue-banner-1');
      expect(
        provider.activeMarketNotification?.message,
        'We are experiencing some technical issues and are looking into it.',
      );

      // Dismiss the active notification
      await provider.dismissMarketNotification('tech-issue-banner-1');
      expect(provider.hasActiveMarketNotification, isFalse);
      expect(provider.activeMarketNotification, isNull);

      // Clear dismissed notifications restores it
      await provider.clearDismissedMarketNotifications();
      expect(provider.hasActiveMarketNotification, isTrue);
    });
  });

  group('MarketNotificationBanner Widget Tests', () {
    testWidgets('renders technical issue message when active notification exists',
        (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'market': 'SE',
            'notifications': [
              {
                'id': 'tech-issue-widget-1',
                'market': 'ALL',
                'title': 'Technical Issues',
                'message':
                    'We are experiencing some technical issues and are looking into it.',
                'severity': 'warning',
                'active': true,
                'dismissible': true,
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final prefs = await SharedPreferences.getInstance();
      final service =
          MarketNotificationService(client: mockClient, prefs: prefs);
      final provider = PantaProvider(marketNotificationService: service);
      await provider.fetchMarketNotifications(marketCode: 'SE');

      await tester.pumpWidget(
        ChangeNotifierProvider<PantaProvider>.value(
          value: provider,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  MarketNotificationBanner(),
                  Text('Dashboard content'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
            'We are experiencing some technical issues and are looking into it.'),
        findsOneWidget,
      );
      expect(find.text('Technical Issues'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap dismiss button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'We are experiencing some technical issues and are looking into it.'),
        findsNothing,
      );
      expect(provider.activeMarketNotification, isNull);
    });

    testWidgets('renders nothing (SizedBox.shrink) when active notification is null',
        (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'market': 'SE', 'notifications': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MarketNotificationService(client: mockClient);
      final provider = PantaProvider(marketNotificationService: service);
      await provider.fetchMarketNotifications(marketCode: 'SE');

      await tester.pumpWidget(
        ChangeNotifierProvider<PantaProvider>.value(
          value: provider,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MarketNotificationBanner(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}
