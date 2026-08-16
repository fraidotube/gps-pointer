import '../domain/geo_point.dart';

abstract interface class TerrainProfileElevationProvider {
  Future<List<double>> getElevations(List<GeoPoint> coordinates);
}
