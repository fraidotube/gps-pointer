import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/application/catalogue_controller.dart';
import 'package:gps_pointer/application/catalogue_export_service.dart';
import 'package:gps_pointer/application/device_installation_id_service.dart';
import 'package:gps_pointer/application/device_location_service.dart';
import 'package:gps_pointer/application/device_orientation_service.dart';
import 'package:gps_pointer/application/pointing_controller.dart';
import 'package:gps_pointer/application/radio_beacon_file_picker.dart';
import 'package:gps_pointer/core/core.dart';
import 'package:gps_pointer/presentation/gps_pointer_app.dart';

void main() {
  testWidgets('first launch requires a device name before the catalogue', (
    tester,
  ) async {
    final controller = CatalogueController(
      importService: RadioBeaconImportService(
        parser: RadioBeaconFileParser(),
        repository: InMemoryRadioBeaconRepository(),
      ),
      filePicker: const _CancelledPicker(),
      elevationService: RadioBeaconElevationService(_UnusedElevation()),
      locationService: _UnusedLocation(),
      exportService: _UnusedExport(),
      identityService: _FakeIdentity(),
    );
    await controller.initialize();
    await tester.pumpWidget(
      GpsPointerApp(
        controller: controller,
        pointingController: PointingController(
          locationService: _UnusedLocation(),
          elevationProvider: _UnusedElevation(),
          orientationService: _UnusedOrientation(),
        ),
      ),
    );

    expect(find.text('Configura questo dispositivo'), findsOneWidget);
    expect(find.text('Imposta nome dispositivo'), findsOneWidget);
  });

  testWidgets('an existing catalogue acquires GPS automatically', (
    tester,
  ) async {
    final repository = InMemoryRadioBeaconRepository();
    await repository.replace(
      RadioBeaconCatalogue(
        beacons: const [
          RadioBeacon(
            id: 'TEST-001',
            name: 'CasaPacico',
            position: GeoPoint(latitude: 42.982646, longitude: 12.775651),
          ),
        ],
        sourceFileName: 'radiofari_gps_pointer.txt',
        importedAt: DateTime.utc(2026, 8, 14),
      ),
    );
    final location = _FixedLocation();
    final controller = CatalogueController(
      importService: RadioBeaconImportService(
        parser: RadioBeaconFileParser(),
        repository: repository,
      ),
      filePicker: const _CancelledPicker(),
      elevationService: RadioBeaconElevationService(_UnusedElevation()),
      locationService: location,
      exportService: _UnusedExport(),
      identityService: _FakeIdentity(displayName: 'Samsung Test'),
    );
    await controller.initialize();

    await tester.pumpWidget(
      GpsPointerApp(
        controller: controller,
        pointingController: PointingController(
          locationService: location,
          elevationProvider: _UnusedElevation(),
          orientationService: _UnusedOrientation(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(location.calls, 1);
    expect(controller.catalogueFilterPosition, isNotNull);
    expect(find.textContaining('Distanza dalla posizione:'), findsOneWidget);
  });
}

final class _FakeIdentity implements DeviceInstallationIdService {
  _FakeIdentity({String? displayName})
    : identity = DeviceIdentity(
        installationId: 'GPSP-11111111-1111-1111-1111-111111111111',
        displayName: displayName,
      );

  DeviceIdentity identity;

  @override
  Future<DeviceIdentity> loadOrCreate() async => identity;

  @override
  Future<DeviceIdentity> updateDisplayName(String displayName) async =>
      identity = DeviceIdentity(
        installationId: identity.installationId,
        displayName: displayName,
      );
}

final class _CancelledPicker implements RadioBeaconFilePicker {
  const _CancelledPicker();
  @override
  Future<SelectedRadioBeaconFile?> selectFile() async => null;
}

final class _UnusedElevation implements TerrainElevationProvider {
  @override
  Future<double> getTerrainElevationMeters(GeoPoint position) async => 0;
}

final class _UnusedLocation implements DeviceLocationService {
  @override
  Future<DeviceLocationReading> readCurrentPosition() =>
      throw UnimplementedError();
}

final class _FixedLocation implements DeviceLocationService {
  int calls = 0;

  @override
  Future<DeviceLocationReading> readCurrentPosition() async {
    calls++;
    return const DeviceLocationReading(
      latitude: 43,
      longitude: 13,
      altitudeMeters: 400,
      horizontalAccuracyMeters: 3,
      verticalAccuracyMeters: 5,
    );
  }
}

final class _UnusedOrientation implements DeviceOrientationService {
  @override
  Future<DeviceOrientationInfo> readInfo(DeviceLocationReading location) =>
      throw UnimplementedError();
}

final class _UnusedExport implements CatalogueExportService {
  @override
  Future<void> export(String content) async {}
}
