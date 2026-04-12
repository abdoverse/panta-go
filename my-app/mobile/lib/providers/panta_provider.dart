import 'dart:convert';

import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_localizations.dart';
import '../models/request_model.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/panta_state_services.dart' as panta_state;

double? calculateHelperReliabilityRating({
  required int completedJobs,
  required int canceledPickups,
}) {
  return panta_state.calculateHelperReliabilityRating(
    completedJobs: completedJobs,
    canceledPickups: canceledPickups,
  );
}

List<RecyclingRequest> sortRequestsByDistance(
  List<RecyclingRequest> requests, {
  double? helperLatitude,
  double? helperLongitude,
}) {
  return panta_state.sortRequestsByDistance(
    requests,
    helperLatitude: helperLatitude,
    helperLongitude: helperLongitude,
  );
}

class PantaProvider extends ChangeNotifier {
  static const _languagePreferenceKey = 'app_language_code';

  final AuthService _authService = AuthService();
  final panta_state.PantaAuthState _authState = panta_state.PantaAuthState();
  final panta_state.PantaRequestState _requestState =
      panta_state.PantaRequestState();
  final panta_state.PantaHelperLocationState _locationState =
      panta_state.PantaHelperLocationState();
  bool _isRestoringSession = true;
  Locale _locale = AppLocalizations.supportedLocales.first;

  PantaProvider() {
    _initialize();
  }

  bool get isHelper => _authState.isHelper;
  bool get isAuthenticated => _authState.isAuthenticated;
  bool get isLoading => _requestState.isLoading;
  bool get isRestoringSession => _isRestoringSession;
  List<RecyclingRequest> get requests => _requestState.requests;
  String? get currentUserDisplayName => _authState.currentUserDisplayName;
  Locale get locale => _locale;

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) {
      return;
    }

    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePreferenceKey, locale.languageCode);
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languagePreferenceKey);
    if (languageCode == null) {
      return;
    }

    final savedLocale = AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == languageCode,
      orElse: () => AppLocalizations.supportedLocales.first,
    );
    if (_locale == savedLocale) {
      return;
    }

    _locale = savedLocale;
    notifyListeners();
  }

  Future<void> _initialize() async {
    await _loadSavedLocale();
    await restoreSession();
  }

  void handleRealtimeMessage(String rawMessage) {
    _requestState.handleRealtimeMessage(
      rawMessage,
      fromJson: _fromJson,
      onRefreshRequested: () => fetchRequests(silent: true),
    );
    notifyListeners();
  }

  // For User Dashboard
  List<RecyclingRequest> get myRequests =>
      _requestState.requests; // In real app, filter by userId
  List<RecyclingRequest> get ongoingRequests => _requestState.requests
      .where((r) => r.status != RequestStatus.pickedUp)
      .toList();
  List<RecyclingRequest> get previousRequests => _requestState.requests
      .where((r) => r.status == RequestStatus.pickedUp)
      .toList();

  // For Helper Dashboard
  List<RecyclingRequest> get availableJobs => _requestState.availableJobs(
        helperLatitude: _locationState.helperLatitude,
        helperLongitude: _locationState.helperLongitude,
      );

  List<RecyclingRequest> get acceptedJobs =>
      _requestState.acceptedJobs(_authState.currentUserId);

  List<RecyclingRequest> get completedJobs =>
      _requestState.completedJobs(_authState.currentUserId);
  bool get isResolvingHelperLocation => _locationState.isResolving;
  bool get isSortingJobsByDistance => _locationState.isSortingJobsByDistance;
  String get helperLocationSortingMessage =>
      _locationState.helperLocationSortingMessage;

  int get helperCompletedCount => completedJobs.length;
  int get helperCancellationCount =>
      _requestState.helperCancellationCount(_authState.currentUserId);
  double? get helperReliabilityRating => calculateHelperReliabilityRating(
        completedJobs: helperCompletedCount,
        canceledPickups: helperCancellationCount,
      );

  Future<void> refreshHelperLocation() async {
    if (_locationState.isResolving) {
      return;
    }

    _locationState.isResolving = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationState.clear();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationState.clear();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      _locationState.update(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('Error fetching helper location: $e');
      _locationState.clear();
    } finally {
      _locationState.isResolving = false;
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password, bool asHelper) async {
    final error = await _authService.login(email, password);
    if (error == null) {
      await _refreshAuthState(
        helperOverride: asHelper,
        fallbackEmail: email,
      );
      debugPrint("Logged in as Helper/User ID: ${_authState.currentUserId}");
      notifyListeners();
      fetchRequests();
      return null;
    }
    return error;
  }

  Future<void> restoreSession() async {
    _isRestoringSession = true;
    notifyListeners();

    try {
      final restored = await _authService.restoreSession();
      if (!restored) {
        _clearAuthenticatedState(notify: false);
        return;
      }

      await _refreshAuthState();

      if (_authState.currentUserId == null) {
        await _authService.logout();
        _clearAuthenticatedState(notify: false);
        return;
      }

      await fetchRequests(silent: true);
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _clearAuthenticatedState();
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String role,
    required String name,
  }) async {
    final result = await _authService.signUp(
      email: email,
      password: password,
      role: role,
      name: name,
    );
    if (result.success) {
      _authState.cachePendingSignup(
        email: result.email,
        username: result.cognitoUsername,
      );
      return null;
    }
    return result.error;
  }

  Future<String?> confirmUser(String email, String code) async {
    final usernameToConfirm = _authState.pendingSignupUsername ??
        _authState.pendingSignupEmail ??
        email;
    final error = await _authService.confirmUser(usernameToConfirm, code);

    if (error == null) {
      _authState.clearPendingSignup();
    }

    return error;
  }

  Future<void> fetchRequests({bool silent = false}) async {
    final token = await _authService.getToken();
    if (token == null) {
      _clearAuthenticatedState();
      return;
    }

    if (!silent) {
      _setLoading(true);
      notifyListeners();
    }

    try {
      final response = await http.get(
        ApiConfig.apiUri('/api/v1/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _requestState.replaceAll(data.map((json) => _fromJson(json)).toList());
      } else {
        debugPrint('Failed to load requests: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    } finally {
      if (!silent) {
        _setLoading(false);
      }
      notifyListeners();
    }
  }

  Future<String?> _uploadRequestImage(
    Uint8List imageBytes, {
    required String fileName,
    required String mimeType,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final request = http.MultipartRequest(
      'POST',
      ApiConfig.apiUri('/api/v1/uploads/request-image'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        return payload['uploadKey'] as String?;
      }
      debugPrint(
          'Failed to upload request image: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error uploading request image: $e');
    }

    return null;
  }

  Future<bool> createRequest(
    String title,
    DateTime from,
    DateTime to,
    String location, {
    double? locationLatitude,
    double? locationLongitude,
    String description = '',
    double reward = 0.0,
    Uint8List? imageBytes,
    String? imageFileName,
    String? imageMimeType,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    _setLoading(true);
    notifyListeners();

    // Try to get FCM Token
    String? fcmToken;
    try {
      // Request permission primarily for iOS/Web
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final vapidKey = kIsWeb ? ApiConfig.firebaseWebVapidKey : null;
        if (kIsWeb && vapidKey == null) {
          debugPrint(
            'Skipping web push token because FIREBASE_WEB_VAPID_KEY is not configured.',
          );
        }

        fcmToken = await FirebaseMessaging.instance.getToken(
          vapidKey: vapidKey,
        );
        debugPrint("FCM Token: $fcmToken");
      } else {
        debugPrint('User declined or has not accepted permission');
      }
    } catch (e) {
      debugPrint("Failed to get FCM token: $e");
    }

    String? imageUploadKey;
    if (imageBytes != null &&
        imageFileName != null &&
        imageFileName.isNotEmpty &&
        imageMimeType != null &&
        imageMimeType.isNotEmpty) {
      imageUploadKey = await _uploadRequestImage(
        imageBytes,
        fileName: imageFileName,
        mimeType: imageMimeType,
      );
      if (imageUploadKey == null) {
        _setLoading(false);
        notifyListeners();
        return false;
      }
    }

    final body = json.encode({
      'title': title,
      'scheduledFrom': from.toUtc().toIso8601String(),
      'scheduledTo': to.toUtc().toIso8601String(),
      'location': location,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'description': description, // Add description
      'reward': reward, // Add reward
      'imageUrl': null,
      'imageUploadKey': imageUploadKey,
      'isRated': false,
      'creatorDeviceToken': fcmToken, // Send token
    });

    try {
      final response = await http.post(
        ApiConfig.apiUri('/api/v1/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        // Refresh list
        await fetchRequests();
        return true;
      }
      debugPrint("API Error: ${response.statusCode} - ${response.body}");
      return false;
    } catch (e) {
      debugPrint('Error creating request: $e');
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<bool> acceptRequest(String id) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        ApiConfig.apiUri('/api/v1/requests/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'id': id}),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        _requestState.upsert(_fromJson(payload));
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }
    return false;
  }

  Future<bool> completeRequest(String id) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        ApiConfig.apiUri('/api/v1/requests/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'id': id}),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        _requestState.upsert(_fromJson(payload));
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error completing request: $e');
    }
    return false;
  }

  Future<bool> cancelRequest(String id) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        ApiConfig.apiUri('/api/v1/requests/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'id': id}),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        _requestState.upsert(_fromJson(payload));
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error canceling request: $e');
    }
    return false;
  }

  Future<void> rateHelper(String id, double rating, {String? comment}) async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        ApiConfig.apiUri('/api/v1/requests/rate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id': id,
          'rating': rating,
          'comment': comment ?? '', // Pass comment field
        }),
      );
      if (response.statusCode == 200) {
        await fetchRequests();
      }
    } catch (e) {
      debugPrint('Error rating helper: $e');
    }
  }

  // --- Helpers ---

  RecyclingRequest _fromJson(Map<String, dynamic> json) {
    return RecyclingRequest(
      id: json['id'],
      title: json['title'],
      imageUrl: _parseImageUrl(json['imageUrl']),
      scheduledFrom: DateTime.parse(json['scheduledFrom']),
      scheduledTo: DateTime.parse(json['scheduledTo']),
      location: json['location'],
      locationLatitude: json['locationLatitude'] != null
          ? double.tryParse(json['locationLatitude'].toString())
          : null,
      locationLongitude: json['locationLongitude'] != null
          ? double.tryParse(json['locationLongitude'].toString())
          : null,
      description: json['description'] ?? '',
      reward: json['reward'] != null
          ? double.tryParse(json['reward'].toString()) ?? 0.0
          : 0.0,
      status: _parseStatus(json['status']),
      helperId: json['helperId'],
      canceledHelperIds: (json['canceledHelperIds'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const [],
      isRated: json['isRated'] ?? false,
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      ratingComment: json['ratingComment'],
    );
  }

  RequestStatus _parseStatus(String status) {
    switch (status) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'pickedUp':
        return RequestStatus.pickedUp;
      default:
        return RequestStatus.pending;
    }
  }

  String? _parseImageUrl(dynamic value) {
    final imageUrl = value?.toString().trim();
    if (imageUrl == null ||
        imageUrl.isEmpty ||
        imageUrl == 'assets/images/generic.png') {
      return null;
    }
    return imageUrl;
  }

  Future<void> _refreshAuthState({
    bool? helperOverride,
    String? fallbackEmail,
  }) async {
    _authState.updateSession(
      userId: await _authService.getCurrentUsername(),
      displayName: await _authService.getCurrentDisplayName(
        fallbackEmail: fallbackEmail,
      ),
      helper: helperOverride ??
          await _authService.getCurrentUserIsHelper() ??
          false,
    );
  }

  void _setLoading(bool value) {
    _requestState.isLoading = value;
  }

  void _clearAuthenticatedState({bool notify = true}) {
    _authState.clearSession();
    _requestState.clear();
    _locationState.clear();

    if (notify) {
      notifyListeners();
    }
  }
}
