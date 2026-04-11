import 'dart:math' as math;

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
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

  final CognitoUserPool _userPool = CognitoUserPool(
    ApiConfig.userPoolId,
    ApiConfig.clientId,
  );

  CognitoUser? _currentUser;
  CognitoUserSession? _session;

  // Login
  Future<String?> login(String email, String password) async {
    final cognitoUser = CognitoUser(email, _userPool);
    final authDetails = AuthenticationDetails(
      username: email,
      password: password,
    );

    try {
      _session = await cognitoUser.authenticateUser(authDetails);
      _currentUser = cognitoUser;
      await _cacheSession(_session!);
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
    final cognitoUser = CognitoUser(email, _userPool);
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

  // Get Token
  Future<String?> getToken() async {
    if (_session == null) {
      await _loadSession();
    }

    if (_session != null) {
      if (!_session!.isValid()) {
        // Refresh token if needed
        _currentUser = CognitoUser(_currentUser?.username, _userPool);
        try {
          _session =
              await _currentUser?.refreshSession(_session!.getRefreshToken()!);
          await _cacheSession(_session!);
        } catch (e) {
          return null;
        }
      }
      return _session!.getIdToken().getJwtToken();
    }
    return null;
  }

  // Get Current Sub/Username
  String? getCurrentUsername() {
    // Backend uses ID Token claims (cognito:username)
    final payload = _session?.getIdToken().payload;
    return payload?['cognito:username'] ?? payload?['sub'];
  }

  String? getCurrentDisplayName({String? fallbackEmail}) {
    final payload = _session?.getIdToken().payload;
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

  // Logout
  Future<void> logout() async {
    if (_currentUser != null) {
      await _currentUser!.signOut();
    }
    _session = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_session');
  }

  // Session Management
  Future<void> _cacheSession(CognitoUserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    // In a real app, use SecureStorage data encryption
    // Here we serialize the session manually or just rely on re-login for simplicity if complexity is high
    // The library doesn't have a built-in "toJson" for session easily,
    // so for this MVP we will rely on active memory or just basic refresh token storage.
    // For now, simpler: do nothing and require login on restart or store refresh token.
  }

  Future<void> _loadSession() async {
    // secure storage retrieval logic would go here
  }
}
