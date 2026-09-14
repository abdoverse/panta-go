import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AdminFeedbackModel {
  final String id;
  final String userName;
  final String category;
  final String message;
  final bool contactRequested;
  final String createdAt;

  const AdminFeedbackModel({
    required this.id,
    required this.userName,
    required this.category,
    required this.message,
    required this.contactRequested,
    required this.createdAt,
  });

  factory AdminFeedbackModel.fromJson(Map<String, dynamic> json) {
    return AdminFeedbackModel(
      id: json['id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      message: json['message']?.toString() ?? '',
      contactRequested: json['contactRequested'] == true,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class AdminMarketSummary {
  final int totalRequests;
  final int activeRequests;
  final int pendingRequests;
  final int inProgressRequests;
  final int completedRequests;
  final int cancelledRequests;
  final double totalPantAmount;
  final double totalRecyclerPayout;
  final double totalHelperPayout;
  final int recyclerLimit;
  final int helperLimit;
  final int activeRecyclersCount;
  final int activeHelpersCount;

  const AdminMarketSummary({
    this.totalRequests = 0,
    this.activeRequests = 0,
    this.pendingRequests = 0,
    this.inProgressRequests = 0,
    this.completedRequests = 0,
    this.cancelledRequests = 0,
    this.totalPantAmount = 0.0,
    this.totalRecyclerPayout = 0.0,
    this.totalHelperPayout = 0.0,
    this.recyclerLimit = 20,
    this.helperLimit = 30,
    this.activeRecyclersCount = 0,
    this.activeHelpersCount = 0,
  });

  factory AdminMarketSummary.fromJson(Map<String, dynamic> json) {
    return AdminMarketSummary(
      totalRequests: (json['totalRequests'] as num?)?.toInt() ?? 0,
      activeRequests: (json['activeRequests'] as num?)?.toInt() ?? 0,
      pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 0,
      inProgressRequests: (json['inProgressRequests'] as num?)?.toInt() ?? 0,
      completedRequests: (json['completedRequests'] as num?)?.toInt() ?? 0,
      cancelledRequests: (json['cancelledRequests'] as num?)?.toInt() ?? 0,
      totalPantAmount: (json['totalPantAmount'] as num?)?.toDouble() ?? 0.0,
      totalRecyclerPayout:
          (json['totalRecyclerPayout'] as num?)?.toDouble() ?? 0.0,
      totalHelperPayout: (json['totalHelperPayout'] as num?)?.toDouble() ?? 0.0,
      recyclerLimit: (json['recyclerLimit'] as num?)?.toInt() ?? 20,
      helperLimit: (json['helperLimit'] as num?)?.toInt() ?? 30,
      activeRecyclersCount:
          (json['activeRecyclersCount'] as num?)?.toInt() ?? 0,
      activeHelpersCount: (json['activeHelpersCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CityTrendModel {
  final String cityName;
  final String countryCode;
  final double latitude;
  final double longitude;
  final int activeRequests;
  final int pendingRequests;
  final int acceptedRequests;
  final int completedRequests;
  final int activeHelpers;
  final int avgEtaMinutes;
  final String status;
  final List<String> districts;

  const CityTrendModel({
    required this.cityName,
    this.countryCode = 'SE',
    required this.latitude,
    required this.longitude,
    this.activeRequests = 0,
    this.pendingRequests = 0,
    this.acceptedRequests = 0,
    this.completedRequests = 0,
    this.activeHelpers = 0,
    this.avgEtaMinutes = 12,
    this.status = 'optimal',
    this.districts = const [],
  });

  factory CityTrendModel.fromJson(Map<String, dynamic> json) {
    return CityTrendModel(
      cityName: json['cityName']?.toString() ?? 'Unknown City',
      countryCode: json['countryCode']?.toString() ?? 'SE',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 59.3293,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 18.0686,
      activeRequests: (json['activeRequests'] as num?)?.toInt() ?? 0,
      pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 0,
      acceptedRequests: (json['acceptedRequests'] as num?)?.toInt() ?? 0,
      completedRequests: (json['completedRequests'] as num?)?.toInt() ?? 0,
      activeHelpers: (json['activeHelpers'] as num?)?.toInt() ?? 0,
      avgEtaMinutes: (json['avgEtaMinutes'] as num?)?.toInt() ?? 12,
      status: json['status']?.toString() ?? 'optimal',
      districts: (json['districts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class AdminLogModel {
  final String id;
  final String timestamp;
  final String level;
  final String category;
  final String message;
  final String city;
  final Map<String, dynamic> details;

  const AdminLogModel({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    required this.city,
    this.details = const {},
  });

  factory AdminLogModel.fromJson(Map<String, dynamic> json) {
    return AdminLogModel(
      id: json['id']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      level: json['level']?.toString() ?? 'INFO',
      category: json['category']?.toString() ?? 'GENERAL',
      message: json['message']?.toString() ?? '',
      city: json['city']?.toString() ?? 'National',
      details: json['details'] is Map<String, dynamic>
          ? json['details'] as Map<String, dynamic>
          : const {},
    );
  }
}

class AdminOverviewData {
  final AdminMarketSummary summary;
  final List<CityTrendModel> cities;

  const AdminOverviewData({
    required this.summary,
    required this.cities,
  });
}

class AdminApiService {
  final http.Client _client;

  AdminApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<AdminFeedbackModel>> fetchFeedback(
      {required String token}) async {
    try {
      final response = await _client.get(
        ApiConfig.apiUri('/api/v1/admin/feedback'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (data['feedback'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AdminFeedbackModel.fromJson)
            .toList();
      }
      debugPrint('Admin feedback failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Admin feedback error: $e');
    }
    return [];
  }

  Future<AdminOverviewData?> fetchOverview({required String token}) async {
    try {
      final uri = ApiConfig.apiUri('/api/v1/admin/overview');
      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = json.decode(response.body);
        final summaryJson = data['summary'] as Map<String, dynamic>? ?? {};
        final citiesList = (data['cities'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(CityTrendModel.fromJson)
                .toList() ??
            [];
        return AdminOverviewData(
          summary: AdminMarketSummary.fromJson(summaryJson),
          cities: citiesList,
        );
      }
      debugPrint('Admin overview failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Admin overview error: $e');
    }
    return null;
  }

  Future<List<AdminLogModel>> fetchLogs({required String token}) async {
    try {
      final uri = ApiConfig.apiUri('/api/v1/admin/logs');
      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = json.decode(response.body);
        final logsJson = data['logs'] as List<dynamic>? ?? [];
        return logsJson
            .whereType<Map<String, dynamic>>()
            .map(AdminLogModel.fromJson)
            .toList();
      }
      debugPrint('Admin logs failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Admin logs error: $e');
    }
    return [];
  }

  Future<AdminLogModel?> simulateLog({required String token}) async {
    try {
      final uri = ApiConfig.apiUri('/api/v1/admin/logs/simulate');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = json.decode(response.body);
        final logJson = data['simulatedLog'] as Map<String, dynamic>?;
        if (logJson != null) {
          return AdminLogModel.fromJson(logJson);
        }
      }
      debugPrint('Admin simulate log failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Admin simulate log error: $e');
    }
    return null;
  }

  Future<List<UserBlockModel>> fetchUserBlocks({
    required String token,
    String? status,
  }) async {
    try {
      final query = status != null ? '?status=$status' : '';
      final uri = ApiConfig.apiUri('/api/v1/admin/users/blocks$query');
      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = json.decode(response.body);
        final blocksList = data['blocks'] as List<dynamic>? ?? [];
        return blocksList
            .whereType<Map<String, dynamic>>()
            .map(UserBlockModel.fromJson)
            .toList();
      }
      debugPrint('Admin fetchUserBlocks failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Admin fetchUserBlocks error: $e');
    }
    return [];
  }

  Future<bool> blockUser({
    required String token,
    required String userId,
    required String reason,
    required String caseReferenceId,
    String? email,
    String? expiresAt,
  }) async {
    try {
      final uri = ApiConfig.apiUri('/api/v1/admin/users/block');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'userId': userId,
          'email': email ?? '',
          'reason': reason,
          'caseReferenceId': caseReferenceId,
          if (expiresAt != null && expiresAt.isNotEmpty) 'expiresAt': expiresAt,
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Admin blockUser error: $e');
      return false;
    }
  }

  Future<bool> unblockUser({
    required String token,
    required String userId,
    required String reason,
    required String caseReferenceId,
    String? email,
  }) async {
    try {
      final uri = ApiConfig.apiUri('/api/v1/admin/users/unblock');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'userId': userId,
          'email': email ?? '',
          'reason': reason,
          'caseReferenceId': caseReferenceId,
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Admin unblockUser error: $e');
      return false;
    }
  }
}

class UserBlockModel {
  final String userId;
  final String email;
  final String status;
  final String reason;
  final String caseReferenceId;
  final String blockedAt;
  final String blockedBy;
  final String? expiresAt;
  final String? unblockedAt;
  final String? unblockedBy;
  final String? unblockReason;

  const UserBlockModel({
    required this.userId,
    this.email = '',
    required this.status,
    required this.reason,
    required this.caseReferenceId,
    required this.blockedAt,
    required this.blockedBy,
    this.expiresAt,
    this.unblockedAt,
    this.unblockedBy,
    this.unblockReason,
  });

  factory UserBlockModel.fromJson(Map<String, dynamic> json) {
    return UserBlockModel(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'BLOCKED',
      reason: json['reason']?.toString() ?? '',
      caseReferenceId: json['caseReferenceId']?.toString() ?? '',
      blockedAt: json['blockedAt']?.toString() ?? '',
      blockedBy: json['blockedBy']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString(),
      unblockedAt: json['unblockedAt']?.toString(),
      unblockedBy: json['unblockedBy']?.toString(),
      unblockReason: json['unblockReason']?.toString(),
    );
  }
}
