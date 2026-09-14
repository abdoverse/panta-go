import 'dart:convert';

/// Represents GDPR-compliant cookie and local storage preferences
/// in compliance with the Swedish Electronic Communications Act (LEK 2022:482)
/// and EU GDPR (Articles 4(11), 6, 7).
class CookieConsent {
  static const String currentPolicyVersion = '2026.1';

  /// Strictly necessary cookies/storage (authentication, security, session).
  /// Always true and cannot be disabled.
  final bool necessary;

  /// Functional cookies (language preferences, theme, UI customizations).
  final bool functional;

  /// Analytics & performance cookies (anonymized metrics, crash diagnostics).
  final bool analytics;

  /// Marketing & referral cookies (campaign attribution, panting milestones).
  final bool marketing;

  /// Timestamp when consent was recorded or modified.
  final DateTime timestamp;

  /// Policy version to detect when policies are updated and require re-consent.
  final String policyVersion;

  const CookieConsent({
    this.necessary = true,
    required this.functional,
    required this.analytics,
    required this.marketing,
    required this.timestamp,
    this.policyVersion = currentPolicyVersion,
  });

  /// Factory when user clicks "Godkänn alla" / "Accept all".
  factory CookieConsent.acceptAll({String? version}) {
    return CookieConsent(
      necessary: true,
      functional: true,
      analytics: true,
      marketing: true,
      timestamp: DateTime.now().toUtc(),
      policyVersion: version ?? currentPolicyVersion,
    );
  }

  /// Factory when user clicks "Endast nödvändiga" / "Necessary only".
  factory CookieConsent.necessaryOnly({String? version}) {
    return CookieConsent(
      necessary: true,
      functional: false,
      analytics: false,
      marketing: false,
      timestamp: DateTime.now().toUtc(),
      policyVersion: version ?? currentPolicyVersion,
    );
  }

  /// Factory for granular custom preferences.
  factory CookieConsent.custom({
    required bool functional,
    required bool analytics,
    required bool marketing,
    String? version,
  }) {
    return CookieConsent(
      necessary: true,
      functional: functional,
      analytics: analytics,
      marketing: marketing,
      timestamp: DateTime.now().toUtc(),
      policyVersion: version ?? currentPolicyVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'necessary': true,
      'functional': functional,
      'analytics': analytics,
      'marketing': marketing,
      'timestamp': timestamp.toIso8601String(),
      'policyVersion': policyVersion,
    };
  }

  String toJson() => json.encode(toMap());

  factory CookieConsent.fromMap(Map<String, dynamic> map) {
    return CookieConsent(
      necessary: true,
      functional: map['functional'] == true,
      analytics: map['analytics'] == true,
      marketing: map['marketing'] == true,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      policyVersion: map['policyVersion']?.toString() ?? currentPolicyVersion,
    );
  }

  factory CookieConsent.fromJson(String source) {
    return CookieConsent.fromMap(json.decode(source) as Map<String, dynamic>);
  }

  CookieConsent copyWith({
    bool? functional,
    bool? analytics,
    bool? marketing,
    DateTime? timestamp,
    String? policyVersion,
  }) {
    return CookieConsent(
      necessary: true,
      functional: functional ?? this.functional,
      analytics: analytics ?? this.analytics,
      marketing: marketing ?? this.marketing,
      timestamp: timestamp ?? DateTime.now().toUtc(),
      policyVersion: policyVersion ?? this.policyVersion,
    );
  }
}
