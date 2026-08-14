import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

final class _FakeTerrainElevationProvider implements TerrainElevationProvider {
  const _FakeTerrainElevationProvider(this.elevation);

  final double elevation;

  @override
  Future<double> getTerrainElevationMeters(GeoPoint position) async =>
      elevation;
}

void main() {
  test('keeps terrain, pole and antenna elevations separate', () async {
    const beacon = RadioBeacon(
      id: 'TEST-001',
      name: 'CasaPacico',
      position: GeoPoint(latitude: 42.982646, longitude: 12.775651),
      poleHeightMeters: 12.5,
    );
    const service = RadioBeaconElevationService(
      _FakeTerrainElevationProvider(500),
    );

    final enriched = await service.loadTerrainElevation(beacon);

    expect(beacon.terrainElevationMeters, isNull);
    expect(enriched.terrainElevationMeters, 500);
    expect(enriched.poleHeightMeters, 12.5);
    expect(enriched.antennaElevationMeters, 512.5);
  });
}
