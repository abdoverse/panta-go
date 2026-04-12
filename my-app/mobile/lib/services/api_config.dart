class ApiConfig {
  static const String _defaultBaseUrl = 'http://127.0.0.1:8080';
  static const String _defaultRegion = 'eu-north-1';

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

  static String _requiredEnvironmentValue(String name) {
    final value = const String.fromEnvironment(name, defaultValue: '').trim();
    if (value.isEmpty) {
      throw StateError('$name must be provided at build time.');
    }
    return value;
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

  static String get userPoolId => _requiredEnvironmentValue(
        'COGNITO_USER_POOL_ID',
      );

  static String get clientId => _requiredEnvironmentValue(
        'COGNITO_CLIENT_ID',
      );

  static String get region => const String.fromEnvironment(
        'AWS_REGION',
        defaultValue: _defaultRegion,
      ).trim();

  static String? get firebaseWebVapidKey {
    final value = const String.fromEnvironment(
      'FIREBASE_WEB_VAPID_KEY',
      defaultValue: '',
    ).trim();
    return value.isEmpty ? null : value;
  }

  static bool get hasFirebaseWebVapidKey => firebaseWebVapidKey != null;
}
