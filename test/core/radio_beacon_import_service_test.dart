import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  test('replaces the whole catalogue after complete validation', () async {
    final repository = InMemoryRadioBeaconRepository();
    final service = RadioBeaconImportService(
      parser: RadioBeaconFileParser(),
      repository: repository,
    );
    const first = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
OLD-1;Old;40.0;10.0;;;;;
''';
    const replacement = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
TEST-001;CasaPacico;42.982646;12.775651;;;;;
NEW-2;New;43.0;13.0;;500;;;
''';

    await service.importText(
      first,
      sourceFileName: 'first.txt',
      importedAt: DateTime.utc(2026, 8, 14, 10),
    );
    final summary = await service.importText(
      replacement,
      sourceFileName: 'replacement.txt',
      importedAt: DateTime.utc(2026, 8, 14, 11),
    );

    expect(summary.formatVersion, 3);
    expect(summary.importedCount, 2);
    final catalogue = await service.currentCatalogue();
    expect(catalogue!.sourceFileName, 'replacement.txt');
    expect(catalogue.beacons.map((beacon) => beacon.id), ['TEST-001', 'NEW-2']);
  });

  test('does not modify the catalogue when validation fails', () async {
    final repository = InMemoryRadioBeaconRepository();
    final service = RadioBeaconImportService(
      parser: RadioBeaconFileParser(),
      repository: repository,
    );
    const valid = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
SAFE-1;Existing;42.0;12.0;;;;;
''';
    const invalid = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
BAD-1;Broken;999.0;12.0;;;;;
''';

    await service.importText(
      valid,
      sourceFileName: 'valid.txt',
      importedAt: DateTime.utc(2026, 8, 14),
    );
    await expectLater(
      service.importText(
        invalid,
        sourceFileName: 'invalid.txt',
        importedAt: DateTime.utc(2026, 8, 15),
      ),
      throwsA(isA<RadioBeaconImportException>()),
    );

    final catalogue = await service.currentCatalogue();
    expect(catalogue!.sourceFileName, 'valid.txt');
    expect(catalogue.beacons.single.id, 'SAFE-1');
  });
}
