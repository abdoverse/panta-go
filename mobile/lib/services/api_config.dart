class ApiConfig {
  static const String _defaultBaseUrl =
      'https://pa-b4e8e272d1194dae93b9d860991c7e74.ecs.eu-north-1.on.aws';

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

    if (uri.scheme != 'https' && !_isLocalNetworkHost(uri.host)) {
      throw StateError(
        'Panta requires HTTPS for remote API traffic. '
        'Use a secure API_BASE_URL or a local network host.',
      );
    }

    return uri.replace(path: '', query: null, fragment: null);
  }

  static bool _isLocalNetworkHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return true;
    }

    final octets = host.split('.');
    if (octets.length != 4) return false;
    final values = octets.map(int.tryParse).toList();
    if (values.any((value) => value == null || value < 0 || value > 255)) {
      return false;
    }

    final first = values[0]!;
    final second = values[1]!;
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
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

  static bool get hasCognitoConfig =>
      userPoolId.isNotEmpty && clientId.isNotEmpty;
  static String? get firebaseWebVapidKey {
    const val =
        String.fromEnvironment('FIREBASE_WEB_VAPID_KEY', defaultValue: '');
    return val.isEmpty ? null : val;
  }

  static bool get hasFirebaseWebVapidKey => firebaseWebVapidKey != null;
}
