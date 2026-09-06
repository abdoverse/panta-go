import 'dart:ui';

class CountryProfile {
  final String name;
  final String localeId;
  final Locale locale;
  final String currencySymbol;
  final String currencyCode;

  const CountryProfile({
    required this.name,
    required this.localeId,
    required this.locale,
    required this.currencySymbol,
    required this.currencyCode,
  });
}

class AppConstants {
  static const CountryProfile sweden = CountryProfile(
    name: 'Sweden',
    localeId: 'sv_SE',
    locale: Locale('sv', 'SE'),
    currencySymbol: 'kr',
    currencyCode: 'SEK',
  );

  static const CountryProfile usa = CountryProfile(
    name: 'United States',
    localeId: 'en_US',
    locale: Locale('en', 'US'),
    currencySymbol: '\$',
    currencyCode: 'USD',
  );

  static const CountryProfile norway = CountryProfile(
    name: 'Norway',
    localeId: 'nb_NO',
    locale: Locale('nb', 'NO'),
    currencySymbol: 'kr',
    currencyCode: 'NOK',
  );

  static const CountryProfile denmark = CountryProfile(
    name: 'Denmark',
    localeId: 'da_DK',
    locale: Locale('da', 'DK'),
    currencySymbol: 'kr.',
    currencyCode: 'DKK',
  );

  static const CountryProfile finland = CountryProfile(
    name: 'Finland',
    localeId: 'fi_FI',
    locale: Locale('fi', 'FI'),
    currencySymbol: '€',
    currencyCode: 'EUR',
  );

  static const CountryProfile germany = CountryProfile(
    name: 'Germany',
    localeId: 'de_DE',
    locale: Locale('de', 'DE'),
    currencySymbol: '€',
    currencyCode: 'EUR',
  );

  static const CountryProfile uk = CountryProfile(
    name: 'United Kingdom',
    localeId: 'en_GB',
    locale: Locale('en', 'GB'),
    currencySymbol: '£',
    currencyCode: 'GBP',
  );

  static const Map<String, CountryProfile> marketProfiles = {
    'SE': sweden,
    'NO': norway,
    'DK': denmark,
    'FI': finland,
    'DE': germany,
    'US': usa,
    'GB': uk,
    'UK': uk,
  };

  static CountryProfile getProfileForMarket(String? marketCode) {
    if (marketCode == null || marketCode.isEmpty) return sweden;
    return marketProfiles[marketCode.toUpperCase()] ?? sweden;
  }

  // Active configuration
  static const CountryProfile currentCountry = sweden;

  // Shortcuts
  static String get defaultLocaleId => currentCountry.localeId;
  static Locale get defaultLocale => currentCountry.locale;
  static String get currencySymbol => currentCountry.currencySymbol;
  static String get currencyCode => currentCountry.currencyCode;
}
