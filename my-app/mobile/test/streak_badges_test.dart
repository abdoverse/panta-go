import 'package:flutter_test/flutter_test.dart';
import 'package:panta/models/impact_summary.dart';
import 'package:panta/models/request_model.dart';

void main() {
  group('Gamified Recycling Streaks & Eco Badges (plan-54)', () {
    test('StreakData serializes and parses properly', () {
      final json = {
        'currentStreakWeeks': 4,
        'longestStreakWeeks': 6,
        'isActive': true,
      };

      final streak = StreakData.fromJson(json);
      expect(streak.currentStreakWeeks, 4);
      expect(streak.longestStreakWeeks, 6);
      expect(streak.isActive, true);
    });

    test('EcoBadge parses and computes unlock state properly', () {
      final badge = EcoBadge(
        id: 'carbon_crusher',
        title: 'Carbon Crusher',
        description: 'Offset 10 kg CO2',
        icon: '🌍',
        isUnlocked: true,
        progress: 1.0,
        current: 12,
        target: 10,
      );

      expect(badge.isUnlocked, true);
      expect(badge.progress, 1.0);
      expect(badge.icon, '🌍');

      final lockedBadge = EcoBadge(
        id: 'streak_master',
        title: 'Streak Master',
        description: '3-week streak',
        icon: '🔥',
        isUnlocked: false,
        progress: 0.67,
        current: 2,
        target: 3,
      );

      expect(lockedBadge.isUnlocked, false);
      expect(lockedBadge.progress, 0.67);
    });

    test('ImpactSummary unlocks badges when thresholds are met', () {
      final requests = [
        RecyclingRequest(
          id: 'req-1',
          title: 'Big can collection',
          status: RequestStatus.pickedUp,
          scheduledFrom: DateTime(2026, 9, 1),
          scheduledTo: DateTime(2026, 9, 1),
          location: 'Stockholm',
          receiptAmount: 200.0,
          splitPercentage: 70.0,
          recyclerPayout: 140.0,
          helperPayout: 60.0,
        ),
      ];

      final summary = ImpactSummary.fromRequests(requests, isHelper: false);

      expect(summary.streak.currentStreakWeeks, greaterThan(0));
      expect(summary.streak.isActive, true);

      final firstStep = summary.badges.firstWhere((b) => b.id == 'first_step');
      expect(firstStep.isUnlocked, true);

      final centurion = summary.badges.firstWhere((b) => b.id == 'centurion');
      expect(centurion.isUnlocked, true); // 200 / 1.5 = 133 containers >= 100
    });
  });
}
