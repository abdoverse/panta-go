import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'api_config.dart';

class ChatApiService {
  final http.Client _client;

  ChatApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<ChatMessage?> sendChatMessage({
    required String token,
    required String requestId,
    required String text,
    bool isPreset = false,
  }) async {
    try {
      final response = await _client.post(
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
        return ChatMessage.fromJson(payload);
      }
      debugPrint('Failed to send chat message: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error sending chat message: $e');
    }
    return null;
  }

  Future<List<ChatMessage>> fetchChatMessages({
    required String token,
    required String requestId,
  }) async {
    try {
      final response = await _client.get(
        ApiConfig.apiUri(
          '/api/v1/chat',
          queryParameters: {'requestId': requestId},
        ),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        final list = (payload['messages'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map((m) => ChatMessage.fromJson(m))
                .toList() ??
            [];
        return list;
      }
      debugPrint('Failed to fetch chat messages: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching chat messages: $e');
    }
    return [];
  }
}
