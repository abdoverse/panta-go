import 'dart:convert';

import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/request_model.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';

double? calculateHelperReliabilityRating({
  required int completedJobs,
  required int canceledPickups,
}) {
  if (completedJobs == 0 && canceledPickups == 0) {
    return null;
  }
  if (canceledPickups == 0) {
    return 5;
  }

  final completionRatio = completedJobs / (completedJobs + canceledPickups);
  final score = 1 + (completionRatio * 4);
  return double.parse(score.clamp(1, 5).toStringAsFixed(1));
}

double? calculateDistanceInKilometers({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  final meters = Geolocator.distanceBetween(
    fromLatitude,
    fromLongitude,
    toLatitude,
    toLongitude,
  );
  return double.parse((meters / 1000).toStringAsFixed(1));
}

List<RecyclingRequest> sortRequestsByDistance(
  List<RecyclingRequest> requests, {
  double? helperLatitude,
  double? helperLongitude,
}) {
  final sorted = List<RecyclingRequest>.from(requests);
  if (helperLatitude == null || helperLongitude == null) {
    return sorted;
  }

  double? distanceFor(RecyclingRequest request) {
    final latitude = request.locationLatitude;
    final longitude = request.locationLongitude;
    if (latitude == null || longitude == null) {
      return null;
    }
    return calculateDistanceInKilometers(
      fromLatitude: helperLatitude,
      fromLongitude: helperLongitude,
      toLatitude: latitude,
      toLongitude: longitude,
    );
  }

  sorted.sort((a, b) {
    final distanceA = distanceFor(a);
    final distanceB = distanceFor(b);
    if (distanceA == null && distanceB == null) {
      return a.scheduledFrom.compareTo(b.scheduledFrom);
    }
    if (distanceA == null) {
      return 1;
    }
    if (distanceB == null) {
      return -1;
    }
    final byDistance = distanceA.compareTo(distanceB);
    if (byDistance != 0) {
      return byDistance;
    }
    return a.scheduledFrom.compareTo(b.scheduledFrom);
  });

  return sorted;
}

class PantaProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  List<RecyclingRequest> _requests = [];
  bool _isLoading = false;

  String? _currentUserId;
  String? _currentUserDisplayName;
  bool _isHelper = false;
  double? _helperLatitude;
  double? _helperLongitude;
  bool _isResolvingHelperLocation = false;

  String? _pendingSignupEmail;
  String? _pendingSignupUsername;

  bool get isHelper => _isHelper;
  bool get isLoading => _isLoading;
  List<RecyclingRequest> get requests => _requests;
  String? get currentUserDisplayName => _currentUserDisplayName;

  // For User Dashboard
  List<RecyclingRequest> get myRequests =>
      _requests; // In real app, filter by userId
  List<RecyclingRequest> get ongoingRequests =>
      _requests.where((r) => r.status != RequestStatus.pickedUp).toList();
  List<RecyclingRequest> get previousRequests =>
      _requests.where((r) => r.status == RequestStatus.pickedUp).toList();

  // For Helper Dashboard
  List<RecyclingRequest> get availableJobs {
    final jobs = _requests
        .where((r) =>
            r.status == RequestStatus.pending &&
            (_currentUserId == null ||
                !r.canceledHelperIds.contains(_currentUserId)))
        .toList();
    return sortRequestsByDistance(
      jobs,
      helperLatitude: _helperLatitude,
      helperLongitude: _helperLongitude,
    );
  }

  List<RecyclingRequest> get acceptedJobs => _requests
      .where((r) =>
          r.status == RequestStatus.accepted && r.helperId == _currentUserId)
      .toList();

  List<RecyclingRequest> get completedJobs => _requests
      .where((r) =>
          r.status == RequestStatus.pickedUp && r.helperId == _currentUserId)
      .toList();
  bool get isResolvingHelperLocation => _isResolvingHelperLocation;
  bool get isSortingJobsByDistance =>
      _helperLatitude != null && _helperLongitude != null;
  String get helperLocationSortingMessage => isSortingJobsByDistance
      ? 'Closest jobs are shown first based on your current location.'
      : 'Enable location access to sort available jobs by distance.';

  int get helperCompletedCount => completedJobs.length;
  int get helperCancellationCount => _requests
      .where((r) =>
          _currentUserId != null &&
          r.canceledHelperIds.contains(_currentUserId))
      .length;
  double? get helperReliabilityRating => calculateHelperReliabilityRating(
        completedJobs: helperCompletedCount,
        canceledPickups: helperCancellationCount,
      );

  Future<void> refreshHelperLocation() async {
    if (_isResolvingHelperLocation) {
      return;
    }

    _isResolvingHelperLocation = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _helperLatitude = null;
        _helperLongitude = null;
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _helperLatitude = null;
        _helperLongitude = null;
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _helperLatitude = position.latitude;
      _helperLongitude = position.longitude;
    } catch (e) {
      debugPrint('Error fetching helper location: $e');
      _helperLatitude = null;
      _helperLongitude = null;
    } finally {
      _isResolvingHelperLocation = false;
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password, bool asHelper) async {
    _isHelper = asHelper;
    final error = await _authService.login(email, password);
    if (error == null) {
      _currentUserId = _authService.getCurrentUsername();
      _currentUserDisplayName =
          _authService.getCurrentDisplayName(fallbackEmail: email);
      debugPrint("Logged in as Helper/User ID: $_currentUserId");
      notifyListeners();
      fetchRequests();
      return null;
    }
    return error;
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
      _pendingSignupEmail = result.email;
      _pendingSignupUsername = result.cognitoUsername;
      return null;
    }
    return result.error;
  }

  Future<String?> confirmUser(String email, String code) async {
    final usernameToConfirm =
        _pendingSignupUsername ?? _pendingSignupEmail ?? email;
    final error = await _authService.confirmUser(usernameToConfirm, code);

    if (error == null) {
      _pendingSignupEmail = null;
      _pendingSignupUsername = null;
    }

    return error;
  }

  Future<void> fetchRequests({bool silent = false}) async {
    final token = await _authService.getToken();
    if (token == null) return;

    if (!silent) {
      _isLoading = true;
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
        _requests = data.map((json) => _fromJson(json)).toList();
      } else {
        debugPrint('Failed to load requests: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
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

    _isLoading = true;
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
        // On Web, you need a VAPID key. Get this from Firebase Console -> Cloud Messaging -> Web Configuration
        fcmToken = await FirebaseMessaging.instance.getToken(
          vapidKey: kIsWeb
              ? "BL4573IrUlN0kK8MKBbLMFCSM-TPVjleJcgAKciiCO32VEEpVuugg4iXA6G341Kp2ZQE1SqqFZokA0ADSnGXUiI"
              : null,
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
        _isLoading = false;
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
      'imageUrl': imageUploadKey == null ? 'assets/images/generic.png' : null,
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
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptRequest(String id) async {
    final token = await _authService.getToken();
    if (token == null) return;

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
        await fetchRequests();
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }
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
        await fetchRequests();
        return true;
      }
    } catch (e) {
      debugPrint('Error completing request: $e');
    }
    return false;
  }

  Future<void> cancelRequest(String id) async {
    final token = await _authService.getToken();
    if (token == null) return;

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
        await fetchRequests();
      }
    } catch (e) {
      debugPrint('Error canceling request: $e');
    }
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
      imageUrl: json['imageUrl'] ?? 'assets/images/generic.png',
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
}
