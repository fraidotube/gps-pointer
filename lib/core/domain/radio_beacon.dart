import 'geo_point.dart';

/// Radio beacon stored in the local operational catalogue.
///
/// Version 1 deliberately has no active/inactive flag: a beacon exists when it
/// is present in the imported file and does not exist when it is absent.
final class RadioBeacon {
  const RadioBeacon({
    required this.id,
    required this.name,
    required this.position,
    this.terrainElevationMeters,
    this.poleHeightMeters = 0,
    this.elevationSource,
    this.horizontalAccuracyMeters,
    this.verticalAccuracyMeters,
  });

  final String id;
  final String name;
  final GeoPoint position;

  /// Terrain elevation. Null until obtained from a verified elevation source.
  final double? terrainElevationMeters;

  /// Optional pole height above terrain. An empty v1 import field means zero.
  final double poleHeightMeters;
  final String? elevationSource;
  final double? horizontalAccuracyMeters;
  final double? verticalAccuracyMeters;

  /// Absolute antenna elevation when terrain elevation is known.
  double? get antennaElevationMeters => terrainElevationMeters == null
      ? null
      : terrainElevationMeters! + poleHeightMeters;

  RadioBeacon withTerrainElevation(double elevationMeters) {
    if (!elevationMeters.isFinite) {
      throw ArgumentError.value(
        elevationMeters,
        'elevationMeters',
        'Must be finite.',
      );
    }
    return RadioBeacon(
      id: id,
      name: name,
      position: position,
      terrainElevationMeters: elevationMeters,
      poleHeightMeters: poleHeightMeters,
      elevationSource: elevationSource,
      horizontalAccuracyMeters: horizontalAccuracyMeters,
      verticalAccuracyMeters: verticalAccuracyMeters,
    );
  }

  RadioBeacon copyWith({
    GeoPoint? position,
    double? terrainElevationMeters,
    double? poleHeightMeters,
    String? elevationSource,
    double? horizontalAccuracyMeters,
    double? verticalAccuracyMeters,
  }) => RadioBeacon(
    id: id,
    name: name,
    position: position ?? this.position,
    terrainElevationMeters:
        terrainElevationMeters ?? this.terrainElevationMeters,
    poleHeightMeters: poleHeightMeters ?? this.poleHeightMeters,
    elevationSource: elevationSource ?? this.elevationSource,
    horizontalAccuracyMeters:
        horizontalAccuracyMeters ?? this.horizontalAccuracyMeters,
    verticalAccuracyMeters:
        verticalAccuracyMeters ?? this.verticalAccuracyMeters,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioBeacon &&
          id == other.id &&
          name == other.name &&
          position == other.position &&
          terrainElevationMeters == other.terrainElevationMeters &&
          poleHeightMeters == other.poleHeightMeters &&
          elevationSource == other.elevationSource &&
          horizontalAccuracyMeters == other.horizontalAccuracyMeters &&
          verticalAccuracyMeters == other.verticalAccuracyMeters;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    position,
    terrainElevationMeters,
    poleHeightMeters,
    elevationSource,
    horizontalAccuracyMeters,
    verticalAccuracyMeters,
  );

  @override
  String toString() =>
      'RadioBeacon(id: $id, name: $name, position: $position, '
      'terrainElevationMeters: $terrainElevationMeters, '
      'poleHeightMeters: $poleHeightMeters)';
}
