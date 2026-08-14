import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/application/device_location_service.dart';
import 'package:gps_pointer/application/device_orientation_service.dart';
import 'package:gps_pointer/application/pointing_controller.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  test('chooses the best GPS sample and locks it for later targets', () async {
    final locations = _FakeLocations(<DeviceLocationReading>[
      _reading(latitude: 43.00, accuracy: 20),
      _reading(latitude: 43.01, accuracy: 4),
      _reading(latitude: 43.02, accuracy: 9),
      _reading(latitude: 43.03, accuracy: 2),
      _reading(latitude: 43.04, accuracy: 5),
      _reading(latitude: 43.05, accuracy: 7),
    ]);
    final controller = PointingController(
      locationService: locations,
      elevationProvider: _FakeElevation(),
      orientationService: _FakeOrientation(),
    );

    await controller.prepare(beacon: _beacon, observerHeightMeters: 3);
    expect(controller.location!.latitude, 43.01);
    expect(controller.location!.horizontalAccuracyMeters, 4);
    expect(locations.calls, 3);
    expect(controller.positionSamplesUsed, 3);
    expect(controller.declinationDegrees, 3.2);

    await controller.prepare(beacon: _beacon, observerHeightMeters: 6);
    expect(locations.calls, 3);
    expect(controller.location!.latitude, 43.01);
    expect(controller.observerHeightMeters, 6);

    await controller.prepare(
      beacon: _beacon,
      observerHeightMeters: 6,
      refreshPosition: true,
    );
    expect(locations.calls, 6);
    expect(controller.location!.latitude, 43.03);
    expect(controller.location!.horizontalAccuracyMeters, 2);
  });
}

const _beacon = RadioBeacon(
  id: 'TEST',
  name: 'Test',
  position: GeoPoint(latitude: 43.1, longitude: 12.9),
  terrainElevationMeters: 800,
);

DeviceLocationReading _reading({
  required double latitude,
  required double accuracy,
}) => DeviceLocationReading(
  latitude: latitude,
  longitude: 12.8,
  altitudeMeters: 400,
  horizontalAccuracyMeters: accuracy,
  verticalAccuracyMeters: 5,
);

final class _FakeLocations implements DeviceLocationService {
  _FakeLocations(this.readings);

  final List<DeviceLocationReading> readings;
  int calls = 0;

  @override
  Future<DeviceLocationReading> readCurrentPosition() async =>
      readings[calls++];
}

final class _FakeElevation implements TerrainElevationProvider {
  @override
  Future<double> getTerrainElevationMeters(GeoPoint position) async => 400;
}

final class _FakeOrientation implements DeviceOrientationService {
  @override
  Future<DeviceOrientationInfo> readInfo(
    DeviceLocationReading location,
  ) async => const DeviceOrientationInfo(
    hasMagnetometer: true,
    declinationDegrees: 3.2,
  );
}
