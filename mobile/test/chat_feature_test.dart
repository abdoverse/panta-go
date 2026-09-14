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
      expect(deserialized.messageType, ChatMessageType.text);
      expect(deserialized.isArrivalAlert, isFalse);
      expect(deserialized.isPreset, true);
    });

    test('ChatMessage strongly-typed arrivalAlert factory and serialization', () {
      final arrival = ChatMessage.arrivalAlert(
        id: 'msg-arr-99',
        requestId: 'req-1',
        senderId: 'helper-1',
        senderRole: 'helper',
        senderName: 'Ding-Dong! Helper is at your door 🛎️',
        text: 'Erik has arrived outside your door.',
      );

      expect(arrival.messageType, ChatMessageType.arrivalAlert);
      expect(arrival.isArrivalAlert, isTrue);

      final json = arrival.toJson();
      expect(json['messageType'], 'arrival_alert');

      final restored = ChatMessage.fromJson(json);
      expect(restored.messageType, ChatMessageType.arrivalAlert);
      expect(restored.isArrivalAlert, isTrue);

      // Normal message with word "door" in text is NOT an arrival alert
      final normalWithDoor = ChatMessage(
        id: 'msg-normal',
        requestId: 'req-1',
        senderId: 'user-1',
        senderRole: 'user',
        senderName: 'Anna',
        text: 'The door code is 1234',
        createdAt: DateTime.now(),
      );
      expect(normalWithDoor.messageType, ChatMessageType.text);
      expect(normalWithDoor.isArrivalAlert, isFalse);
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
