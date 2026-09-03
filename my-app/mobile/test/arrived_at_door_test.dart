import 'package:flutter_test/flutter_test.dart';
import 'package:panta/models/request_model.dart';

void main() {
  group('"I\'m at the Door" Arrival Alert (plan-65)', () {
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
  });
}
