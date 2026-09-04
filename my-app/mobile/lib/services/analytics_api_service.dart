import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/impact_summary.dart';
import 'api_config.dart';

class AnalyticsApiService {
  final http.Client _client;

  AnalyticsApiService({http.Client? client})
      : _client = client ?? http.Client();

  Future<ImpactSummary?> fetchImpactAnalytics({required String token}) async {
    try {
      final response = await _client.get(
        ApiConfig.apiUri('/api/v1/analytics'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        return ImpactSummary.fromJson(payload);
      }
      debugPrint('Failed to load analytics: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching impact analytics: $e');
    }
    return null;
  }
}
