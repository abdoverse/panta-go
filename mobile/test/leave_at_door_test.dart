import 'package:flutter_test/flutter_test.dart';
import 'package:panta/features/receipt/receipt_scanner_dialog.dart';
import 'package:panta/models/request_model.dart';

void main() {
  group('Leave at Door with Photo Confirmation (plan-56)', () {
    test('initializes RecyclingRequest with leaveAtDoor and doorInstructions', () {
      final req = RecyclingRequest(
        id: 'door-1',
        title: '3 bags of cans at door',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Stockholm, Vasastan',
        leaveAtDoor: true,
        doorInstructions: 'Code 9876, 4th floor, next to doormat',
      );

      expect(req.leaveAtDoor, isTrue);
      expect(req.doorInstructions, 'Code 9876, 4th floor, next to doormat');
      expect(req.dropoffPhotoUrl, isNull);
      expect(req.dropoffConfirmedAt, isNull);
    });

    test('updates request with dropoffPhotoUrl upon completion', () {
      final req = RecyclingRequest(
        id: 'door-2',
        title: 'Bottles outside',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 2)),
        location: 'Gothenburg',
        leaveAtDoor: true,
      );

      final now = DateTime.now();
      final completed = req.copyWith(
        status: RequestStatus.pickedUp,
        dropoffPhotoUrl: 'https://cdn.panta-go.com/proofs/photo_123.jpg',
        dropoffConfirmedAt: now,
      );

      expect(completed.leaveAtDoor, isTrue);
      expect(completed.dropoffPhotoUrl, 'https://cdn.panta-go.com/proofs/photo_123.jpg');
      expect(completed.dropoffConfirmedAt, now);
      expect(completed.status, RequestStatus.pickedUp);
    });

    test('ReceiptScanResult captures dropoffPhotoUrl correctly', () {
      const result = ReceiptScanResult(
        amount: 85.50,
        totalContainers: 45,
        storeName: 'ICA Kvantum',
        splitPercentage: 70.0,
        dropoffPhotoUrl: 'assets/images/dropoff_confirmed.jpg',
      );

      expect(result.amount, 85.50);
      expect(result.dropoffPhotoUrl, 'assets/images/dropoff_confirmed.jpg');
      expect(result.splitPercentage, 70.0);
    });
  });
}
