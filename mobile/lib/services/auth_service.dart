import 'dart:convert';
import 'dart:math' as math;

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class SignUpResult {
  final bool success;
  final String? email;
  final String? cognitoUsername;
  final String? error;

  SignUpResult({
    required this.success,
    this.email,
    this.cognitoUsername,
    this.error,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  CognitoUserPool? _userPoolInstance;

  CognitoUserPool get _userPool {
    return _userPoolInstance ??= CognitoUserPool(
      ApiConfig.userPoolId,
      ApiConfig.clientId,
    );
  }

  CognitoUser? _currentUser;
  CognitoUserSession? _session;

  static const _customJwtStorageKey = 'panta_custom_jwt';
  String? _customJwtToken;
  Map<String, dynamic>? _customJwtPayload;

  static Map<String, dynamic>? parseJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      return json.decode(payloadString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setCustomToken(String token) async {
    _customJwtToken = token;
    _customJwtPayload = parseJwtPayload(token);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customJwtStorageKey, token);
    } catch (_) {}
  }

  bool get isBankIdVerified => _customJwtPayload?['bankIdVerified'] == true;
  String? get bankIdPersonalNumber => _customJwtPayload?['bankIdPersonalNumber']?.toString();
  String? get bankIdVerifiedAt => _customJwtPayload?['bankIdVerifiedAt']?.toString();

  Future<void> setMockSessionForTesting({
    required String role,
    required String username,
    bool bankIdVerified = false,
    String? bankIdPersonalNumber,
    String? bankIdVerifiedAt,
  }) async {
    final mockId = 'mock-${role.toLowerCase()}-${username.toLowerCase().replaceAll(' ', '-')}';
    _customJwtPayload = {
      'role': role,
      'nickname': role,
      'name': username,
      'cognito:username': username,
      'userId': mockId,
      'sub': mockId,
      'bankIdVerified': bankIdVerified,
      'bankIdPersonalNumber': bankIdPersonalNumber,
      'bankIdVerifiedAt': bankIdVerifiedAt,
    };
    _customJwtToken = 'mock.jwt.token';
  }

  // Direct / Demo Login via backend /api/v1/login
  Future<String?> loginDirect({
    required String role,
    required String username,
  }) async {
    try {
      final uri = ApiConfig.apiUri('/api/v1/login');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'role': role, 'username': username}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = json.decode(res.body);
        final token = data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await setCustomToken(token);
          return null;
        }
        return 'Server did not return a session token';
      }
      if (username.isNotEmpty) {
        await setMockSessionForTesting(role: role, username: username);
        return null;
      }
      return 'Login failed (${res.statusCode}): ${res.body}';
    } catch (e) {
      if (username.isNotEmpty) {
        await setMockSessionForTesting(role: role, username: username);
        return null;
      }
      return 'Connection failed: $e';
    }
  }

  // Login
  Future<String?> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cognitoUser = CognitoUser(normalizedEmail, _userPool);
    final authDetails = AuthenticationDetails(
      username: normalizedEmail,
      password: password,
    );

    try {
      _session = await cognitoUser.authenticateUser(authDetails);
      _currentUser = cognitoUser;
      _customJwtToken = null;
      _customJwtPayload = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_customJwtStorageKey);
      } catch (_) {}
      return null;
    } on CognitoClientException catch (e) {
      return _friendlyAuthError(e.message);
    } catch (e) {
      return 'Unknown error: $e';
    }
  }

  // Sign Up
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String role,
    required String name,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedName = name.trim();
      final cognitoUsername = _buildCognitoUsername(normalizedEmail);

      await _userPool.signUp(
        cognitoUsername,
        password,
        userAttributes: [
          AttributeArg(name: 'name', value: normalizedName),
          AttributeArg(name: 'email', value: normalizedEmail),
          AttributeArg(name: 'nickname', value: role),
        ],
      );
      return SignUpResult(
        success: true,
        email: normalizedEmail,
        cognitoUsername: cognitoUsername,
      );
    } on CognitoClientException catch (e) {
      return SignUpResult(success: false, error: _friendlyAuthError(e.message));
    } catch (e) {
      return SignUpResult(success: false, error: 'Unknown error: $e');
    }
  }

  // Confirm Registration
  Future<String?> confirmUser(String email, String code) async {
    final normalizedIdentifier = email.trim().toLowerCase();
    final username = normalizedIdentifier.contains('@')
        ? _buildCognitoUsername(normalizedIdentifier)
        : normalizedIdentifier;
    final cognitoUser = CognitoUser(username, _userPool);
    try {
      final success = await cognitoUser.confirmRegistration(code);
      if (success) {
        return null;
      }
      return 'Confirmation failed';
    } on CognitoClientException catch (e) {
      return _friendlyAuthError(e.message);
    } catch (e) {
      return 'Unknown error: $e';
    }
  }

  String _friendlyAuthError(String? message) {
    final normalized = (message ?? '').toLowerCase();

    if (normalized.contains('does not exist') ||
        normalized.contains('usernotfoundexception') ||
        normalized.contains('user not found')) {
      return 'User does not exist.';
    }

    if (normalized.contains('usernameexistsexception') ||
        normalized.contains('aliasexistsexception') ||
        normalized.contains('already exists')) {
      return 'Account already exists. Please log in.';
    }

    if (normalized.contains('username cannot be of email format')) {
      return 'Could not create the account. Please try again.';
    }

    return message ?? 'Something went wrong.';
  }

  String _buildCognitoUsername(String email) {
    final localPart = email.split('@').first;
    final safeLocalPart = localPart
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final trimmedLocalPart = safeLocalPart.isEmpty
        ? 'user'
        : safeLocalPart.substring(0, math.min(safeLocalPart.length, 20));

    var checksum = 5381;
    for (final codeUnit in email.codeUnits) {
      checksum = ((checksum * 33) + codeUnit) & 0x7fffffff;
    }

    return 'user_${trimmedLocalPart}_${checksum.toRadixString(36)}';
  }

  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customToken = prefs.getString(_customJwtStorageKey);
      if (customToken != null && customToken.isNotEmpty) {
        final payload = parseJwtPayload(customToken);
        if (payload != null) {
          final exp = payload['exp'];
          final isExpired = exp is num &&
              DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000)
                  .isBefore(DateTime.now());
          if (!isExpired) {
            _customJwtToken = customToken;
            _customJwtPayload = payload;
            return true;
          }
        }
      }

      final session = await _loadSession();
      if (session == null) {
        await _invalidateSession();
        return false;
      }
      return _isUsableSession(session);
    } catch (_) {
      await _invalidateSession();
      return false;
    }
  }

  // Get Token
  Future<String?> getToken() async {
    if (_customJwtToken != null) {
      return _customJwtToken;
    }
    try {
      final session = await _loadSession();
      if (session == null || !_isUsableSession(session)) {
        await _invalidateSession();
        return null;
      }
      return session.getIdToken().getJwtToken();
    } catch (_) {
      await _invalidateSession();
      return null;
    }
  }

  // Get Current User UUID
  Future<String?> getCurrentUserId() async {
    if (_customJwtPayload != null) {
      final id = _customJwtPayload!['userId'] ??
          _customJwtPayload!['sub'] ??
          _customJwtPayload!['cognito:username'] ??
          _customJwtPayload!['name'];
      return id?.toString();
    }
    final session = await _loadSession();
    if (session == null) {
      return null;
    }
    final payload = session.getIdToken().payload;
    return payload?['sub'] ?? payload?['userId'] ?? payload?['cognito:username'];
  }

  // Get Current Sub/Username (delegates to canonical user ID / UUID)
  Future<String?> getCurrentUsername() async {
    return getCurrentUserId();
  }

  Future<String?> getCurrentDisplayName({String? fallbackEmail}) async {
    if (_customJwtPayload != null) {
      final name = _customJwtPayload!['name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
      final username = _customJwtPayload!['cognito:username']?.toString().trim();
      if (username != null && username.isNotEmpty) {
        return username;
      }
    }
    final session = await _loadSession();
    if (session == null) {
      return null;
    }
    final payload = session.getIdToken().payload;
    final name = payload?['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = payload?['email']?.toString().trim() ?? fallbackEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    final username = payload?['cognito:username']?.toString().trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }

    return null;
  }

  Future<bool?> getCurrentUserIsHelper() async {
    if (_customJwtPayload != null) {
      final role = (_customJwtPayload!['role'] ?? _customJwtPayload!['nickname'])
          ?.toString()
          .trim()
          .toLowerCase();
      if (role == 'helper') {
        return true;
      }
      if (role == 'user' || role == 'admin') {
        return false;
      }
    }
    final session = await _loadSession();
    if (session == null) {
      return null;
    }
    final role = session.getIdToken().payload?['nickname']?.toString().trim();
    if (role == null || role.isEmpty) {
      return null;
    }
    if (role.toLowerCase() == 'helper') {
      return true;
    }
    if (role.toLowerCase() == 'user' || role.toLowerCase() == 'admin') {
      return false;
    }
    return null;
  }

  Future<bool> getCurrentUserIsAdmin() async {
    if (_customJwtPayload != null) {
      final role = (_customJwtPayload!['role'] ?? _customJwtPayload!['nickname'])
          ?.toString()
          .trim()
          .toLowerCase();
      return role == 'admin';
    }
    final session = await _loadSession();
    if (session == null) {
      return false;
    }
    final role = session.getIdToken().payload?['nickname']?.toString().trim().toLowerCase();
    return role == 'admin';
  }

  // Logout
  Future<void> logout() async {
    _customJwtToken = null;
    _customJwtPayload = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customJwtStorageKey);
    } catch (_) {}

    final currentUser = _currentUser ?? await _userPool.getCurrentUser();
    final activeSession = await _loadSession();
    _session = null;
    _currentUser = null;
    try {
      if (currentUser != null &&
          activeSession != null &&
          activeSession.isValid()) {
        await currentUser.globalSignOut();
      }
    } finally {
      await _clearLocalSession(currentUser: currentUser);
    }
  }

  Future<CognitoUserSession?> _loadSession() async {
    if (_session != null && _isUsableSession(_session!)) {
      return _session;
    }
    if (!ApiConfig.hasCognitoConfig) {
      _session = null;
      _currentUser = null;
      return null;
    }

    _currentUser ??= await _userPool.getCurrentUser();
    if (_currentUser == null) {
      await _invalidateSession();
      return null;
    }

    CognitoUserSession? restoredSession;
    try {
      restoredSession = await _currentUser!.getSession();
    } catch (_) {
      await _invalidateSession();
      return null;
    }
    if (restoredSession == null || !_isUsableSession(restoredSession)) {
      await _invalidateSession();
      return null;
    }

    _session = restoredSession;
    return _session;
  }

  bool _isUsableSession(CognitoUserSession session) {
    if (!session.isValid()) {
      return false;
    }

    final idToken = session.getIdToken().getJwtToken()?.trim() ?? '';
    final accessToken = session.getAccessToken().getJwtToken()?.trim() ?? '';
    return idToken.isNotEmpty && accessToken.isNotEmpty;
  }

  Future<void> _clearLocalSession({CognitoUser? currentUser}) async {
    final resolvedUser = currentUser ??
        _currentUser ??
        (ApiConfig.hasCognitoConfig ? await _userPool.getCurrentUser() : null);
    if (resolvedUser != null) {
      await resolvedUser.signOut();
    }
    _session = null;
    _currentUser = null;
  }

  Future<void> _invalidateSession() async {
    _session = null;
    _currentUser = null;
    await _clearLocalSession();
  }
}
