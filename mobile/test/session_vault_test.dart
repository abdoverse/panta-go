import 'package:flutter_test/flutter_test.dart';
import 'package:panta/services/auth_service.dart';
import 'package:panta/services/session_vault/session_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionVault - Multi-Tab Independence & Security', () {
    test('Simulates independent browser tabs without cross-tab session contamination',
        () async {
      // In a real browser, Tab 1 and Tab 2 have separate window.sessionStorage instances.
      // We simulate Tab 1 and Tab 2 via distinct SessionMemoryVault instances.
      final tab1Vault = SessionMemoryVault();
      final tab2Vault = SessionMemoryVault();

      // Anna logs in on Tab 1
      const annaJwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiQW5uYSBSZWN5Y2xlciIsInJvbGUiOiJ1c2VyIiwidXNlcklkIjoidXNlci1hbm5hIn0.sig';
      await tab1Vault.setItem('panta_custom_jwt', annaJwt);

      // Erik logs in on Tab 2
      const erikJwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiRXJpayBIZWxwZXIiLCJyb2xlIjoiaGVscGVyIiwidXNlcklkIjoidXNlci1lcmlrIn0.sig';
      await tab2Vault.setItem('panta_custom_jwt', erikJwt);

      // Verify Tab 1 still holds Anna's token exclusively
      expect(await tab1Vault.getItem('panta_custom_jwt'), equals(annaJwt));
      expect(await tab1Vault.getItem('panta_custom_jwt'), isNot(equals(erikJwt)));

      // Verify Tab 2 still holds Erik's token exclusively
      expect(await tab2Vault.getItem('panta_custom_jwt'), equals(erikJwt));
      expect(await tab2Vault.getItem('panta_custom_jwt'), isNot(equals(annaJwt)));

      // Verify logout on Tab 1 does NOT affect Tab 2
      await tab1Vault.removeItem('panta_custom_jwt');
      expect(await tab1Vault.getItem('panta_custom_jwt'), isNull);
      expect(await tab2Vault.getItem('panta_custom_jwt'), equals(erikJwt));

      // Verify Tab 2 can also logout cleanly
      await tab2Vault.removeItem('panta_custom_jwt');
      expect(await tab2Vault.getItem('panta_custom_jwt'), isNull);
    });

    test('SessionMemoryVault handles string list operations correctly', () async {
      final vault = SessionMemoryVault();
      expect(await vault.getStringList('names'), isNull);

      await vault.setStringList('names', ['user-1\u0000Anna', 'user-2\u0000Erik']);
      final retrieved = await vault.getStringList('names');
      expect(retrieved, equals(['user-1\u0000Anna', 'user-2\u0000Erik']));

      await vault.clear();
      expect(await vault.getStringList('names'), isNull);
      expect(await vault.getItem('any'), isNull);
    });

    test('CognitoSessionStorage delegates properly to SessionVault', () async {
      final vault = SessionMemoryVault();
      final cognitoStorage = CognitoSessionStorage(vault);

      await cognitoStorage.setItem('key1', 'value1');
      expect(await cognitoStorage.getItem('key1'), equals('value1'));
      expect(await vault.getItem('key1'), equals('value1'));

      final removed = await cognitoStorage.removeItem('key1');
      expect(removed, equals('value1'));
      expect(await cognitoStorage.getItem('key1'), isNull);

      await cognitoStorage.setItem('key2', 'value2');
      await cognitoStorage.clear();
      expect(await cognitoStorage.getItem('key2'), isNull);
    });

    test('SharedPreferencesSessionVault delegates to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'panta_custom_jwt': 'initial-token',
        'panta_custom_display_names': ['id\u0000Name'],
      });

      final vault = SharedPreferencesSessionVault();
      expect(await vault.getItem('panta_custom_jwt'), equals('initial-token'));
      expect(
        await vault.getStringList('panta_custom_display_names'),
        equals(['id\u0000Name']),
      );

      await vault.setItem('test_key', 'test_val');
      expect(await vault.getItem('test_key'), equals('test_val'));

      await vault.removeItem('test_key');
      expect(await vault.getItem('test_key'), isNull);
    });

    test('AuthService integrates with custom SessionVault instance', () async {
      final isolatedVault = SessionMemoryVault();
      AuthService.resetForTesting(vault: isolatedVault);

      final auth = AuthService();
      expect(auth.vault, equals(isolatedVault));

      const testJwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiQW5uYSBSZWN5Y2xlciIsInJvbGUiOiJ1c2VyIiwidXNlcklkIjoidXNlci1hbm5hIiwiZXhwIjoyNTM0MDIzMDA3OTl9.sig';
      await auth.setCustomToken(testJwt);

      expect(await auth.getToken(), equals(testJwt));
      expect(await isolatedVault.getItem('panta_custom_jwt'), equals(testJwt));

      // Verify restoreSession from vault
      final newAuth = AuthService(vault: isolatedVault);
      final restored = await newAuth.restoreSession();
      expect(restored, isTrue);
      expect(await newAuth.getCurrentDisplayName(), equals('Anna Recycler'));

      // Verify logout clears vault
      await newAuth.logout();
      expect(await isolatedVault.getItem('panta_custom_jwt'), isNull);
      expect(await newAuth.getToken(), isNull);

      // Clean up for other tests
      AuthService.resetForTesting();
    });
  });
}
