import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panta/providers/panta_provider.dart';
import 'package:intl/intl.dart';

void main() {
  test('setLocale persists language preference', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = PantaProvider();

    // Default should be sv_SE
    expect(provider.locale.languageCode, 'sv');

    // Change to en_US
    await provider.setLocale(const Locale('en', 'US'));

    expect(provider.locale.languageCode, 'en');
    expect(Intl.defaultLocale, 'en_US');
    
    // Verify it is saved in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language_code'), 'en');

    // Simulate reloading the provider (e.g., when the app restarts)
    final newProvider = PantaProvider();
    
    // The constructor calls _initialize() asynchronously, so we wait
    await Future.delayed(const Duration(milliseconds: 100));

    // Wait, the new provider should have loaded 'en'
    expect(newProvider.locale.languageCode, 'en');
    expect(Intl.defaultLocale, 'en_US');
  });
}
