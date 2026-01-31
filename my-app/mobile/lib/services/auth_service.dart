import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // Import uuid
import 'api_config.dart';

class AuthService {
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
      return e.message;
    } catch (e) {
      return 'Unknown error: $e';
    }
  }

  // Sign Up
  Future<String?> signUp(String email, String password) async {
    try {
      // Generate a unique username because 'email' cannot be the username when email alias is enabled
      final username = const Uuid().v4();

      await _userPool.signUp(
        username,
        password,
        userAttributes: [
          AttributeArg(name: 'email', value: email),
        ],
      );
      return null;
    } on CognitoClientException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unknown error: $e';
    }
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
          _session = await _currentUser?.refreshSession(_session!.getRefreshToken()!);
          await _cacheSession(_session!);
        } catch (e) {
          return null;
        }
      }
      return _session!.getIdToken().getJwtToken();
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
