import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/market_notification.dart';
import 'api_config.dart';

/// Service responsible for fetching market-level operational notices and status
/// updates directly from the server via standard HTTP requests (no push notifications required).
class MarketNotificationService {
  static const String _dismissedPrefKey =
      'panta_dismissed_market_notifications_v1';
  final http.Client _client;
  final SharedPreferences? _prefs;

  MarketNotificationService({http.Client? client, SharedPreferences? prefs})
      : _client = client ?? http.Client(),
        _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    return await SharedPreferences.getInstance();
  }

  /// Fetches active notifications targeted for [market] (e.g. "SE", "NO") plus
  /// any global ("ALL") system-wide notices.
  Future<List<MarketNotification>> fetchMarketNotifications(
      {String? market}) async {
    try {
      final queryParams =
          (market != null && market.isNotEmpty) ? {'market': market} : null;
      final uri = ApiConfig.apiUri('/api/v1/market/notifications',
          queryParameters: queryParams);
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic> &&
            decoded['notifications'] is List) {
          final list = (decoded['notifications'] as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => MarketNotification.fromJson(item))
              .toList();
          return list;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching market notifications: $e');
      return [];
    }
  }

  /// Retrieves the set of notification IDs that the user has already dismissed locally.
  Future<Set<String>> getDismissedNotificationIds() async {
    try {
      final prefs = await _getPrefs();
      final list = prefs.getStringList(_dismissedPrefKey);
      return (list ?? []).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Persists a dismissed notification ID so it is not displayed again during this session.
  Future<void> dismissNotification(String id) async {
    try {
      final prefs = await _getPrefs();
      final list = prefs.getStringList(_dismissedPrefKey) ?? [];
      if (!list.contains(id)) {
        list.add(id);
        await prefs.setStringList(_dismissedPrefKey, list);
      }
    } catch (_) {}
  }

  /// Resets all locally dismissed notification IDs.
  Future<void> clearDismissed() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_dismissedPrefKey);
    } catch (_) {}
  }
}
