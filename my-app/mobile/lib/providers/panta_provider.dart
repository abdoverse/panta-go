import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/impact_summary.dart';
import '../models/request_model.dart';
import '../services/analytics_api_service.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/chat_api_service.dart';
import '../services/panta_state_services.dart' as panta_state;
import '../services/request_api_service.dart';

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

  final AuthService _authService;
  final RequestApiService _requestApiService;
  final ChatApiService _chatApiService;
  final AnalyticsApiService _analyticsApiService;

  final panta_state.PantaAuthState _authState = panta_state.PantaAuthState();
  final panta_state.PantaRequestState _requestState =
      panta_state.PantaRequestState();
  final panta_state.PantaHelperLocationState _locationState =
      panta_state.PantaHelperLocationState();

  List<SavedAddress> _savedAddresses = const [];
  List<RequestTemplate> _requestTemplates = const [];
  bool _isRestoringSession = true;
  Locale _locale = AppLocalizations.supportedLocales.first;

  PantaProvider({
    AuthService? authService,
    RequestApiService? requestApiService,
    ChatApiService? chatApiService,
    AnalyticsApiService? analyticsApiService,
  })  : _authService = authService ?? AuthService(),
        _requestApiService = requestApiService ?? RequestApiService(),
        _chatApiService = chatApiService ?? ChatApiService(),
        _analyticsApiService = analyticsApiService ?? AnalyticsApiService() {
    _initialize();
  }

  // --- Getters ---

  bool get isHelper => _authState.isHelper;
  bool get isAuthenticated => _authState.isAuthenticated;
  bool get isLoading => _requestState.isLoading;
  bool get isRestoringSession => _isRestoringSession;
  List<RecyclingRequest> get requests => _requestState.requests;
  List<SavedAddress> get savedAddresses => _savedAddresses;
  List<RequestTemplate> get requestTemplates => _requestTemplates;
  String? get currentUserDisplayName => _authState.currentUserDisplayName;
  Locale get locale => _locale;

  // For User Dashboard
  List<RecyclingRequest> get myRequests => _requestState.requests;
  List<RecyclingRequest> get ongoingRequests =>
      _requestState.requests.where((r) => r.status != RequestStatus.pickedUp).toList();
  List<RecyclingRequest> get previousRequests =>
      _requestState.requests.where((r) => r.status == RequestStatus.pickedUp).toList();

  ImpactSummary get userImpactSummary =>
      ImpactSummary.fromRequests(_requestState.requests, isHelper: false);

  ImpactSummary get helperImpactSummary =>
      ImpactSummary.fromRequests(_requestState.requests, isHelper: true);

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

  // --- Localization ---

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePreferenceKey, locale.languageCode);
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languagePreferenceKey);
    if (languageCode == null) return;

    final savedLocale = AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == languageCode,
      orElse: () => AppLocalizations.supportedLocales.first,
    );
    if (_locale == savedLocale) return;

    _locale = savedLocale;
    notifyListeners();
  }

  Future<void> _initialize() async {
    await _loadSavedLocale();
    await restoreSession();
  }

  // --- Realtime WebSocket Messaging ---

  void handleRealtimeMessage(String rawMessage) {
    try {
      final decoded = json.decode(rawMessage);
      if (decoded is Map<String, dynamic> && decoded['type'] == 'chat-message') {
        final messageJson = decoded['message'];
        if (messageJson is Map<String, dynamic>) {
          final newMsg = ChatMessage.fromJson(messageJson);
          _appendChatMessage(newMsg);
          return;
        }
      }
    } catch (_) {}

    _requestState.handleRealtimeMessage(
      rawMessage,
      fromJson: RequestApiService.parseRecyclingRequest,
      onRefreshRequested: () => fetchRequests(silent: true),
    );
    notifyListeners();
  }

  // --- Helper Location ---

  Future<void> refreshHelperLocation() async {
    if (_locationState.isResolving) return;

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

  // --- Authentication ---

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
      fetchRequestAssets();
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

      await Future.wait([
        fetchRequests(silent: true),
        fetchRequestAssets(silent: true),
      ]);
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

  // --- Requests & Assets API Integration ---

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
      final list = await _requestApiService.fetchRequests(token: token);
      _requestState.replaceAll(list);
    } finally {
      if (!silent) {
        _setLoading(false);
      }
      notifyListeners();
    }
  }

  Future<void> fetchRequestAssets({bool silent = false}) async {
    final token = await _authService.getToken();
    if (token == null) {
      _clearAuthenticatedState();
      return;
    }

    try {
      final results = await Future.wait([
        _requestApiService.fetchSavedAddresses(token: token),
        _requestApiService.fetchRequestTemplates(token: token),
      ]);
      _savedAddresses = results[0] as List<SavedAddress>;
      _requestTemplates = results[1] as List<RequestTemplate>;
    } catch (e) {
      if (!silent) {
        debugPrint('Error loading request assets: $e');
      }
    } finally {
      notifyListeners();
    }
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
    bool saveAddress = false,
    String? addressLabel,
    bool saveTemplate = false,
    String? templateName,
    double splitPercentage = 70.0,
    bool leaveAtDoor = false,
    String? doorInstructions,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    _setLoading(true);
    notifyListeners();

    String? fcmToken;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final vapidKey = kIsWeb ? ApiConfig.firebaseWebVapidKey : null;
        if (kIsWeb && vapidKey == null) {
          debugPrint('Skipping web push token: FIREBASE_WEB_VAPID_KEY unset.');
        }
        fcmToken = await FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
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
      imageUploadKey = await _requestApiService.uploadRequestImage(
        token: token,
        imageBytes: imageBytes,
        fileName: imageFileName,
        mimeType: imageMimeType,
      );
      if (imageUploadKey == null) {
        _setLoading(false);
        notifyListeners();
        return false;
      }
    }

    try {
      final success = await _requestApiService.createRequest(
        token: token,
        title: title,
        from: from,
        to: to,
        location: location,
        locationLatitude: locationLatitude,
        locationLongitude: locationLongitude,
        description: description,
        reward: reward,
        splitPercentage: splitPercentage,
        leaveAtDoor: leaveAtDoor,
        doorInstructions: doorInstructions,
        imageUploadKey: imageUploadKey,
        fcmToken: fcmToken,
      );

      if (success) {
        if (saveAddress) {
          await saveAddressEntry(
            SavedAddress(
              label: _normalizeLabel(addressLabel, fallback: location),
              location: location,
              latitude: locationLatitude,
              longitude: locationLongitude,
            ),
            silent: true,
          );
        }
        if (saveTemplate) {
          await saveRequestTemplate(
            RequestTemplate(
              name: _normalizeLabel(templateName, fallback: title),
              title: title,
              description: description,
              reward: reward,
            ),
            silent: true,
          );
        }
        await fetchRequests();
        return true;
      }
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<bool> saveAddressEntry(
    SavedAddress address, {
    bool silent = false,
  }) async {
    final token = await _authService.getToken();
    if (token == null) {
      _clearAuthenticatedState();
      return false;
    }

    final updated = [
      address,
      ..._savedAddresses.where(
        (item) => item.location.toLowerCase() != address.location.toLowerCase(),
      ),
    ];
    final success = await _requestApiService.saveSavedAddresses(
      token: token,
      addresses: updated,
    );
    if (success) {
      _savedAddresses = updated;
      notifyListeners();
      return true;
    }
    if (!silent) {
      debugPrint('Failed to save address entry.');
    }
    return false;
  }

  Future<bool> saveRequestTemplate(
    RequestTemplate template, {
    bool silent = false,
  }) async {
    final token = await _authService.getToken();
    if (token == null) {
      _clearAuthenticatedState();
      return false;
    }

    final updated = [
      template,
      ..._requestTemplates.where(
        (item) => item.name.toLowerCase() != template.name.toLowerCase(),
      ),
    ];
    final success = await _requestApiService.saveRequestTemplates(
      token: token,
      templates: updated,
    );
    if (success) {
      _requestTemplates = updated;
      notifyListeners();
      return true;
    }
    if (!silent) {
      debugPrint('Failed to save request template.');
    }
    return false;
  }

  Future<bool> acceptRequest(String id) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final updated = await _requestApiService.acceptRequest(token: token, id: id);
    if (updated != null) {
      _requestState.upsert(updated);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> completeRequest(
    String id, {
    double? receiptAmount,
    String? receiptImageUrl,
    double? splitPercentage,
    String? dropoffPhotoUrl,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final updated = await _requestApiService.completeRequest(
      token: token,
      id: id,
      receiptAmount: receiptAmount,
      receiptImageUrl: receiptImageUrl,
      splitPercentage: splitPercentage,
      dropoffPhotoUrl: dropoffPhotoUrl,
    );
    if (updated != null) {
      _requestState.upsert(updated);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> cancelRequest(String id) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final updated = await _requestApiService.cancelRequest(token: token, id: id);
    if (updated != null) {
      _requestState.upsert(updated);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> markArrivedAtDoor(String requestId) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final updated = await _requestApiService.markArrivedAtDoor(
      token: token,
      id: requestId,
    );
    if (updated != null) {
      _requestState.upsert(updated);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> updateHelperLocation(
    String requestId,
    double lat,
    double lng, {
    int? etaMinutes,
    String? milestone,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final updated = await _requestApiService.updateHelperLocation(
      token: token,
      id: requestId,
      lat: lat,
      lng: lng,
      etaMinutes: etaMinutes,
      milestone: milestone,
    );
    if (updated != null) {
      _requestState.upsert(updated);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> rateHelper(String id, double rating, {String? comment}) async {
    final token = await _authService.getToken();
    if (token == null) return;

    final success = await _requestApiService.rateHelper(
      token: token,
      id: id,
      rating: rating,
      comment: comment,
    );
    if (success) {
      await fetchRequests();
    }
  }

  // --- In-App Chat Integration ---

  Future<bool> sendChatMessage(
    String requestId,
    String text, {
    bool isPreset = false,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final message = await _chatApiService.sendChatMessage(
      token: token,
      requestId: requestId,
      text: text,
      isPreset: isPreset,
    );
    if (message != null) {
      _appendChatMessage(message);
      return true;
    }
    return false;
  }

  Future<List<ChatMessage>> fetchChatMessages(String requestId) async {
    final token = await _authService.getToken();
    if (token == null) return [];

    final list = await _chatApiService.fetchChatMessages(
      token: token,
      requestId: requestId,
    );
    final index = _requestState.requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requestState.requests[index] =
          _requestState.requests[index].copyWith(messages: list);
      notifyListeners();
    }
    return list;
  }

  void _appendChatMessage(ChatMessage msg) {
    final index = _requestState.requests.indexWhere((r) => r.id == msg.requestId);
    if (index != -1) {
      final req = _requestState.requests[index];
      if (!req.messages.any((m) => m.id == msg.id)) {
        final updated = List<ChatMessage>.from(req.messages)..add(msg);
        _requestState.requests[index] = req.copyWith(messages: updated);
        notifyListeners();
      }
    }
  }

  // --- Analytics Integration ---

  Future<ImpactSummary?> fetchImpactAnalytics() async {
    final token = await _authService.getToken();
    if (token == null) return null;
    return _analyticsApiService.fetchImpactAnalytics(token: token);
  }

  // --- Private Helpers ---

  String _normalizeLabel(String? value, {required String fallback}) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return fallback.trim();
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
    _savedAddresses = const [];
    _requestTemplates = const [];

    if (notify) {
      notifyListeners();
    }
  }
}
