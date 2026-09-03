import 'package:flutter_test/flutter_test.dart';
import 'package:panta/services/eta_service.dart';

void main() {
  group('EtaService', () {
    test('computes ETA and milestone correctly', () {
      // 2 km apart
      final eta = EtaService.computeEta(
        helperLat: 59.3293,
        helperLng: 18.0686,
        pickupLat: 59.3400,
        pickupLng: 18.0686,
      );

      expect(eta.distanceKm, greaterThan(0.5));
      expect(eta.etaMinutes, greaterThan(0));
    });

    test('transitions milestone to arrivingSoon when under 1 km or 5 min', () {
      final milestone = EtaService.determineMilestone(
        distanceKm: 0.8,
        etaMinutes: 4,
      );

      expect(milestone, DeliveryMilestone.arrivingSoon);
    });

    test('transitions milestone to arrived when under 80 meters', () {
      final milestone = EtaService.determineMilestone(
        distanceKm: 0.05,
        etaMinutes: 0,
      );

      expect(milestone, DeliveryMilestone.arrived);
    });

    test('converts milestone to and from string accurately', () {
      const ms = DeliveryMilestone.onTheWay;
      final str = EtaService.milestoneToString(ms);
      expect(str, 'on_the_way');

      final parsed = EtaService.parseMilestone(str);
      expect(parsed, DeliveryMilestone.onTheWay);
    });
  });
}
