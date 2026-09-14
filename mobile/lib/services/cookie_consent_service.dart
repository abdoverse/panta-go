import 'package:shared_preferences/shared_preferences.dart';
import '../models/cookie_consent.dart';

/// Service responsible for persisting and checking GDPR cookie consent decisions
/// under Swedish LEK 2022:482 & EU GDPR.
class CookieConsentService {
  static const String prefKey = 'panta_gdpr_cookie_consent_v1';

  final SharedPreferences? _prefs;

  CookieConsentService({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    return await SharedPreferences.getInstance();
  }

  Future<CookieConsent?> getConsent() async {
    final prefs = await _getPrefs();
    final jsonString = prefs.getString(prefKey);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      final consent = CookieConsent.fromJson(jsonString);
      return consent;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConsent(CookieConsent consent) async {
    final prefs = await _getPrefs();
    await prefs.setString(prefKey, consent.toJson());
  }

  Future<void> clearConsent() async {
    final prefs = await _getPrefs();
    await prefs.remove(prefKey);
  }

  bool hasValidConsent(CookieConsent? consent) {
    if (consent == null) return false;
    return consent.policyVersion == CookieConsent.currentPolicyVersion;
  }
}
