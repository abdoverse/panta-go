import 'package:flutter_test/flutter_test.dart';
import 'package:panta/models/impact_summary.dart';
import 'package:panta/models/request_model.dart';

void main() {
  group('Pant History and Sustainability Analytics (plan-68)', () {
    test('ImpactSummary.fromRequests calculates recycler metrics accurately', () {
      final requests = [
        RecyclingRequest(
          id: 'req-1',
          title: 'Bottles from party',
          status: RequestStatus.pickedUp,
          scheduledFrom: DateTime.now(),
          scheduledTo: DateTime.now(),
          location: 'Vasastan',
          receiptAmount: 120.0,
          splitPercentage: 70.0,
          recyclerPayout: 84.0,
          helperPayout: 36.0,
        ),
        RecyclingRequest(
          id: 'req-2',
          title: 'ICA Maxi cans',
          status: RequestStatus.pickedUp,
          scheduledFrom: DateTime.now(),
          scheduledTo: DateTime.now(),
          location: 'Södermalm',
          receiptAmount: 80.0,
          splitPercentage: 70.0,
          recyclerPayout: 56.0,
          helperPayout: 24.0,
        ),
        RecyclingRequest(
          id: 'req-3',
          title: 'Pending bags',
          status: RequestStatus.pending,
          scheduledFrom: DateTime.now(),
          scheduledTo: DateTime.now(),
          location: 'Kungsholmen',
          receiptAmount: 0.0,
        ),
      ];

      final summary = ImpactSummary.fromRequests(requests, isHelper: false);

      expect(summary.totalPickups, 2);
      expect(summary.totalReceiptAmount, 200.0);
      expect(summary.totalEarnings, 140.0);
      expect(summary.containersRecycled, greaterThan(100));
      expect(summary.co2SavedKg, greaterThan(0));
      expect(summary.treesEquivalent, greaterThan(0));
      expect(summary.recentActivity.length, 2);
    });

    test('ImpactSummary.fromRequests calculates helper earnings correctly', () {
      final requests = [
        RecyclingRequest(
          id: 'req-1',
          title: 'Bottles',
          status: RequestStatus.pickedUp,
          scheduledFrom: DateTime.now(),
          scheduledTo: DateTime.now(),
          location: 'Vasastan',
          receiptAmount: 100.0,
          splitPercentage: 70.0,
          recyclerPayout: 70.0,
          helperPayout: 30.0,
        ),
      ];

      final helperSummary = ImpactSummary.fromRequests(requests, isHelper: true);
      expect(helperSummary.totalPickups, 1);
      expect(helperSummary.totalEarnings, 30.0);
      expect(helperSummary.totalReceiptAmount, 100.0);
    });

    test('ImpactSummary serializes and deserializes JSON correctly', () {
      final json = {
        'totalPickups': 5,
        'totalReceiptAmount': 450.5,
        'totalEarnings': 315.35,
        'containersRecycled': 300,
        'co2SavedKg': 27.0,
        'treesEquivalent': 1.28,
        'recentActivity': [
          {
            'id': 'job-1',
            'title': 'Stora Coop Pant',
            'completedAt': '2026-09-04T00:00:00.000Z',
            'receiptAmount': 150.0,
            'earnings': 105.0,
            'co2SavedKg': 12.0,
          }
        ],
      };

      final summary = ImpactSummary.fromJson(json);
      expect(summary.totalPickups, 5);
      expect(summary.totalReceiptAmount, 450.5);
      expect(summary.totalEarnings, 315.35);
      expect(summary.containersRecycled, 300);
      expect(summary.co2SavedKg, 27.0);
      expect(summary.recentActivity.length, 1);
      expect(summary.recentActivity.first.title, 'Stora Coop Pant');
    });
  });
}
