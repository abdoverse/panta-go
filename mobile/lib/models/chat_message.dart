import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

/// Strongly-typed enumeration of chat message types.
enum ChatMessageType {
  text,
  arrivalAlert,
}

class ChatMessage {
  final String id;
  final String requestId;
  final String senderId;
  final String senderRole; // 'user' or 'helper'
  final String senderName;
  final String text;
  final ChatMessageType messageType;
  final bool isPreset;
  final DateTime createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.text,
    this.messageType = ChatMessageType.text,
    this.isPreset = false,
    required this.createdAt,
    this.isRead = false,
  });

  /// Factory constructor for arrival at door alerts.
  factory ChatMessage.arrivalAlert({
    required String id,
    required String requestId,
    required String senderId,
    required String senderRole,
    required String senderName,
    required String text,
    DateTime? createdAt,
    bool isRead = false,
  }) {
    return ChatMessage(
      id: id,
      requestId: requestId,
      senderId: senderId,
      senderRole: senderRole,
      senderName: senderName,
      text: text,
      messageType: ChatMessageType.arrivalAlert,
      isPreset: true,
      createdAt: createdAt ?? DateTime.now(),
      isRead: isRead,
    );
  }

  /// Strongly-typed check for Ding-Dong arrival at door alerts.
  bool get isArrivalAlert => messageType == ChatMessageType.arrivalAlert;

  static ChatMessageType parseMessageType(dynamic raw) {
    if (raw == null) return ChatMessageType.text;
    final str = raw.toString().toLowerCase().trim();
    switch (str) {
      case 'arrival_alert':
      case 'arrival':
        return ChatMessageType.arrivalAlert;
      case 'text':
      default:
        return ChatMessageType.text;
    }
  }

  String get messageTypeValue {
    switch (messageType) {
      case ChatMessageType.arrivalAlert:
        return 'arrival_alert';
      case ChatMessageType.text:
        return 'text';
    }
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawType = json['messageType'] ?? json['type'];
    ChatMessageType msgType = parseMessageType(rawType);
    if (msgType == ChatMessageType.text && (rawType == null || rawType.toString().isEmpty)) {
      final text = json['text']?.toString() ?? '';
      if (text == '🛎️ Ding-Dong! I am at your door!' || json['isArrivalAlert'] == true) {
        msgType = ChatMessageType.arrivalAlert;
      }
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      requestId: json['requestId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? 'user',
      senderName: json['senderName']?.toString() ?? 'User',
      text: json['text']?.toString() ?? '',
      messageType: msgType,
      isPreset: json['isPreset'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestId': requestId,
      'senderId': senderId,
      'senderRole': senderRole,
      'senderName': senderName,
      'text': text,
      'messageType': messageTypeValue,
      'isPreset': isPreset,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? requestId,
    String? senderId,
    String? senderRole,
    String? senderName,
    String? text,
    ChatMessageType? messageType,
    bool? isPreset,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      messageType: messageType ?? this.messageType,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  static const List<String> helperPresets = [
    "🚗 I'm on my way!",
    "🚪 I'm downstairs at the entrance",
    "🛎️ I'm outside your door",
    "📦 Bags picked up, heading to recycle center",
    "🧾 Pant receipt scanned at the store",
  ];

  static const List<String> recyclerPresets = [
    "🔑 Door code is: ",
    "🚪 Bags are left outside the door",
    "🏃 Coming down now!",
    "🔔 Please ring the doorbell",
    "👍 Thank you so much!",
  ];

  types.TextMessage toFlyerMessage() {
    return types.TextMessage(
      author: types.User(
        id: senderId,
        firstName: senderName,
        role: senderRole == 'helper' ? types.Role.agent : types.Role.user,
      ),
      createdAt: createdAt.millisecondsSinceEpoch,
      id: id,
      text: text,
      status: isRead ? types.Status.seen : types.Status.delivered,
    );
  }
}
