import 'package:flutter_test/flutter_test.dart';
import 'package:panta/providers/panta_provider.dart';

void main() {
  group('calculateHelperReliabilityRating', () {
    test('returns null when helper has no history', () {
      expect(
        calculateHelperReliabilityRating(completedJobs: 0, canceledPickups: 0),
        isNull,
      );
    });

    test('returns 5 when helper has no cancellations', () {
      expect(
        calculateHelperReliabilityRating(completedJobs: 7, canceledPickups: 0),
        5,
      );
    });

    test('drops toward 1 as cancellations rise', () {
      expect(
        calculateHelperReliabilityRating(completedJobs: 3, canceledPickups: 3),
        3,
      );
      expect(
        calculateHelperReliabilityRating(completedJobs: 0, canceledPickups: 2),
        1,
      );
    });
  });
}
