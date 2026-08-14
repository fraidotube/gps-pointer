import 'dart:math' as math;

import '../domain/geo_point.dart';

final class GeoCalculation {
  const GeoCalculation({
    required this.distanceMeters,
    required this.initialBearingDegrees,
  });

  final double distanceMeters;
  final double initialBearingDegrees;
}

final class PointingCalculation {
  const PointingCalculation({
    required this.distanceMeters,
    required this.initialBearingDegrees,
    required this.elevationAngleDegrees,
    required this.heightDifferenceMeters,
  });

  final double distanceMeters;
  final double initialBearingDegrees;
  final double elevationAngleDegrees;
  final double heightDifferenceMeters;
}

/// Pure geographic calculations with no dependency on Android or Flutter UI.
abstract final class GeoCalculator {
  static const double earthMeanRadiusMeters = 6371008.8;

  static GeoCalculation between(GeoPoint origin, GeoPoint destination) {
    return GeoCalculation(
      distanceMeters: distanceMeters(origin, destination),
      initialBearingDegrees: initialBearingDegrees(origin, destination),
    );
  }

  static PointingCalculation pointing({
    required GeoPoint origin,
    required double originElevationMeters,
    required GeoPoint destination,
    required double destinationElevationMeters,
  }) {
    final horizontalDistance = distanceMeters(origin, destination);
    final heightDifference = destinationElevationMeters - originElevationMeters;
    final elevationAngle = horizontalDistance == 0
        ? (heightDifference == 0 ? 0.0 : (heightDifference > 0 ? 90.0 : -90.0))
        : _radiansToDegrees(math.atan2(heightDifference, horizontalDistance));
    return PointingCalculation(
      distanceMeters: horizontalDistance,
      initialBearingDegrees: initialBearingDegrees(origin, destination),
      elevationAngleDegrees: elevationAngle,
      heightDifferenceMeters: heightDifference,
    );
  }

  /// Great-circle distance calculated with the haversine formula.
  static double distanceMeters(GeoPoint origin, GeoPoint destination) {
    final latitude1 = _degreesToRadians(origin.latitude);
    final latitude2 = _degreesToRadians(destination.latitude);
    final deltaLatitude = latitude2 - latitude1;
    final deltaLongitude = _degreesToRadians(
      destination.longitude - origin.longitude,
    );

    final sinHalfLatitude = math.sin(deltaLatitude / 2);
    final sinHalfLongitude = math.sin(deltaLongitude / 2);
    final haversine =
        sinHalfLatitude * sinHalfLatitude +
        math.cos(latitude1) *
            math.cos(latitude2) *
            sinHalfLongitude *
            sinHalfLongitude;
    final boundedHaversine = haversine.clamp(0.0, 1.0);
    final angularDistance =
        2 *
        math.atan2(
          math.sqrt(boundedHaversine),
          math.sqrt(1 - boundedHaversine),
        );
    return earthMeanRadiusMeters * angularDistance;
  }

  /// Initial great-circle bearing relative to true north, normalized to
  /// [0, 360). Equal points return 0 by explicit convention.
  static double initialBearingDegrees(GeoPoint origin, GeoPoint destination) {
    if (origin == destination) {
      return 0;
    }

    final latitude1 = _degreesToRadians(origin.latitude);
    final latitude2 = _degreesToRadians(destination.latitude);
    final deltaLongitude = _degreesToRadians(
      destination.longitude - origin.longitude,
    );
    final y = math.sin(deltaLongitude) * math.cos(latitude2);
    final x =
        math.cos(latitude1) * math.sin(latitude2) -
        math.sin(latitude1) * math.cos(latitude2) * math.cos(deltaLongitude);
    return normalizeDegrees(_radiansToDegrees(math.atan2(y, x)));
  }

  static double normalizeDegrees(double degrees) {
    final normalized = degrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  static double _radiansToDegrees(double radians) => radians * 180 / math.pi;
}
