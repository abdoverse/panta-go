class ApiConfig {
  static const String _defaultBaseUrl = 'http://127.0.0.1:8080';
  static const String _defaultRegion = 'eu-north-1';
  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  static String get baseUrl => _normalizedBaseUri.toString();

  static Uri get _normalizedBaseUri {
    return _configuredBaseUri(
      envName: 'API_BASE_URL',
      defaultValue: _defaultBaseUrl,
      requireProductionOverride: true,
    );
  }

  static String _requiredEnvironmentValue(String name) {
    final value = String.fromEnvironment(name, defaultValue: '').trim();
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
    final baseUri = _configuredBaseUri(
      envName: 'WS_BASE_URL',
      defaultValue: baseUrl,
      requireProductionOverride: false,
    );
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
        defaultValue: '',
      ).trim().isNotEmpty
          ? const String.fromEnvironment(
              'AWS_REGION',
              defaultValue: '',
            ).trim()
          : _fallbackRegion;

  static String get _fallbackRegion {
    if (_isProduction) {
      throw StateError('AWS_REGION must be provided for production builds.');
    }
    return _defaultRegion;
  }

  static String? get firebaseWebVapidKey {
    final value = const String.fromEnvironment(
      'FIREBASE_WEB_VAPID_KEY',
      defaultValue: '',
    ).trim();
    return value.isEmpty ? null : value;
  }

  static bool get hasFirebaseWebVapidKey => firebaseWebVapidKey != null;

  static Uri _configuredBaseUri({
    required String envName,
    required String defaultValue,
    required bool requireProductionOverride,
  }) {
    final configuredValue = _environmentValue(envName);
    final candidate = configuredValue.isEmpty ? defaultValue : configuredValue;
    if (configuredValue.isEmpty && _isProduction && requireProductionOverride) {
      throw StateError('$envName must be provided for production builds.');
    }

    final withScheme =
        candidate.contains('://') ? candidate : 'https://$candidate';
    final uri = Uri.parse(withScheme);
    final allowedSchemes = {'https', 'http'};
    if (!allowedSchemes.contains(uri.scheme) || uri.host.isEmpty) {
      throw StateError('$envName must be a valid http or https URL.');
    }

    final isLocalHost = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
    if (uri.scheme != 'https' && !isLocalHost) {
      throw StateError(
        'Panta requires HTTPS for remote runtime traffic. '
        'Use a secure $envName or a local emulator host.',
      );
    }

    return uri.replace(path: '', query: null, fragment: null);
  }

  static String _environmentValue(String name) {
    switch (name) {
      case 'API_BASE_URL':
        return const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: '',
        ).trim();
      case 'WS_BASE_URL':
        return const String.fromEnvironment(
          'WS_BASE_URL',
          defaultValue: '',
        ).trim();
      case 'AWS_REGION':
        return const String.fromEnvironment(
          'AWS_REGION',
          defaultValue: '',
        ).trim();
      case 'COGNITO_USER_POOL_ID':
        return const String.fromEnvironment(
          'COGNITO_USER_POOL_ID',
          defaultValue: '',
        ).trim();
      case 'COGNITO_CLIENT_ID':
        return const String.fromEnvironment(
          'COGNITO_CLIENT_ID',
          defaultValue: '',
        ).trim();
      case 'FIREBASE_WEB_VAPID_KEY':
        return const String.fromEnvironment(
          'FIREBASE_WEB_VAPID_KEY',
          defaultValue: '',
        ).trim();
      default:
        throw StateError('Unsupported environment variable lookup: $name');
    }
  }
}
