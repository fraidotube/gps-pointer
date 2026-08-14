import '../domain/radio_beacon.dart';
import '../elevation/terrain_elevation_provider.dart';

/// Enriches a beacon without coupling the domain model to Google or HTTP.
final class RadioBeaconElevationService {
  const RadioBeaconElevationService(this._provider);

  final TerrainElevationProvider _provider;

  Future<RadioBeacon> loadTerrainElevation(RadioBeacon beacon) async {
    final elevation = await _provider.getTerrainElevationMeters(
      beacon.position,
    );
    return beacon.withTerrainElevation(elevation);
  }
}
