import 'package:flutter_test/flutter_test.dart';
import 'package:panta/models/request_model.dart';
import 'package:panta/providers/panta_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('"I\'m at the Door" Arrival Alert (plan-65)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
    test('RecyclingRequest stores arrivedAtDoor timestamp and supports copyWith', () {
      final now = DateTime.now();
      final req = RecyclingRequest(
        id: 'req-door-1',
        title: 'ICA Maxi cans',
        status: RequestStatus.accepted,
        scheduledFrom: now,
        scheduledTo: now.add(const Duration(hours: 1)),
        location: 'Stockholm',
        leaveAtDoor: true,
        doorInstructions: 'Code 1234, top floor',
      );

      expect(req.arrivedAtDoor, isNull);

      final arrivalTime = DateTime.now();
      final updated = req.copyWith(
        arrivedAtDoor: arrivalTime,
        milestone: 'arrived',
      );

      expect(updated.arrivedAtDoor, arrivalTime);
      expect(updated.milestone, 'arrived');
      expect(updated.leaveAtDoor, true);
      expect(updated.doorInstructions, 'Code 1234, top floor');
    });

    test('RecyclingRequest preserves arrival state across copyWith operations', () {
      final arrivalTime = DateTime(2026, 9, 4, 1, 30);
      final req = RecyclingRequest(
        id: 'req-door-2',
        title: 'Bottles',
        status: RequestStatus.accepted,
        scheduledFrom: arrivalTime,
        scheduledTo: arrivalTime,
        location: 'Solna',
        arrivedAtDoor: arrivalTime,
      );

      final completed = req.copyWith(status: RequestStatus.pickedUp);
      expect(completed.status, RequestStatus.pickedUp);
      expect(completed.arrivedAtDoor, arrivalTime);
    });

    test('PantaProvider processes helper-arrived-at-door realtime event and triggers alert', () async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final now = DateTime.now();
      final req = RecyclingRequest(
        id: 'req-door-realtime',
        title: 'Glass return',
        status: RequestStatus.accepted,
        scheduledFrom: now,
        scheduledTo: now.add(const Duration(hours: 1)),
        location: 'Stockholm',
      );
      provider.requests.add(req);

      expect(provider.requests.first.arrivedAtDoor, isNull);
      expect(provider.lastIncomingChatMessage, isNull);

      final arrivalEvent = '{"type":"helper-arrived-at-door","requestId":"req-door-realtime","title":"Ding-Dong! Helper is at your door 🛎️","message":"Erik is at your door."}';
      provider.handleRealtimeMessage(arrivalEvent);

      expect(provider.requests.first.arrivedAtDoor, isNotNull);
      expect(provider.requests.first.milestone, 'arrived');
      expect(provider.lastIncomingChatMessage, isNotNull);
      expect(provider.lastIncomingChatMessage!.text, 'Erik is at your door.');
      expect(provider.lastIncomingChatMessage!.senderName, 'Ding-Dong! Helper is at your door 🛎️');
    });

    test('PantaProvider processes push-notification realtime event and creates incoming message', () async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final pushEvent = '{"type":"push-notification","requestId":"req-push-1","title":"Alert","body":"Arrival push notification delivered"}';
      provider.handleRealtimeMessage(pushEvent);

      expect(provider.lastIncomingChatMessage, isNotNull);
      expect(provider.lastIncomingChatMessage!.text, 'Arrival push notification delivered');
    });
  });
}
