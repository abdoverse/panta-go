import 'package:flutter_test/flutter_test.dart';
import 'package:panta/models/request_model.dart';
import 'package:panta/providers/panta_provider.dart';

void main() {
  group('sortRequestsByDistance', () {
    test('sorts jobs by distance and moves unknown locations to the end', () {
      final requests = [
        RecyclingRequest(
          id: 'far',
          title: 'Far job',
          imageUrl: '',
          scheduledFrom: DateTime(2026, 1, 1, 12),
          scheduledTo: DateTime(2026, 1, 1, 13),
          location: 'Far',
          locationLatitude: 59.37,
          locationLongitude: 18.1,
        ),
        RecyclingRequest(
          id: 'unknown',
          title: 'Unknown job',
          imageUrl: '',
          scheduledFrom: DateTime(2026, 1, 1, 11),
          scheduledTo: DateTime(2026, 1, 1, 12),
          location: 'Unknown',
        ),
        RecyclingRequest(
          id: 'near',
          title: 'Near job',
          imageUrl: '',
          scheduledFrom: DateTime(2026, 1, 1, 14),
          scheduledTo: DateTime(2026, 1, 1, 15),
          location: 'Near',
          locationLatitude: 59.3326,
          locationLongitude: 18.0649,
        ),
      ];

      final sorted = sortRequestsByDistance(
        requests,
        helperLatitude: 59.3293,
        helperLongitude: 18.0686,
      );

      expect(sorted.map((request) => request.id), ['near', 'far', 'unknown']);
    });
  });
}
