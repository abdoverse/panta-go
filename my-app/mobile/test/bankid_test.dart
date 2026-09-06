import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/shared/profile_screen.dart';
import 'package:panta/models/request_model.dart';
import 'package:panta/providers/panta_provider.dart';
import 'package:panta/services/auth_service.dart';
import 'package:panta/services/bankid_service.dart';
import 'package:panta/services/panta_state_services.dart';
import 'package:panta/services/request_api_service.dart';

void main() {
  group('BankID Integration Tests', () {
    test('RecyclingRequest stores creator and helper BankID verification flags', () {
      final now = DateTime.now();
      final req = RecyclingRequest(
        id: 'bankid-req-1',
        title: 'Recycling with BankID verification',
        scheduledFrom: now,
        scheduledTo: now.add(const Duration(hours: 1)),
        location: 'Stockholm',
        creatorBankIdVerified: true,
        helperBankIdVerified: false,
      );

      expect(req.creatorBankIdVerified, isTrue);
      expect(req.helperBankIdVerified, isFalse);

      final accepted = req.copyWith(helperBankIdVerified: true);
      expect(accepted.creatorBankIdVerified, isTrue);
      expect(accepted.helperBankIdVerified, isTrue);
    });

    test('RequestApiService parses BankID verification flags from API payload', () {
      final jsonPayload = {
        'id': 'bankid-req-2',
        'title': 'Glass bottles',
        'scheduledFrom': '2026-09-06T12:00:00.000Z',
        'scheduledTo': '2026-09-06T14:00:00.000Z',
        'location': 'Gothenburg',
        'status': 'pending',
        'creatorBankIdVerified': true,
        'helperBankIdVerified': true,
      };

      final parsed = RequestApiService.parseRecyclingRequest(jsonPayload);
      expect(parsed.creatorBankIdVerified, isTrue);
      expect(parsed.helperBankIdVerified, isTrue);
    });

    test('BankIdCollectResponse properly deserializes pending and complete states', () {
      final pendingJson = {
        'orderRef': 'order-123',
        'status': 'pending',
        'hintCode': 'outstandingTransaction',
      };

      final pending = BankIdCollectResponse.fromJson(pendingJson);
      expect(pending.orderRef, 'order-123');
      expect(pending.isPending, isTrue);
      expect(pending.isComplete, isFalse);
      expect(pending.hintCode, 'outstandingTransaction');

      final completeJson = {
        'orderRef': 'order-123',
        'status': 'complete',
        'hintCode': 'complete',
        'token': 'mock.jwt.token',
        'personalNumber': '19900101-****',
        'name': 'Anna Andersson',
        'bankIdVerified': true,
        'bankIdVerifiedAt': '2026-09-06T12:00:00Z',
      };

      final complete = BankIdCollectResponse.fromJson(completeJson);
      expect(complete.isComplete, isTrue);
      expect(complete.bankIdVerified, isTrue);
      expect(complete.personalNumber, '19900101-****');
      expect(complete.name, 'Anna Andersson');
      expect(complete.token, 'mock.jwt.token');
    });

    test('AuthService.parseJwtPayload parses custom JWT claims with BankID data', () {
      // Build test JWT payload
      final claims = {
        'nickname': 'user',
        'name': 'Sven Svensson',
        'bankIdVerified': true,
        'bankIdPersonalNumber': '19850512-****',
        'bankIdVerifiedAt': '2026-09-06T10:00:00Z',
        'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      };

      final headerBase64 = base64Url.encode(utf8.encode(json.encode({'alg': 'HS256'})));
      final payloadBase64 = base64Url.encode(utf8.encode(json.encode(claims)));
      final signatureBase64 = base64Url.encode(utf8.encode('signature'));
      final token = '$headerBase64.$payloadBase64.$signatureBase64';

      final parsed = AuthService.parseJwtPayload(token);
      expect(parsed, isNotNull);
      expect(parsed!['bankIdVerified'], isTrue);
      expect(parsed['bankIdPersonalNumber'], '19850512-****');
      expect(parsed['nickname'], 'user');
      expect(parsed['name'], 'Sven Svensson');
    });

    test('PantaAuthState manages BankID status correctly', () {
      final authState = PantaAuthState();
      expect(authState.bankIdVerified, isFalse);
      expect(authState.bankIdPersonalNumber, isNull);

      authState.updateSession(
        userId: 'user-1',
        displayName: 'Erik',
        helper: false,
        verifiedBankId: true,
        personalNumber: '19920101-****',
        verifiedAt: '2026-09-06T10:00:00Z',
      );

      expect(authState.bankIdVerified, isTrue);
      expect(authState.bankIdPersonalNumber, '19920101-****');
      expect(authState.bankIdVerifiedAt, '2026-09-06T10:00:00Z');

      authState.clearSession();
      expect(authState.bankIdVerified, isFalse);
      expect(authState.bankIdPersonalNumber, isNull);
    });

    testWidgets('ProfileScreen renders BankID verified badge without personal number (plan-72)', (WidgetTester tester) async {
      final claims = {
        'nickname': 'user',
        'name': 'Sven Svensson',
        'bankIdVerified': true,
        'bankIdPersonalNumber': '19850512-****',
        'bankIdVerifiedAt': '2026-09-06T10:00:00Z',
        'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      };
      final headerBase64 = base64Url.encode(utf8.encode(json.encode({'alg': 'HS256'})));
      final payloadBase64 = base64Url.encode(utf8.encode(json.encode(claims)));
      final signatureBase64 = base64Url.encode(utf8.encode('signature'));
      final token = '$headerBase64.$payloadBase64.$signatureBase64';

      SharedPreferences.setMockInitialValues({'panta_custom_jwt': token});

      final authService = AuthService();
      await authService.setCustomToken(token);
      final provider = PantaProvider(authService: authService);
      await provider.restoreSession();

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
            home: Scaffold(body: ProfileScreen(isHelper: false)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data == 'Verifierad med BankID' || w.data == 'Verified with BankID'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('19850512'), findsNothing);
      expect(find.textContaining('****'), findsNothing);
    });
  });
}
