import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/request_model.dart';
import '../services/api_config.dart';

class PantaProvider extends ChangeNotifier {
  List<RecyclingRequest> _requests = [];
  bool _isLoading = false;

  String? _currentUserId;
  bool _isHelper = false;

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
      _requests.where((r) => r.status == RequestStatus.accepted && r.helperId == 'currentHelper').toList();

  void login(bool asHelper) {
    _isHelper = asHelper;
    fetchRequests(); // Initial fetch
    notifyListeners();
  }

  Future<void> fetchRequests({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/requests'));
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

  Future<void> createRequest(String title, DateTime from, DateTime to, String location) async {
    _isLoading = true;
    notifyListeners();

    final body = json.encode({
      'title': title,
      'scheduledFrom': from.toIso8601String(),
      'scheduledTo': to.toIso8601String(),
      'location': location,
      'imageUrl': 'assets/images/generic.png',
      'isRated': false,
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/requests'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 201) {
        // Refresh list
        await fetchRequests();
      }
    } catch (e) {
      debugPrint('Error creating request: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptRequest(String id) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/requests/accept'),
        headers: {'Content-Type': 'application/json'},
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
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/requests/complete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id}),
      );
      if (response.statusCode == 200) {
        await fetchRequests();
      }
    } catch (e) {
      debugPrint('Error completing request: $e');
    }
  }

  Future<void> rateHelper(String id, double rating) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/requests/rate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id, 'rating': rating}),
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
      status: _parseStatus(json['status']),
      helperId: json['helperId'],
      isRated: json['isRated'] ?? false,
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
