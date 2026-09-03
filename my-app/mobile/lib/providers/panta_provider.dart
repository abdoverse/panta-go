import 'dart:convert';

import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/impact_summary.dart';
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
  List<SavedAddress> _savedAddresses = const [];
  List<RequestTemplate> _requestTemplates = const [];
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
  List<SavedAddress> get savedAddresses => _savedAddresses;
  List<RequestTemplate> get requestTemplates => _requestTemplates;
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

  Future<void> fetchRequestAssets({bool silent = false}) async {
    final token = await _authService.getToken();
    if (token == null) {
      _clearAuthenticatedState();
      return;
    }

    try {
      final responses = await Future.wait([
        http.get(
          ApiConfig.apiUri('/api/v1/requests/saved-addresses'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        http.get(
          ApiConfig.apiUri('/api/v1/requests/templates'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      ]);

      final addressesResponse = responses[0];
      final templatesResponse = responses[1];
      if (addressesResponse.statusCode == 200) {
        final payload =
            json.decode(addressesResponse.body) as Map<String, dynamic>;
        final items = payload['savedAddresses'] as List<dynamic>? ?? const [];
        _savedAddresses = items
            .whereType<Map>()
            .map(
              (item) => _savedAddressFromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList(growable: false);
      } else if (!silent) {
        debugPrint(
          'Failed to load saved addresses: ${addressesResponse.statusCode}',
        );
      }

      if (templatesResponse.statusCode == 200) {
        final payload =
            json.decode(templatesResponse.body) as Map<String, dynamic>;
        final items = payload['templates'] as List<dynamic>? ?? const [];
        _requestTemplates = items
            .whereType<Map>()
            .map(
              (item) => _requestTemplateFromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList(growable: false);
      } else if (!silent) {
        debugPrint(
          'Failed to load request templates: ${templatesResponse.statusCode}',
        );
      }
    } catch (e) {
      if (!silent) {
        debugPrint('Error loading request assets: $e');
      }
    } finally {
      notifyListeners();
    }
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
      'splitPercentage': splitPercentage,
      'leaveAtDoor': leaveAtDoor,
      'doorInstructions': doorInstructions,
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

  Future<bool> saveAddressEntry(
    SavedAddress address, {
    bool silent = false,
  }) async {
    final updated = [
      address,
      ..._savedAddresses.where(
        (item) => item.location.toLowerCase() != address.location.toLowerCase(),
      ),
    ];
    final success = await _putCollection(
      path: '/api/v1/requests/saved-addresses',
      body: {
        'savedAddresses':
            updated.map((item) => item.toJson()).toList(growable: false),
      },
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
    final updated = [
      template,
      ..._requestTemplates.where(
        (item) => item.name.toLowerCase() != template.name.toLowerCase(),
      ),
    ];
    final success = await _putCollection(
      path: '/api/v1/requests/templates',
      body: {
        'templates':
            updated.map((item) => item.toJson()).toList(growable: false),
      },
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

  Future<bool> _putCollection({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final token = await _authService.getToken();
    if (token == null) {
      _clearAuthenticatedState();
      return false;
    }

    try {
      final response = await http.put(
        ApiConfig.apiUri(path),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating $path: $e');
      return false;
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

  Future<bool> completeRequest(
    String id, {
    double? receiptAmount,
    String? receiptImageUrl,
    double? splitPercentage,
    String? dropoffPhotoUrl,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    try {
      final bodyMap = <String, dynamic>{'id': id};
      if (receiptAmount != null && receiptAmount > 0) {
        bodyMap['receiptAmount'] = receiptAmount;
      }
      if (receiptImageUrl != null && receiptImageUrl.isNotEmpty) {
        bodyMap['receiptImageUrl'] = receiptImageUrl;
      }
      if (splitPercentage != null && splitPercentage > 0) {
        bodyMap['splitPercentage'] = splitPercentage;
      }
      if (dropoffPhotoUrl != null && dropoffPhotoUrl.isNotEmpty) {
        bodyMap['dropoffPhotoUrl'] = dropoffPhotoUrl;
      }

      final response = await http.post(
        ApiConfig.apiUri('/api/v1/requests/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(bodyMap),
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

  Future<bool> sendChatMessage(
    String requestId,
    String text, {
    bool isPreset = false,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        ApiConfig.apiUri('/api/v1/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'requestId': requestId,
          'text': text,
          'isPreset': isPreset,
        }),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        final message = ChatMessage.fromJson(payload);
        _appendChatMessage(message);
        return true;
      }
    } catch (e) {
      debugPrint('Error sending chat message: $e');
    }
    return false;
  }

  Future<List<ChatMessage>> fetchChatMessages(String requestId) async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        ApiConfig.apiUri('/api/v1/chat', queryParameters: {'requestId': requestId}),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        final list = (payload['messages'] as List<dynamic>?)
                ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [];
        final index = _requestState.requests.indexWhere((r) => r.id == requestId);
        if (index != -1) {
          _requestState.requests[index] =
              _requestState.requests[index].copyWith(messages: list);
          notifyListeners();
        }
        return list;
      }
    } catch (e) {
      debugPrint('Error fetching chat messages: $e');
    }
    return [];
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

  Future<ImpactSummary?> fetchImpactAnalytics() async {
    final token = await _authService.getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        ApiConfig.apiUri('/api/v1/analytics'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        return ImpactSummary.fromJson(payload);
      }
    } catch (e) {
      debugPrint('Error fetching impact analytics: $e');
    }
    return null;
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

    try {
      final bodyMap = <String, dynamic>{
        'id': requestId,
        'helperLatitude': lat,
        'helperLongitude': lng,
      };
      if (etaMinutes != null) bodyMap['etaMinutes'] = etaMinutes;
      if (milestone != null) bodyMap['milestone'] = milestone;

      final response = await http.post(
        ApiConfig.apiUri('/api/v1/requests/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(bodyMap),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        _requestState.upsert(_fromJson(payload));
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating helper location: $e');
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
      receiptImageUrl: json['receiptImageUrl']?.toString(),
      receiptAmount: json['receiptAmount'] != null
          ? double.tryParse(json['receiptAmount'].toString())
          : null,
      receiptScannedAt: json['receiptScannedAt'] != null
          ? DateTime.tryParse(json['receiptScannedAt'].toString())
          : null,
      helperLatitude: json['helperLatitude'] != null
          ? double.tryParse(json['helperLatitude'].toString())
          : null,
      helperLongitude: json['helperLongitude'] != null
          ? double.tryParse(json['helperLongitude'].toString())
          : null,
      etaMinutes: json['etaMinutes'] != null
          ? int.tryParse(json['etaMinutes'].toString())
          : null,
      milestone: json['milestone']?.toString(),
      splitPercentage: json['splitPercentage'] != null
          ? double.tryParse(json['splitPercentage'].toString()) ?? 70.0
          : 70.0,
      recyclerPayout: json['recyclerPayout'] != null
          ? double.tryParse(json['recyclerPayout'].toString())
          : null,
      helperPayout: json['helperPayout'] != null
          ? double.tryParse(json['helperPayout'].toString())
          : null,
      leaveAtDoor: json['leaveAtDoor'] == true,
      doorInstructions: json['doorInstructions']?.toString(),
      dropoffPhotoUrl: json['dropoffPhotoUrl']?.toString(),
      dropoffConfirmedAt: json['dropoffConfirmedAt'] != null
          ? DateTime.tryParse(json['dropoffConfirmedAt'].toString())
          : null,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
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

  SavedAddress _savedAddressFromJson(Map<String, dynamic> json) {
    return SavedAddress(
      label: (json['label'] ?? json['location'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
    );
  }

  RequestTemplate _requestTemplateFromJson(Map<String, dynamic> json) {
    return RequestTemplate(
      name: (json['name'] ?? json['title'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      reward: json['reward'] != null
          ? double.tryParse(json['reward'].toString()) ?? 0.0
          : 0.0,
    );
  }

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
