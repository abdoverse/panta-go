import 'dart:ui';

class CountryProfile {
  final String name;
  final String localeId;
  final String currencySymbol;
  final String currencyCode;

  const CountryProfile({
    required this.name,
    required this.localeId,
    required this.currencySymbol,
    required this.currencyCode,
  });

  Locale get locale {
    final parts = localeId.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : null);
  }
}

class AppConstants {
  static const CountryProfile sweden = CountryProfile(
    name: 'Sweden',
    localeId: 'sv_SE',
    currencySymbol: 'kr',
    currencyCode: 'SEK',
  );

  static const CountryProfile usa = CountryProfile(
    name: 'United States',
    localeId: 'en_US',
    currencySymbol: '\$',
    currencyCode: 'USD',
  );

  // Active configuration
  static const CountryProfile currentCountry = sweden;

  // Shortcuts
  static String get defaultLocaleId => currentCountry.localeId;
  static Locale get defaultLocale => currentCountry.locale;
  static String get currencySymbol => currentCountry.currencySymbol;
  static String get currencyCode => currentCountry.currencyCode;
}
