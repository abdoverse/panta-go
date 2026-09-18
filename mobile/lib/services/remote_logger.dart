import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class RemoteLogger {
  static void init() {
    if (!kDebugMode) return;

    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      originalDebugPrint(message, wrapWidth: wrapWidth);
      _sendToBackend('DEBUG', message ?? 'null');
    };

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (originalOnError != null) originalOnError(details);
      _sendToBackend('ERROR', details.toString());
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _sendToBackend('FATAL', '$error\n$stack');
      return true;
    };
  }

  static Future<void> _sendToBackend(String level, String message) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      await http.post(
        Uri.parse('$baseUrl/api/v1/dev/logs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'level': level,
          'message': message,
          'time': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      // Silently fail if backend is unreachable so we don't cause infinite loops
    }
  }
}
