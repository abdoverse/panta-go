class ApiConfig {
  static const String _defaultBaseUrl =
      'https://pa-ec5659fcd7824996910b75e3c67c48e2.ecs.eu-north-1.on.aws';

  static String get baseUrl => _normalizedBaseUri.toString();

  static Uri get _normalizedBaseUri {
    final configuredValue = const String.fromEnvironment('API_BASE_URL',
            defaultValue: _defaultBaseUrl)
        .trim();
    final withScheme = configuredValue.contains('://')
        ? configuredValue
        : 'https://$configuredValue';
    final uri = Uri.parse(withScheme);
    final allowedSchemes = {'https', 'http'};
    if (!allowedSchemes.contains(uri.scheme) || uri.host.isEmpty) {
      throw StateError('API_BASE_URL must be a valid http or https URL.');
    }

    final isLocalHost = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
    if (uri.scheme != 'https' && !isLocalHost) {
      throw StateError(
        'Panta requires HTTPS for remote API traffic. '
        'Use a secure API_BASE_URL or a local emulator host.',
      );
    }

    return uri.replace(path: '', query: null, fragment: null);
  }

  static Uri apiUri(String path, {Map<String, String>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return _normalizedBaseUri.replace(
      path: normalizedPath,
      queryParameters: queryParameters,
    );
  }

  static Uri webSocketUri({Map<String, String>? queryParameters}) {
    final baseUri = _normalizedBaseUri;
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri.replace(
      scheme: wsScheme,
      path: '/api/v1/ws',
      queryParameters: queryParameters,
    );
  }

  static const String userPoolId = 'eu-north-1_Rg7i36e8Q';
  static const String clientId = '7qmiaaqn1dhhfedhr7kcgvp074';
  static const String region = 'eu-north-1';

  static bool get hasCognitoConfig => userPoolId.isNotEmpty && clientId.isNotEmpty;
  static String? get firebaseWebVapidKey {
    const val = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY', defaultValue: '');
    return val.isEmpty ? null : val;
  }
  static bool get hasFirebaseWebVapidKey => firebaseWebVapidKey != null;
}
