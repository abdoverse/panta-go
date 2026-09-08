import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:panta/models/request_model.dart';
import 'package:panta/providers/panta_provider.dart';
import 'package:panta/services/auth_service.dart';
import 'package:panta/services/request_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UUID and Currency Refactor Tests', () {
    test('RecyclingRequest parses UUIDs and currency fields from JSON payload', () {
      final jsonPayload = {
        'id': 'req-test-uuid',
        'creatorId': 'a1b2c3d4-e5f6-5a7b-8c9d-0123456789ab',
        'creatorName': 'Anna Recycler',
        'helperId': 'f1e2d3c4-b5a6-5978-9876-543210fedcba',
        'helperName': 'Erik Helper',
        'title': 'Sorted Pant Bags',
        'scheduledFrom': '2026-09-07T10:00:00Z',
        'scheduledTo': '2026-09-07T12:00:00Z',
        'location': 'Stockholm',
        'reward': 40.0,
        'currency': 'NOK',
        'currencySymbol': 'kr',
        'market': 'NO',
        'status': 'accepted',
      };

      final req = RequestApiService.parseRecyclingRequest(jsonPayload);

      expect(req.id, 'req-test-uuid');
      expect(req.creatorId, 'a1b2c3d4-e5f6-5a7b-8c9d-0123456789ab');
      expect(req.creatorName, 'Anna Recycler');
      expect(req.helperId, 'f1e2d3c4-b5a6-5978-9876-543210fedcba');
      expect(req.helperName, 'Erik Helper');
      expect(req.currency, 'NOK');
      expect(req.currencySymbol, 'kr');
      expect(req.market, 'NO');
      expect(req.status, RequestStatus.accepted);
    });

    test('AuthService parses user UUID from custom token sub and userId claims', () async {
      final userUUID = 'e8b7c3d2-4567-4a89-9bcd-ef0123456789';
      final claims = {
        'sub': userUUID,
        'userId': userUUID,
        'nickname': 'user',
        'name': 'Anna Recycler',
        'email': 'anna.recycler@example.com',
        'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      };

      final headerBase64 = base64Url.encode(utf8.encode(json.encode({'alg': 'HS256'})));
      final payloadBase64 = base64Url.encode(utf8.encode(json.encode(claims)));
      final signatureBase64 = base64Url.encode(utf8.encode('signature'));
      final token = '$headerBase64.$payloadBase64.$signatureBase64';

      final authService = AuthService();
      await authService.setCustomToken(token);

      final currentId = await authService.getCurrentUserId();
      final currentUsername = await authService.getCurrentUsername();
      final displayName = await authService.getCurrentDisplayName();

      expect(currentId, userUUID);
      expect(currentUsername, userUUID);
      expect(displayName, 'Anna Recycler');
    });

    test('AppConstants and PantaProvider configure currency and symbol per market', () {
      final provider = PantaProvider();

      // 1. Default market is Sweden (SEK, kr)
      expect(provider.currentMarket, 'SE');
      expect(provider.currencyCode, 'SEK');
      expect(provider.currencySymbol, 'kr');
      expect(provider.formatCurrency(50.5), '50.50 kr');

      // 2. Norway market (NOK, kr)
      provider.setMarket('NO');
      expect(provider.currentMarket, 'NO');
      expect(provider.currencyCode, 'NOK');
      expect(provider.currencySymbol, 'kr');
      expect(provider.formatCurrency(120), '120.00 kr');

      // 3. Denmark market (DKK, kr.)
      provider.setMarket('DK');
      expect(provider.currentMarket, 'DK');
      expect(provider.currencyCode, 'DKK');
      expect(provider.currencySymbol, 'kr.');
      expect(provider.formatCurrency(75), '75.00 kr.');

      // 4. Finland / Germany Euro markets (EUR, €)
      provider.setMarket('FI');
      expect(provider.currentMarket, 'FI');
      expect(provider.currencyCode, 'EUR');
      expect(provider.currencySymbol, '€');
      expect(provider.formatCurrency(15.25), '15.25 €');

      provider.setMarket('DE');
      expect(provider.currentMarket, 'DE');
      expect(provider.currencyCode, 'EUR');
      expect(provider.currencySymbol, '€');

      // 5. United Kingdom (GBP, £)
      provider.setMarket('GB');
      expect(provider.currentMarket, 'GB');
      expect(provider.currencyCode, 'GBP');
      expect(provider.currencySymbol, '£');
      expect(provider.formatCurrency(25), '25.00 £');

      // 6. United States (USD, $)
      provider.setMarket('US');
      expect(provider.currentMarket, 'US');
      expect(provider.currencyCode, 'USD');
      expect(provider.currencySymbol, r'$');
      expect(provider.formatCurrency(10), r'10.00 $');
    });
  });
}
