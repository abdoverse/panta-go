import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/request_model.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';

class PantaProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  List<RecyclingRequest> _requests = [];
  bool _isLoading = false;

  String? _currentUserId;
  bool _isHelper = false;

  String? _tempSignupUsername; // Store generated username for confirmation

  bool get isHelper => _isHelper;
  bool get isLoading => _isLoading;
  List<RecyclingRequest> get requests => _requests;

  // For User Dashboard
  List<RecyclingRequest> get myRequests => _requests; // In real app, filter by userId
  List<RecyclingRequest> get ongoingRequests =>
      _requests.where((r) => r.status != RequestStatus.pickedUp).toList();
  List<RecyclingRequest> get previousRequests =>
      _requests.where((r) => r.status == RequestStatus.pickedUp).toList();

  // For Helper Dashboard
  List<RecyclingRequest> get availableJobs =>
      _requests.where((r) => r.status == RequestStatus.pending).toList();

  List<RecyclingRequest> get acceptedJobs =>
      _requests.where((r) => r.status == RequestStatus.accepted && r.helperId == _currentUserId).toList();

  List<RecyclingRequest> get completedJobs =>
      _requests.where((r) => r.status == RequestStatus.pickedUp && r.helperId == _currentUserId).toList();

  Future<String?> login(String username, String password, bool asHelper) async {
    _isHelper = asHelper;
    // For demo, we are using the email as username
    final error = await _authService.login(username, password);
    if (error == null) {
      _currentUserId = _authService.getCurrentUsername();
      debugPrint("Logged in as Helper/User ID: $_currentUserId");
      notifyListeners();
      fetchRequests();
      return null;
    }
    return error;
  }

  Future<String?> signUp(String username, String password, String role) async {
    final result = await _authService.signUp(username, password, role);
    if (result.success) {
      _tempSignupUsername = result.username;
      return null;
    }
    return result.error;
  }

  Future<String?> confirmUser(String email, String code) async {
    // Ideally use stored username, fallback to email if somehow missing (though likely to fail if alias used)
    final usernameToConfirm = _tempSignupUsername ?? email;
    return await _authService.confirmUser(usernameToConfirm, code);
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
        Uri.parse('${ApiConfig.baseUrl}/api/v1/requests'),
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

  Future<bool> createRequest(
      String title,
      DateTime from,
      DateTime to,
      String location,
      {String description = '', double reward = 0.0} // Add optional args
  ) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    _isLoading = true;
    notifyListeners();

    // Try to get FCM Token
    String? fcmToken;
    try {
        // Request permission primarily for iOS/Web
        NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
           // On Web, you need a VAPID key. Get this from Firebase Console -> Cloud Messaging -> Web Configuration
           fcmToken = await FirebaseMessaging.instance.getToken(
             vapidKey: kIsWeb ? "BL4573IrUlN0kK8MKBbLMFCSM-TPVjleJcgAKciiCO32VEEpVuugg4iXA6G341Kp2ZQE1SqqFZokA0ADSnGXUiI" : null,
           );
           debugPrint("FCM Token: $fcmToken");
        } else {
           debugPrint('User declined or has not accepted permission');
        }
    } catch (e) {
        debugPrint("Failed to get FCM token: $e");
    }

    final body = json.encode({
      'title': title,
      'scheduledFrom': from.toUtc().toIso8601String(),
      'scheduledTo': to.toUtc().toIso8601String(),
      'location': location,
      'description': description, // Add description
      'reward': reward,           // Add reward
      'imageUrl': 'assets/images/generic.png',
      'isRated': false,
      'creatorDeviceToken': fcmToken, // Send token
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/requests'),
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
        Uri.parse('${ApiConfig.baseUrl}/api/v1/requests/accept'),
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

  Future<void> completeRequest(String id) async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/requests/complete'),
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
      debugPrint('Error completing request: $e');
    }
  }

  Future<void> rateHelper(String id, double rating, {String? comment}) async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/requests/rate'),
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
      description: json['description'] ?? '',
      reward: json['reward'] != null ? double.tryParse(json['reward'].toString()) ?? 0.0 : 0.0,
      status: _parseStatus(json['status']),
      helperId: json['helperId'],
      isRated: json['isRated'] ?? false,
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
      ratingComment: json['ratingComment'],
    );
  }

  RequestStatus _parseStatus(String status) {
    switch (status) {
      case 'accepted': return RequestStatus.accepted;
      case 'pickedUp': return RequestStatus.pickedUp;
      default: return RequestStatus.pending;
    }
  }
}
