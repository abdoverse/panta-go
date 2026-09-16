import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/shared/cookie_consent_banner.dart';
import 'package:panta/models/cookie_consent.dart';
import 'package:panta/providers/panta_provider.dart';
import 'package:panta/services/cookie_consent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CookieConsent Model Tests', () {
    test('acceptAll sets all permissions and policy version', () {
      final consent = CookieConsent.acceptAll();
      expect(consent.necessary, isTrue);
      expect(consent.functional, isTrue);
      expect(consent.analytics, isTrue);
      expect(consent.marketing, isTrue);
      expect(consent.policyVersion, CookieConsent.currentPolicyVersion);
    });

    test('necessaryOnly sets functional, analytics, and marketing to false', () {
      final consent = CookieConsent.necessaryOnly();
      expect(consent.necessary, isTrue);
      expect(consent.functional, isFalse);
      expect(consent.analytics, isFalse);
      expect(consent.marketing, isFalse);
      expect(consent.policyVersion, CookieConsent.currentPolicyVersion);
    });

    test('custom sets specified permissions correctly', () {
      final consent = CookieConsent.custom(
        functional: true,
        analytics: false,
        marketing: true,
      );
      expect(consent.necessary, isTrue);
      expect(consent.functional, isTrue);
      expect(consent.analytics, isFalse);
      expect(consent.marketing, isTrue);
    });

    test('serialization roundtrip preserves values', () {
      final consent = CookieConsent.custom(
        functional: true,
        analytics: true,
        marketing: false,
      );
      final jsonStr = consent.toJson();
      final parsed = CookieConsent.fromJson(jsonStr);

      expect(parsed.necessary, isTrue);
      expect(parsed.functional, isTrue);
      expect(parsed.analytics, isTrue);
      expect(parsed.marketing, isFalse);
      expect(parsed.policyVersion, CookieConsent.currentPolicyVersion);
    });
  });

  group('CookieConsentService Tests', () {
    test('persists and loads consent from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CookieConsentService();

      expect(await service.getConsent(), isNull);

      final consent = CookieConsent.acceptAll();
      await service.saveConsent(consent);

      final loaded = await service.getConsent();
      expect(loaded, isNotNull);
      expect(loaded!.functional, isTrue);
      expect(service.hasValidConsent(loaded), isTrue);

      await service.clearConsent();
      expect(await service.getConsent(), isNull);
    });

    test('invalidates outdated policy versions', () {
      final service = CookieConsentService();
      final oldConsent = CookieConsent(
        necessary: true,
        functional: true,
        analytics: true,
        marketing: true,
        timestamp: DateTime.now(),
        policyVersion: '1999.0',
      );
      expect(service.hasValidConsent(oldConsent), isFalse);
    });
  });

  group('CookieConsentBanner Widget Tests', () {
    Widget buildTestWidget(PantaProvider provider, {Locale locale = const Locale('sv', 'SE')}) {
      return ChangeNotifierProvider<PantaProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Stack(
              children: [
                Center(child: Text('Main Content')),
                CookieConsentBanner(),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('renders banner when unconsented and hides upon accepting all',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = PantaProvider();
      await tester.runAsync(() async {
        while (!provider.isCookieConsentLoaded) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await tester.pumpWidget(buildTestWidget(provider));
      await tester.pumpAndSettle();

      expect(find.byType(CookieConsentBanner), findsOneWidget);
      expect(find.text('Vi värnar om din integritet'), findsOneWidget);
      expect(find.text('Godkänn alla'), findsOneWidget);
      expect(find.text('Endast nödvändiga'), findsOneWidget);

      await tester.tap(find.text('Godkänn alla'));
      await tester.pumpAndSettle();

      expect(provider.showCookieConsentBanner, isFalse);
      expect(provider.cookieConsent?.functional, isTrue);
      expect(provider.cookieConsent?.analytics, isTrue);
    });

    testWidgets('accepts necessary only when button tapped', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = PantaProvider();
      await tester.runAsync(() async {
        while (!provider.isCookieConsentLoaded) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await tester.pumpWidget(buildTestWidget(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Endast nödvändiga'));
      await tester.pumpAndSettle();

      expect(provider.showCookieConsentBanner, isFalse);
      expect(provider.cookieConsent?.necessary, isTrue);
      expect(provider.cookieConsent?.functional, isFalse);
      expect(provider.cookieConsent?.analytics, isFalse);
      expect(provider.cookieConsent?.marketing, isFalse);
    });

    testWidgets('opens granular preferences modal dialog and saves custom choice',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final provider = PantaProvider();
      await tester.runAsync(() async {
        while (!provider.isCookieConsentLoaded) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await tester.pumpWidget(buildTestWidget(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anpassa kakor'));
      await tester.pumpAndSettle();

      expect(find.text('Cookie-inställningar'), findsOneWidget);
      expect(find.text('Nödvändiga kakor'), findsOneWidget);
      expect(find.text('Funktionella kakor'), findsOneWidget);
      expect(find.text('Analys & Prestanda'), findsOneWidget);
      expect(find.text('Marknadsföring'), findsOneWidget);

      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3));

      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      final saveButton = find.text('Spara inställningar');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(provider.cookieConsent?.functional, isTrue);
      expect(provider.showCookieConsentBanner, isFalse);
    });

    testWidgets('renders in English when locale is en_US', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = PantaProvider();
      await tester.runAsync(() async {
        while (!provider.isCookieConsentLoaded) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await tester.pumpWidget(buildTestWidget(provider, locale: const Locale('en', 'US')));
      await tester.pumpAndSettle();

      expect(find.text('We value your privacy'), findsOneWidget);
      expect(find.text('Accept all'), findsOneWidget);
      expect(find.text('Necessary only'), findsOneWidget);
      expect(find.text('Customize cookies'), findsOneWidget);
    });
  });
}
