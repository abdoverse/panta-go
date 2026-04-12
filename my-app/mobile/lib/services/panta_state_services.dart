import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/request_model.dart';

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

class PantaAuthState {
  String? currentUserId;
  String? currentUserDisplayName;
  bool isHelper = false;
  String? pendingSignupEmail;
  String? pendingSignupUsername;

  bool get isAuthenticated => currentUserId != null;

  void updateSession({
    required String? userId,
    required String? displayName,
    required bool helper,
  }) {
    currentUserId = userId;
    currentUserDisplayName = displayName;
    isHelper = helper;
  }

  void cachePendingSignup({
    required String? email,
    required String? username,
  }) {
    pendingSignupEmail = email;
    pendingSignupUsername = username;
  }

  void clearPendingSignup() {
    pendingSignupEmail = null;
    pendingSignupUsername = null;
  }

  void clearSession() {
    currentUserId = null;
    currentUserDisplayName = null;
    isHelper = false;
    clearPendingSignup();
  }
}

class PantaRequestState {
  List<RecyclingRequest> _requests = [];
  bool isLoading = false;

  List<RecyclingRequest> get requests => _requests;

  void replaceAll(List<RecyclingRequest> requests) {
    _requests = List<RecyclingRequest>.from(requests);
  }

  void upsert(RecyclingRequest request) {
    final existingIndex = _requests.indexWhere((item) => item.id == request.id);
    if (existingIndex == -1) {
      _requests = [..._requests, request];
      return;
    }

    final updated = List<RecyclingRequest>.from(_requests);
    updated[existingIndex] = request;
    _requests = updated;
  }

  void clear() {
    _requests = [];
    isLoading = false;
  }

  List<RecyclingRequest> availableJobs({
    required double? helperLatitude,
    required double? helperLongitude,
  }) {
    final jobs =
        _requests.where((r) => r.status == RequestStatus.pending).toList();
    return sortRequestsByDistance(
      jobs,
      helperLatitude: helperLatitude,
      helperLongitude: helperLongitude,
    );
  }

  List<RecyclingRequest> acceptedJobs(String? currentUserId) => _requests
      .where(
        (r) =>
            r.status == RequestStatus.accepted && r.helperId == currentUserId,
      )
      .toList();

  List<RecyclingRequest> completedJobs(String? currentUserId) => _requests
      .where(
        (r) =>
            r.status == RequestStatus.pickedUp && r.helperId == currentUserId,
      )
      .toList();

  int helperCancellationCount(String? currentUserId) => _requests
      .where(
        (r) =>
            currentUserId != null &&
            r.canceledHelperIds.contains(currentUserId),
      )
      .length;

  void handleRealtimeMessage(
    String rawMessage, {
    required RecyclingRequest Function(Map<String, dynamic> json) fromJson,
    required Future<void> Function() onRefreshRequested,
  }) {
    final chunks = rawMessage
        .split('\n')
        .map((chunk) => chunk.trim())
        .where((chunk) => chunk.isNotEmpty);

    for (final chunk in chunks) {
      try {
        final payload = json.decode(chunk);
        if (payload is! Map<String, dynamic>) {
          continue;
        }

        switch (payload['type']) {
          case 'request-updated':
            final requestPayload = payload['request'];
            if (requestPayload is Map<String, dynamic>) {
              upsert(fromJson(requestPayload));
            } else if (requestPayload is Map) {
              upsert(
                fromJson(
                  requestPayload.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              );
            }
            break;
          case 'refresh':
            onRefreshRequested();
            break;
        }
      } catch (e) {
        debugPrint('Failed to handle realtime message: $e');
      }
    }
  }
}

class PantaHelperLocationState {
  double? helperLatitude;
  double? helperLongitude;
  bool isResolving = false;

  bool get isSortingJobsByDistance =>
      helperLatitude != null && helperLongitude != null;

  String get helperLocationSortingMessage => isSortingJobsByDistance
      ? 'Closest jobs are shown first based on your current location.'
      : 'Enable location access to sort available jobs by distance.';

  void update({
    required double? latitude,
    required double? longitude,
  }) {
    helperLatitude = latitude;
    helperLongitude = longitude;
  }

  void clear() {
    helperLatitude = null;
    helperLongitude = null;
    isResolving = false;
  }
}
