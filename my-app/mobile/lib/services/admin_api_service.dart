import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

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
    this.recyclerLimit = 10,
    this.helperLimit = 15,
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
      totalRecyclerPayout: (json['totalRecyclerPayout'] as num?)?.toDouble() ?? 0.0,
      totalHelperPayout: (json['totalHelperPayout'] as num?)?.toDouble() ?? 0.0,
      recyclerLimit: (json['recyclerLimit'] as num?)?.toInt() ?? 10,
      helperLimit: (json['helperLimit'] as num?)?.toInt() ?? 15,
      activeRecyclersCount: (json['activeRecyclersCount'] as num?)?.toInt() ?? 0,
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
}
