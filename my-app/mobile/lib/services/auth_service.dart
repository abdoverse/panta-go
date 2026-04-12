import 'dart:math' as math;

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
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
    final normalizedEmail = email.trim().toLowerCase();
    final cognitoUser = CognitoUser(normalizedEmail, _userPool);
    final authDetails = AuthenticationDetails(
      username: normalizedEmail,
      password: password,
    );

    try {
      _session = await cognitoUser.authenticateUser(authDetails);
      _currentUser = cognitoUser;
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
    final normalizedEmail = email.trim().toLowerCase();
    final cognitoUser = CognitoUser(normalizedEmail, _userPool);
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
      final session = await _loadSession();
      if (session == null) {
        await _invalidateSession();
        return false;
      }
      return true;
    } catch (_) {
      await _invalidateSession();
      return false;
    }
  }

  // Get Token
  Future<String?> getToken() async {
    try {
      final session = await _loadSession();
      return session?.getIdToken().getJwtToken();
    } catch (_) {
      await _invalidateSession();
      return null;
    }
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

  bool? getCurrentUserIsHelper() {
    final role = _session?.getIdToken().payload?['nickname']?.toString().trim();
    if (role == null || role.isEmpty) {
      return null;
    }
    if (role.toLowerCase() == 'helper') {
      return true;
    }
    if (role.toLowerCase() == 'user') {
      return false;
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
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
    if (_session != null && _session!.isValid()) {
      return _session;
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
    if (restoredSession == null || !restoredSession.isValid()) {
      await _invalidateSession();
      return null;
    }

    _session = restoredSession;
    return _session;
  }

  Future<void> _clearLocalSession({CognitoUser? currentUser}) async {
    final resolvedUser =
        currentUser ?? _currentUser ?? await _userPool.getCurrentUser();
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
