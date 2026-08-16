import 'dart:math' as math;

import '../domain/geo_point.dart';

const double radioProfileEarthRadiusMeters = 6371000.0;
const double radioProfileSpeedOfLightMetersPerSecond = 299792458.0;
const double radioProfileDefaultKFactor = 4.0 / 3.0;

final class RadioProfilePoint {
  const RadioProfilePoint({
    required this.distanceKm,
    required this.terrainMeters,
    required this.earthBulgeMeters,
    required this.adjustedTerrainMeters,
    required this.lineOfSightMeters,
    required this.fresnelRadiusMeters,
    required this.fresnelUpperMeters,
    required this.fresnelLowerMeters,
  });

  final double distanceKm;
  final double terrainMeters;
  final double earthBulgeMeters;
  final double adjustedTerrainMeters;
  final double lineOfSightMeters;
  final double? fresnelRadiusMeters;
  final double? fresnelUpperMeters;
  final double? fresnelLowerMeters;

  Map<String, Object?> toJson() => {
    'distance_km': distanceKm,
    'terrain_m': terrainMeters,
    'earth_bulge_m': earthBulgeMeters,
    'adjusted_terrain_m': adjustedTerrainMeters,
    'line_of_sight_m': lineOfSightMeters,
    'fresnel_radius_m': fresnelRadiusMeters,
    'fresnel_upper_m': fresnelUpperMeters,
    'fresnel_lower_m': fresnelLowerMeters,
  };

  factory RadioProfilePoint.fromJson(Map<String, dynamic> json) =>
      RadioProfilePoint(
        distanceKm: (json['distance_km'] as num).toDouble(),
        terrainMeters: (json['terrain_m'] as num).toDouble(),
        earthBulgeMeters: (json['earth_bulge_m'] as num).toDouble(),
        adjustedTerrainMeters: (json['adjusted_terrain_m'] as num).toDouble(),
        lineOfSightMeters: (json['line_of_sight_m'] as num).toDouble(),
        fresnelRadiusMeters: (json['fresnel_radius_m'] as num?)?.toDouble(),
        fresnelUpperMeters: (json['fresnel_upper_m'] as num?)?.toDouble(),
        fresnelLowerMeters: (json['fresnel_lower_m'] as num?)?.toDouble(),
      );
}

final class RadioProfileResult {
  const RadioProfileResult({
    required this.distanceKm,
    required this.sampleCount,
    required this.installerGroundElevationMeters,
    required this.targetGroundElevationMeters,
    required this.installerAntennaElevationMeters,
    required this.targetAntennaElevationMeters,
    required this.installerAntennaHeightMeters,
    required this.targetAntennaHeightMeters,
    required this.frequencyGhz,
    required this.kFactor,
    required this.tiltDegrees,
    required this.minimumLosClearanceMeters,
    required this.minimumLosClearanceDistanceKm,
    required this.minimumFresnelClearanceMeters,
    required this.minimumFresnelClearanceDistanceKm,
    required this.lineOfSightClear,
    required this.firstFresnelClear,
    required this.points,
  });

  final double distanceKm;
  final int sampleCount;
  final double installerGroundElevationMeters;
  final double targetGroundElevationMeters;
  final double installerAntennaElevationMeters;
  final double targetAntennaElevationMeters;
  final double installerAntennaHeightMeters;
  final double targetAntennaHeightMeters;
  final double? frequencyGhz;
  final double kFactor;
  final double tiltDegrees;
  final double minimumLosClearanceMeters;
  final double minimumLosClearanceDistanceKm;
  final double? minimumFresnelClearanceMeters;
  final double? minimumFresnelClearanceDistanceKm;
  final bool lineOfSightClear;
  final bool? firstFresnelClear;
  final List<RadioProfilePoint> points;

  Map<String, Object?> toJson() => {
    'distance_km': distanceKm,
    'sample_count': sampleCount,
    'installer_ground_elevation_m': installerGroundElevationMeters,
    'target_ground_elevation_m': targetGroundElevationMeters,
    'installer_antenna_elevation_m': installerAntennaElevationMeters,
    'target_antenna_elevation_m': targetAntennaElevationMeters,
    'installer_antenna_height_m': installerAntennaHeightMeters,
    'target_antenna_height_m': targetAntennaHeightMeters,
    'frequency_ghz': frequencyGhz,
    'k_factor': kFactor,
    'tilt_degrees': tiltDegrees,
    'minimum_los_clearance_m': minimumLosClearanceMeters,
    'minimum_los_clearance_distance_km': minimumLosClearanceDistanceKm,
    'minimum_fresnel_clearance_m': minimumFresnelClearanceMeters,
    'minimum_fresnel_clearance_distance_km': minimumFresnelClearanceDistanceKm,
    'line_of_sight_clear': lineOfSightClear,
    'first_fresnel_clear': firstFresnelClear,
    'points': points.map((point) => point.toJson()).toList(growable: false),
  };

  factory RadioProfileResult.fromJson(Map<String, dynamic> json) =>
      RadioProfileResult(
        distanceKm: (json['distance_km'] as num).toDouble(),
        sampleCount: json['sample_count'] as int,
        installerGroundElevationMeters:
            (json['installer_ground_elevation_m'] as num).toDouble(),
        targetGroundElevationMeters: (json['target_ground_elevation_m'] as num)
            .toDouble(),
        installerAntennaElevationMeters:
            (json['installer_antenna_elevation_m'] as num).toDouble(),
        targetAntennaElevationMeters:
            (json['target_antenna_elevation_m'] as num).toDouble(),
        installerAntennaHeightMeters:
            (json['installer_antenna_height_m'] as num).toDouble(),
        targetAntennaHeightMeters: (json['target_antenna_height_m'] as num)
            .toDouble(),
        frequencyGhz: (json['frequency_ghz'] as num?)?.toDouble(),
        kFactor: (json['k_factor'] as num).toDouble(),
        tiltDegrees: (json['tilt_degrees'] as num).toDouble(),
        minimumLosClearanceMeters: (json['minimum_los_clearance_m'] as num)
            .toDouble(),
        minimumLosClearanceDistanceKm:
            (json['minimum_los_clearance_distance_km'] as num).toDouble(),
        minimumFresnelClearanceMeters:
            (json['minimum_fresnel_clearance_m'] as num?)?.toDouble(),
        minimumFresnelClearanceDistanceKm:
            (json['minimum_fresnel_clearance_distance_km'] as num?)?.toDouble(),
        lineOfSightClear: json['line_of_sight_clear'] as bool,
        firstFresnelClear: json['first_fresnel_clear'] as bool?,
        points: (json['points'] as List<dynamic>)
            .map(
              (item) => RadioProfilePoint.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
}

abstract final class RadioProfileEngine {
  static double haversineDistanceMeters(GeoPoint start, GeoPoint end) {
    final lat1 = _radians(start.latitude);
    final lat2 = _radians(end.latitude);
    final deltaLat = lat2 - lat1;
    final deltaLon = _radians(end.longitude - start.longitude);
    final value =
        math.pow(math.sin(deltaLat / 2), 2).toDouble() +
        math.cos(lat1) *
            math.cos(lat2) *
            math.pow(math.sin(deltaLon / 2), 2).toDouble();
    final bounded = value.clamp(0.0, 1.0);
    return radioProfileEarthRadiusMeters *
        2.0 *
        math.atan2(math.sqrt(bounded), math.sqrt(1.0 - bounded));
  }

  static int sampleCountForDistance(double distanceMeters) {
    if (!distanceMeters.isFinite || distanceMeters <= 1.0) {
      throw const FormatException(
        'I due punti devono essere distanti più di un metro.',
      );
    }
    return math.min(500, math.max(2, (distanceMeters / 90.0).ceil() + 1));
  }

  static List<GeoPoint> geodesicCoordinates(
    GeoPoint start,
    GeoPoint end,
    int sampleCount,
  ) {
    if (sampleCount < 2) {
      throw const FormatException('Servono almeno due campioni.');
    }
    final lat1 = _radians(start.latitude);
    final lon1 = _radians(start.longitude);
    final lat2 = _radians(end.latitude);
    final lon2 = _radians(end.longitude);
    final angularDistance =
        haversineDistanceMeters(start, end) / radioProfileEarthRadiusMeters;
    if (angularDistance <= 1.0 / radioProfileEarthRadiusMeters) {
      throw const FormatException(
        'I due punti devono essere distanti più di un metro.',
      );
    }
    final sinDistance = math.sin(angularDistance);
    final coordinates = <GeoPoint>[];
    for (var index = 0; index < sampleCount; index++) {
      final fraction = index / (sampleCount - 1);
      final a = math.sin((1.0 - fraction) * angularDistance) / sinDistance;
      final b = math.sin(fraction * angularDistance) / sinDistance;
      final x =
          a * math.cos(lat1) * math.cos(lon1) +
          b * math.cos(lat2) * math.cos(lon2);
      final y =
          a * math.cos(lat1) * math.sin(lon1) +
          b * math.cos(lat2) * math.sin(lon2);
      final z = a * math.sin(lat1) + b * math.sin(lat2);
      coordinates.add(
        GeoPoint.validated(
          latitude: _degrees(math.atan2(z, math.sqrt(x * x + y * y))),
          longitude: _degrees(math.atan2(y, x)),
        ),
      );
    }
    return coordinates;
  }

  static RadioProfileResult build({
    required double distanceMeters,
    required List<double> elevationsMeters,
    required double installerAntennaHeightMeters,
    required double targetAntennaHeightMeters,
    required double? frequencyGhz,
    double kFactor = radioProfileDefaultKFactor,
  }) {
    if (!distanceMeters.isFinite || distanceMeters <= 1.0) {
      throw const FormatException(
        'I due punti devono essere distanti più di un metro.',
      );
    }
    if (elevationsMeters.length < 2) {
      throw const FormatException(
        'Il profilo richiede almeno due quote terreno.',
      );
    }
    if (installerAntennaHeightMeters < 0 || targetAntennaHeightMeters < 0) {
      throw const FormatException(
        'Le altezze delle antenne non possono essere negative.',
      );
    }
    if (frequencyGhz != null &&
        (!frequencyGhz.isFinite ||
            frequencyGhz < 0.001 ||
            frequencyGhz > 300)) {
      throw const FormatException(
        'La frequenza deve essere compresa tra 0.001 e 300 GHz.',
      );
    }
    if (!kFactor.isFinite || kFactor < 0.5 || kFactor > 10.0) {
      throw const FormatException('Il fattore K non è valido.');
    }
    if (elevationsMeters.any((value) => !value.isFinite)) {
      throw const FormatException('Le quote terreno devono essere finite.');
    }

    final startAntenna = elevationsMeters.first + installerAntennaHeightMeters;
    final targetAntenna = elevationsMeters.last + targetAntennaHeightMeters;
    final wavelength = frequencyGhz == null
        ? null
        : radioProfileSpeedOfLightMetersPerSecond / (frequencyGhz * 1e9);
    final effectiveRadius = radioProfileEarthRadiusMeters * kFactor;
    final points = <RadioProfilePoint>[];
    for (var index = 0; index < elevationsMeters.length; index++) {
      final terrain = elevationsMeters[index];
      final fraction = index / (elevationsMeters.length - 1);
      final distance = distanceMeters * fraction;
      final remaining = distanceMeters - distance;
      final bulge = distance * remaining / (2.0 * effectiveRadius);
      final adjustedTerrain = terrain + bulge;
      final line = startAntenna + (targetAntenna - startAntenna) * fraction;
      final radius = wavelength == null
          ? null
          : math.sqrt(wavelength * distance * remaining / distanceMeters);
      points.add(
        RadioProfilePoint(
          distanceKm: distance / 1000.0,
          terrainMeters: terrain,
          earthBulgeMeters: bulge,
          adjustedTerrainMeters: adjustedTerrain,
          lineOfSightMeters: line,
          fresnelRadiusMeters: radius,
          fresnelUpperMeters: radius == null ? null : line + radius,
          fresnelLowerMeters: radius == null ? null : line - radius,
        ),
      );
    }

    final measured = points.length > 2
        ? points.sublist(1, points.length - 1)
        : points;
    var losIndex = 0;
    var minimumLos = double.infinity;
    for (var index = 0; index < measured.length; index++) {
      final clearance =
          measured[index].lineOfSightMeters -
          measured[index].adjustedTerrainMeters;
      if (clearance < minimumLos) {
        minimumLos = clearance;
        losIndex = index;
      }
    }

    double? minimumFresnel;
    double? minimumFresnelDistance;
    if (frequencyGhz != null) {
      var fresnelIndex = 0;
      var minimumFresnelValue = double.infinity;
      for (var index = 0; index < measured.length; index++) {
        final item = measured[index];
        final clearance =
            item.lineOfSightMeters -
            (item.fresnelRadiusMeters ?? 0.0) -
            item.adjustedTerrainMeters;
        if (clearance < minimumFresnelValue) {
          minimumFresnelValue = clearance;
          fresnelIndex = index;
        }
      }
      minimumFresnel = minimumFresnelValue;
      minimumFresnelDistance = measured[fresnelIndex].distanceKm;
    }

    return RadioProfileResult(
      distanceKm: distanceMeters / 1000.0,
      sampleCount: points.length,
      installerGroundElevationMeters: elevationsMeters.first,
      targetGroundElevationMeters: elevationsMeters.last,
      installerAntennaElevationMeters: startAntenna,
      targetAntennaElevationMeters: targetAntenna,
      installerAntennaHeightMeters: installerAntennaHeightMeters,
      targetAntennaHeightMeters: targetAntennaHeightMeters,
      frequencyGhz: frequencyGhz,
      kFactor: kFactor,
      tiltDegrees: _degrees(
        math.atan2(targetAntenna - startAntenna, distanceMeters),
      ),
      minimumLosClearanceMeters: minimumLos,
      minimumLosClearanceDistanceKm: measured[losIndex].distanceKm,
      minimumFresnelClearanceMeters: minimumFresnel,
      minimumFresnelClearanceDistanceKm: minimumFresnelDistance,
      lineOfSightClear: minimumLos >= 0.0,
      firstFresnelClear: minimumFresnel == null ? null : minimumFresnel >= 0.0,
      points: List.unmodifiable(points),
    );
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;
  static double _degrees(double radians) => radians * 180.0 / math.pi;
}
