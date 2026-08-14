import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/application/catalogue_controller.dart';
import 'package:gps_pointer/application/catalogue_export_service.dart';
import 'package:gps_pointer/application/device_installation_id_service.dart';
import 'package:gps_pointer/application/device_location_service.dart';
import 'package:gps_pointer/application/radio_beacon_file_picker.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  test('import fills a missing elevation and preserves pole height', () async {
    final controller = _controller(file: _validFile);
    await controller.initialize();

    expect(await controller.importCatalogue(), isTrue);
    final beacon = controller.catalogue!.beacons.single;
    expect(beacon.terrainElevationMeters, 321);
    expect(beacon.poleHeightMeters, 10);
    expect(beacon.antennaElevationMeters, 331);
    expect(beacon.elevationSource, 'open_meteo_copernicus_glo90');
  });

  test(
    'on-site measurement replaces coordinates and stores accuracies',
    () async {
      final controller = _controller(file: _validFile);
      await controller.initialize();
      await controller.importCatalogue();

      await controller.measureOnSite('TEST-001');
      final beacon = controller.catalogue!.beacons.single;
      expect(beacon.position.latitude, 43);
      expect(beacon.position.longitude, 13);
      expect(beacon.terrainElevationMeters, 400);
      expect(beacon.elevationSource, 'gps_msl_rilevato_sul_posto');
      expect(beacon.horizontalAccuracyMeters, 3);
      expect(beacon.verticalAccuracyMeters, 5);
    },
  );

  test('manual update stores terrain and pole values', () async {
    final controller = _controller(file: _validFile);
    await controller.initialize();
    await controller.importCatalogue();

    await controller.updateManual(
      beaconId: 'TEST-001',
      terrainElevationMeters: 350,
      poleHeightMeters: 12,
    );
    final beacon = controller.catalogue!.beacons.single;
    expect(beacon.terrainElevationMeters, 350);
    expect(beacon.poleHeightMeters, 12);
    expect(beacon.elevationSource, 'manuale');
  });

  test('filter position is acquired without modifying the catalogue', () async {
    final controller = _controller(file: _validFile);
    await controller.initialize();
    await controller.importCatalogue();
    final original = controller.catalogue!.beacons.single;

    expect(await controller.refreshCatalogueFilterPosition(), isTrue);

    expect(controller.catalogueFilterPosition!.latitude, 43);
    expect(controller.catalogueFilterPosition!.longitude, 13);
    expect(controller.catalogueFilterLocation!.horizontalAccuracyMeters, 3);
    expect(controller.catalogue!.beacons.single, original);
  });

  test('export produces version 3 metadata from the current device', () async {
    final export = _FakeExport();
    final controller = _controller(file: _validFile, export: export);
    await controller.initialize();
    await controller.importCatalogue();

    await controller.exportCatalogue();
    expect(export.content, contains('GPS_POINTER_RADIOFARI;3'));
    expect(
      export.content,
      contains('2026-08-14T00:00:00.000Z;$_deviceId;Telefono Test'),
    );
    expect(export.content, contains('CasaPacico'));
    expect(export.content, contains(';321.0;10.0;'));
  });

  test('manual insertion validates and appends a radio beacon', () async {
    final controller = _controller(file: _validFile);
    await controller.initialize();
    await controller.importCatalogue();

    final success = await controller.addManualBeacon(
      name: 'Nuovo Radiofaro',
      latitude: 43.1,
      longitude: 12.8,
      terrainElevationMeters: 500,
      poleHeightMeters: 8,
    );

    expect(success, isTrue);
    expect(controller.catalogue!.beacons, hasLength(2));
    final added = controller.catalogue!.beacons.last;
    expect(added.id, 'NUOVO-RADIOFARO');
    expect(added.terrainElevationMeters, 500);
    expect(added.poleHeightMeters, 8);
    expect(added.elevationSource, 'manuale');
  });

  test('duplicate generated identifier receives a stable suffix', () async {
    final controller = _controller(file: _validFile);
    await controller.initialize();
    await controller.importCatalogue();

    final first = await controller.addManualBeacon(
      name: 'CasaPacico',
      latitude: 43.1,
      longitude: 12.8,
      terrainElevationMeters: null,
      poleHeightMeters: 0,
    );
    final second = await controller.addManualBeacon(
      name: 'CasaPacico',
      latitude: 43.2,
      longitude: 12.9,
      terrainElevationMeters: null,
      poleHeightMeters: 0,
    );

    expect(first, isTrue);
    expect(second, isTrue);
    expect(controller.catalogue!.beacons, hasLength(3));
    expect(controller.catalogue!.beacons[1].id, 'CASAPACICO');
    expect(controller.catalogue!.beacons[2].id, 'CASAPACICO-2');
  });

  test('foreign device import requires explicit approval', () async {
    const foreign = SelectedRadioBeaconFile(
      name: 'radiofari_gps_pointer.txt',
      content: '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
2026-08-14T10:00:00.000Z;GPSP-22222222-2222-2222-2222-222222222222;Telefono Collega
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
RF-1;Altro;43.0;12.0;;;;;
''',
    );
    final controller = _controller(file: foreign);
    await controller.initialize();
    CatalogueImportPreview? preview;

    final success = await controller.importCatalogue(
      approve: (value) async {
        preview = value;
        return false;
      },
    );

    expect(success, isFalse);
    expect(preview!.deviceDiffers, isTrue);
    expect(preview!.sourceDeviceName, 'Telefono Collega');
    expect(controller.catalogue, isNull);
  });

  test('approved foreign import exports with the local identity', () async {
    const foreign = SelectedRadioBeaconFile(
      name: 'radiofari_gps_pointer.txt',
      content: '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
2026-08-13T08:30:00.000Z;GPSP-22222222-2222-2222-2222-222222222222;Telefono Collega
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
RF-1;Altro;43.0;12.0;321;4;manuale;;
''',
    );
    final export = _FakeExport();
    final controller = _controller(file: foreign, export: export);
    await controller.initialize();

    final success = await controller.importCatalogue(
      approve: (_) async => true,
    );
    await controller.exportCatalogue();

    expect(success, isTrue);
    expect(export.content, contains('$_deviceId;Telefono Test'));
    expect(export.content, isNot(contains('Telefono Collega')));
    expect(
      export.content,
      isNot(contains('GPSP-22222222-2222-2222-2222-222222222222')),
    );
  });

  test('a non-standard filename requires approval', () async {
    final controller = _controller(
      file: const SelectedRadioBeaconFile(
        name: 'archivio_collega.txt',
        content: '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
RF-1;Altro;43.0;12.0;;;;;
''',
      ),
    );
    await controller.initialize();
    CatalogueImportPreview? preview;

    final success = await controller.importCatalogue(
      approve: (value) async {
        preview = value;
        return false;
      },
    );

    expect(success, isFalse);
    expect(preview!.fileNameDiffers, isTrue);
    expect(controller.catalogue, isNull);
  });
}

CatalogueController _controller({
  required SelectedRadioBeaconFile file,
  _FakeExport? export,
}) => CatalogueController(
  importService: RadioBeaconImportService(
    parser: RadioBeaconFileParser(),
    repository: InMemoryRadioBeaconRepository(),
  ),
  filePicker: _FakePicker(file),
  elevationService: RadioBeaconElevationService(_FakeElevation()),
  locationService: _FakeLocation(),
  exportService: export ?? _FakeExport(),
  identityService: _FakeIdentity(),
  clock: () => DateTime.utc(2026, 8, 14),
);

const _validFile = SelectedRadioBeaconFile(
  name: 'radiofari_gps_pointer.txt',
  content: '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
TEST-001;CasaPacico;42.982646;12.775651;;10;;;
''',
);

const _deviceId = 'GPSP-11111111-1111-1111-1111-111111111111';

final class _FakeIdentity implements DeviceInstallationIdService {
  DeviceIdentity identity = const DeviceIdentity(
    installationId: _deviceId,
    displayName: 'Telefono Test',
  );

  @override
  Future<DeviceIdentity> loadOrCreate() async => identity;

  @override
  Future<DeviceIdentity> updateDisplayName(String displayName) async =>
      identity = DeviceIdentity(
        installationId: identity.installationId,
        displayName: displayName,
      );
}

final class _FakePicker implements RadioBeaconFilePicker {
  const _FakePicker(this.file);
  final SelectedRadioBeaconFile file;
  @override
  Future<SelectedRadioBeaconFile?> selectFile() async => file;
}

final class _FakeElevation implements TerrainElevationProvider {
  @override
  Future<double> getTerrainElevationMeters(GeoPoint position) async => 321;
}

final class _FakeLocation implements DeviceLocationService {
  @override
  Future<DeviceLocationReading> readCurrentPosition() async =>
      const DeviceLocationReading(
        latitude: 43,
        longitude: 13,
        altitudeMeters: 400,
        horizontalAccuracyMeters: 3,
        verticalAccuracyMeters: 5,
      );
}

final class _FakeExport implements CatalogueExportService {
  String? content;
  @override
  Future<void> export(String content) async => this.content = content;
}
