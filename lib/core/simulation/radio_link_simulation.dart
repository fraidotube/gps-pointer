import '../domain/geo_point.dart';
import '../geo/radio_profile_engine.dart';

final class RadioLinkSimulation {
  const RadioLinkSimulation({
    required this.id,
    required this.name,
    required this.beaconId,
    required this.beaconName,
    required this.startPosition,
    required this.startGroundElevationMeters,
    required this.buildingHeightMeters,
    required this.targetPosition,
    required this.targetGroundElevationMeters,
    required this.targetPoleHeightMeters,
    required this.frequencyGhz,
    required this.azimuthDegrees,
    required this.profile,
    required this.createdAtUtc,
  });

  final String id;
  final String name;
  final String beaconId;
  final String beaconName;
  final GeoPoint startPosition;
  final double startGroundElevationMeters;
  final double buildingHeightMeters;
  final GeoPoint targetPosition;
  final double targetGroundElevationMeters;
  final double targetPoleHeightMeters;
  final double? frequencyGhz;
  final double azimuthDegrees;
  final RadioProfileResult profile;
  final DateTime createdAtUtc;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'beacon_id': beaconId,
    'beacon_name': beaconName,
    'start_latitude': startPosition.latitude,
    'start_longitude': startPosition.longitude,
    'start_ground_elevation_m': startGroundElevationMeters,
    'building_height_m': buildingHeightMeters,
    'target_latitude': targetPosition.latitude,
    'target_longitude': targetPosition.longitude,
    'target_ground_elevation_m': targetGroundElevationMeters,
    'target_pole_height_m': targetPoleHeightMeters,
    'frequency_ghz': frequencyGhz,
    'azimuth_degrees': azimuthDegrees,
    'profile': profile.toJson(),
    'created_at_utc': createdAtUtc.toUtc().toIso8601String(),
  };

  factory RadioLinkSimulation.fromJson(Map<String, dynamic> json) =>
      RadioLinkSimulation(
        id: json['id'] as String,
        name: json['name'] as String,
        beaconId: json['beacon_id'] as String,
        beaconName: json['beacon_name'] as String,
        startPosition: GeoPoint.validated(
          latitude: (json['start_latitude'] as num).toDouble(),
          longitude: (json['start_longitude'] as num).toDouble(),
        ),
        startGroundElevationMeters: (json['start_ground_elevation_m'] as num)
            .toDouble(),
        buildingHeightMeters: (json['building_height_m'] as num).toDouble(),
        targetPosition: GeoPoint.validated(
          latitude: (json['target_latitude'] as num).toDouble(),
          longitude: (json['target_longitude'] as num).toDouble(),
        ),
        targetGroundElevationMeters: (json['target_ground_elevation_m'] as num)
            .toDouble(),
        targetPoleHeightMeters: (json['target_pole_height_m'] as num)
            .toDouble(),
        frequencyGhz: (json['frequency_ghz'] as num?)?.toDouble(),
        azimuthDegrees: (json['azimuth_degrees'] as num).toDouble(),
        profile: RadioProfileResult.fromJson(
          Map<String, dynamic>.from(json['profile'] as Map),
        ),
        createdAtUtc: DateTime.parse(json['created_at_utc'] as String).toUtc(),
      );
}
