import 'package:flutter_test/flutter_test.dart';
import 'package:panta/models/chat_message.dart';
import 'package:panta/models/request_model.dart';

void main() {
  group('In-App Real-Time Chat (plan-69)', () {
    test('ChatMessage serializes and deserializes cleanly', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg-123',
        requestId: 'req-abc',
        senderId: 'user-1',
        senderRole: 'user',
        senderName: 'Anna',
        text: 'Door code is 1234, 2nd floor',
        isPreset: true,
        createdAt: now,
      );

      final json = msg.toJson();
      expect(json['id'], 'msg-123');
      expect(json['requestId'], 'req-abc');
      expect(json['senderRole'], 'user');
      expect(json['isPreset'], true);
      expect(json['text'], 'Door code is 1234, 2nd floor');

      final deserialized = ChatMessage.fromJson(json);
      expect(deserialized.id, 'msg-123');
      expect(deserialized.text, 'Door code is 1234, 2nd floor');
      expect(deserialized.isPreset, true);
    });

    test('presets contain expected quick communication chips', () {
      expect(ChatMessage.helperPresets, isNotEmpty);
      expect(ChatMessage.helperPresets.any((p) => p.contains('way')), isTrue);
      expect(ChatMessage.helperPresets.any((p) => p.contains('entrance')), isTrue);

      expect(ChatMessage.recyclerPresets, isNotEmpty);
      expect(ChatMessage.recyclerPresets.any((p) => p.contains('code')), isTrue);
      expect(ChatMessage.recyclerPresets.any((p) => p.contains('door')), isTrue);
    });

    test('RecyclingRequest stores and updates chat messages', () {
      final req = RecyclingRequest(
        id: 'req-chat',
        title: 'Recycling pickup',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Stockholm',
      );

      expect(req.messages, isEmpty);

      final msg = ChatMessage(
        id: 'm1',
        requestId: 'req-chat',
        senderId: 'helper-1',
        senderRole: 'helper',
        senderName: 'Erik',
        text: "I'm downstairs!",
        createdAt: DateTime.now(),
      );

      final updated = req.copyWith(messages: [msg]);
      expect(updated.messages.length, 1);
      expect(updated.messages.first.text, "I'm downstairs!");
      expect(updated.messages.first.senderName, 'Erik');
    });
  });
}
