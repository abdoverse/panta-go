import "package:flutter_chat_types/flutter_chat_types.dart" as types;
class ChatMessage {
  final String id;
  final String requestId;
  final String senderId;
  final String senderRole; // 'user' or 'helper'
  final String senderName;
  final String text;
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
    this.isPreset = false,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      requestId: json['requestId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? 'user',
      senderName: json['senderName']?.toString() ?? 'User',
      text: json['text']?.toString() ?? '',
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
      'isPreset': isPreset,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
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
