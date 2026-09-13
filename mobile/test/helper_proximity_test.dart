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

    test('newly added request in Gothenburg appears first for Helper at Gothenburg physical address', () {
      // Helper physical address in Gothenburg: 57.7089, 11.9746
      const helperLat = 57.7089;
      const helperLon = 11.9746;

      final stockholm1 = RecyclingRequest(
        id: 'stockholm-1',
        title: 'Bottles & Cans Pickup',
        imageUrl: '',
        scheduledFrom: DateTime(2026, 9, 13, 10),
        scheduledTo: DateTime(2026, 9, 13, 12),
        location: 'Sveavägen 44, Stockholm',
        locationLatitude: 59.3365,
        locationLongitude: 18.0610,
      );

      final stockholm2 = RecyclingRequest(
        id: 'stockholm-2',
        title: 'Kungsgatan Pickup',
        imageUrl: '',
        scheduledFrom: DateTime(2026, 9, 13, 11),
        scheduledTo: DateTime(2026, 9, 13, 13),
        location: 'Kungsgatan 14, Stockholm',
        locationLatitude: 59.3365,
        locationLongitude: 18.0610,
      );

      final stockholm3 = RecyclingRequest(
        id: 'stockholm-3',
        title: 'Drottningholmsvägen Pickup',
        imageUrl: '',
        scheduledFrom: DateTime(2026, 9, 13, 12),
        scheduledTo: DateTime(2026, 9, 13, 14),
        location: 'Drottningholmsvägen 12, Stockholm',
        locationLatitude: 59.3320,
        locationLongitude: 18.0310,
      );

      // Recently added request at 1, Gyllenstensgatan, Gothenburg (~3.5 km away)
      final gothenburgRecentlyAdded = RecyclingRequest(
        id: 'gothenburg-recent',
        title: 'Gyllenstensgatan Pickup',
        imageUrl: '',
        scheduledFrom: DateTime(2026, 9, 13, 21),
        scheduledTo: DateTime(2026, 9, 13, 23),
        location: '1, Gyllenstensgatan, Kålltorp, Centrum, Gothenburg',
        locationLatitude: 57.7182171,
        locationLongitude: 12.0279283,
      );

      final requests = [stockholm1, stockholm2, stockholm3, gothenburgRecentlyAdded];

      final sorted = sortRequestsByDistance(
        requests,
        helperLatitude: helperLat,
        helperLongitude: helperLon,
      );

      // The Gothenburg job MUST appear first (index 0, closest to helper physical address)
      expect(sorted.first.id, 'gothenburg-recent');
      expect(sorted.map((r) => r.id).toList(), [
        'gothenburg-recent',
        'stockholm-3',
        'stockholm-1',
        'stockholm-2',
      ]);
    });
  });
}
