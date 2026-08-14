import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';
import 'package:gps_pointer/infrastructure/json_radio_beacon_repository.dart';

void main() {
  test('persists and reloads catalogue metadata and beacons', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gps_pointer_repository_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = JsonRadioBeaconRepository(
      File('${directory.path}/catalogue.json'),
    );
    final importedAt = DateTime.utc(2026, 8, 14, 12, 30);
    await repository.replace(
      RadioBeaconCatalogue(
        sourceFileName: 'radiofari_test.txt',
        importedAt: importedAt,
        beacons: const [
          RadioBeacon(
            id: 'TEST-001',
            name: 'CasaPacico',
            position: GeoPoint(latitude: 42.982646, longitude: 12.775651),
            poleHeightMeters: 3.5,
          ),
        ],
      ),
    );

    final loaded = await repository.load();
    expect(loaded!.sourceFileName, 'radiofari_test.txt');
    expect(loaded.importedAt, importedAt);
    expect(loaded.beacons.single.name, 'CasaPacico');
    expect(loaded.beacons.single.poleHeightMeters, 3.5);
  });

  test('returns null when no catalogue exists', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gps_pointer_empty_repository_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = JsonRadioBeaconRepository(
      File('${directory.path}/missing.json'),
    );

    expect(await repository.load(), isNull);
  });
}
