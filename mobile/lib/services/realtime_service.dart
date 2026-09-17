import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';
import 'auth_service.dart';

typedef RealtimeMessageHandler = void Function(String message);

/// Manages a single, resilient WebSocket connection for the application.
/// Eliminates redundant per-page connection attempts and prevents runaway reconnect loops.
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _isIntentionalClose = false;
  int _reconnectAttempts = 0;

  final Set<RealtimeMessageHandler> _handlers = {};

  void addHandler(RealtimeMessageHandler handler) {
    _handlers.add(handler);
  }

  void removeHandler(RealtimeMessageHandler handler) {
    _handlers.remove(handler);
  }

  void connect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    // Cancel pending reconnect timer
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final token = await AuthService().getToken();
    if (token == null) {
      _isConnecting = false;
      return;
    }

    final uri = ApiConfig.webSocketUri(queryParameters: {'token': token});

    // Cleanly close prior connection if any without triggering onDone reconnect
    await _closeChannelInternal();

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _isIntentionalClose = false;

      _subscription = channel.stream.listen(
        (message) {
          // Healthy connection: reset reconnect attempts
          _reconnectAttempts = 0;
          final msgStr = message.toString();
          for (final handler in List.of(_handlers)) {
            try {
              handler(msgStr);
            } catch (e) {
              debugPrint('Error in realtime handler: $e');
            }
          }
        },
        onError: (error) {
          debugPrint('WS Error: $error');
          _onConnectionEnded();
        },
        onDone: () {
          debugPrint('WS Closed');
          _onConnectionEnded();
        },
      );
    } catch (e) {
      debugPrint('WS Connection Error: $e');
      _onConnectionEnded();
    } finally {
      _isConnecting = false;
    }
  }

  void _onConnectionEnded() {
    if (_isIntentionalClose) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    // Exponential backoff: 3s, 6s, 9s, capped at 30s
    final delaySeconds = (_reconnectAttempts * 3).clamp(3, 30);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  Future<void> _closeChannelInternal() async {
    _isIntentionalClose = true;
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _channel?.sink.close();
      _channel = null;
    } catch (_) {}
    _isIntentionalClose = false;
  }

  void disconnect() {
    _isIntentionalClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}
