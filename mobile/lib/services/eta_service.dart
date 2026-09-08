import 'dart:math';
import 'package:geolocator/geolocator.dart';

enum DeliveryMilestone {
  assigned,
  onTheWay,
  arrivingSoon,
  arrived,
  completed,
}

class EtaInfo {
  final int etaMinutes;
  final double distanceKm;
  final DeliveryMilestone milestone;
  final String statusText;

  const EtaInfo({
    required this.etaMinutes,
    required this.distanceKm,
    required this.milestone,
    required this.statusText,
  });

  bool get isArrivingSoon => milestone == DeliveryMilestone.arrivingSoon;
  bool get hasArrived => milestone == DeliveryMilestone.arrived;
}

class EtaService {
  /// Calculates distance in km between two GPS coordinates
  static double calculateDistanceKm({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    final meters = Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);
    return double.parse((meters / 1000).toStringAsFixed(2));
  }

  /// Calculates estimated travel time in minutes based on distance and average speed (km/h)
  static int estimateEtaMinutes(double distanceKm, {double averageSpeedKmh = 25.0}) {
    if (distanceKm <= 0.05) return 0;
    final hours = distanceKm / max(5.0, averageSpeedKmh);
    final minutes = (hours * 60).ceil();
    return max(1, minutes);
  }

  /// Determines the current delivery progress milestone based on proximity
  static DeliveryMilestone determineMilestone({
    required double distanceKm,
    required int etaMinutes,
  }) {
    if (distanceKm <= 0.08) {
      // Within 80 meters
      return DeliveryMilestone.arrived;
    } else if (etaMinutes <= 5 || distanceKm <= 1.0) {
      // Within 5 minutes or 1 km
      return DeliveryMilestone.arrivingSoon;
    } else {
      return DeliveryMilestone.onTheWay;
    }
  }

  /// Computes comprehensive ETA info
  static EtaInfo computeEta({
    required double helperLat,
    required double helperLng,
    required double pickupLat,
    required double pickupLng,
    double averageSpeedKmh = 25.0,
  }) {
    final dist = calculateDistanceKm(
      fromLat: helperLat,
      fromLng: helperLng,
      toLat: pickupLat,
      toLng: pickupLng,
    );
    final minutes = estimateEtaMinutes(dist, averageSpeedKmh: averageSpeedKmh);
    final milestone = determineMilestone(distanceKm: dist, etaMinutes: minutes);

    String statusText;
    switch (milestone) {
      case DeliveryMilestone.arrived:
        statusText = 'Helper has arrived!';
        break;
      case DeliveryMilestone.arrivingSoon:
        statusText = 'Arriving soon (~$minutes min)';
        break;
      case DeliveryMilestone.onTheWay:
        statusText = 'On the way (~$minutes min, $dist km)';
        break;
      default:
        statusText = 'Pickup in progress';
    }

    return EtaInfo(
      etaMinutes: minutes,
      distanceKm: dist,
      milestone: milestone,
      statusText: statusText,
    );
  }

  static String milestoneToString(DeliveryMilestone m) {
    switch (m) {
      case DeliveryMilestone.assigned:
        return 'assigned';
      case DeliveryMilestone.onTheWay:
        return 'on_the_way';
      case DeliveryMilestone.arrivingSoon:
        return 'arriving_soon';
      case DeliveryMilestone.arrived:
        return 'arrived';
      case DeliveryMilestone.completed:
        return 'completed';
    }
  }

  static DeliveryMilestone parseMilestone(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'on_the_way':
      case 'ontheway':
        return DeliveryMilestone.onTheWay;
      case 'arriving_soon':
      case 'arrivingsoon':
        return DeliveryMilestone.arrivingSoon;
      case 'arrived':
        return DeliveryMilestone.arrived;
      case 'completed':
        return DeliveryMilestone.completed;
      default:
        return DeliveryMilestone.assigned;
    }
  }
}
