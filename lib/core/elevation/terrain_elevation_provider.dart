import '../domain/geo_point.dart';

/// Boundary for a future terrain elevation source.
///
/// The Google Elevation API adapter will be implemented only after credentials,
/// billing, policies, networking and secure key handling are approved.
abstract interface class TerrainElevationProvider {
  Future<double> getTerrainElevationMeters(GeoPoint position);
}
