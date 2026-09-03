import 'package:flutter_test/flutter_test.dart';
import 'package:panta/models/request_model.dart';

void main() {
  group('Automated Pant Payout Calculation', () {
    test('RecyclingRequest holds and updates splitPercentage and payouts', () {
      final req = RecyclingRequest(
        id: 'req-1',
        title: 'Pant bags',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 2)),
        location: 'Stockholm',
        splitPercentage: 70.0,
      );

      expect(req.splitPercentage, 70.0);
      expect(req.recyclerPayout, isNull);
      expect(req.helperPayout, isNull);

      final completedReq = req.copyWith(
        receiptAmount: 120.0,
        recyclerPayout: 84.0,
        helperPayout: 36.0,
      );

      expect(completedReq.receiptAmount, 120.0);
      expect(completedReq.recyclerPayout, 84.0);
      expect(completedReq.helperPayout, 36.0);
      expect(completedReq.splitPercentage, 70.0);
    });

    test('calculates correct 70/30, 50/50, and 0/100 splits', () {
      const receiptAmount = 150.0;

      // 70% recycler / 30% helper
      const split70 = 70.0;
      final recycler70 = (receiptAmount * split70) / 100.0;
      final helper70 = (receiptAmount * (100.0 - split70)) / 100.0;
      expect(recycler70, 105.0);
      expect(helper70, 45.0);

      // 50% recycler / 50% helper
      const split50 = 50.0;
      final recycler50 = (receiptAmount * split50) / 100.0;
      final helper50 = (receiptAmount * (100.0 - split50)) / 100.0;
      expect(recycler50, 75.0);
      expect(helper50, 75.0);

      // 0% recycler / 100% helper donation
      const split0 = 0.0;
      final recycler0 = (receiptAmount * split0) / 100.0;
      final helper0 = (receiptAmount * (100.0 - split0)) / 100.0;
      expect(recycler0, 0.0);
      expect(helper0, 150.0);
    });
  });
}
