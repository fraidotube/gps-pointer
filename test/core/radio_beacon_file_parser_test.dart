import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  const validFile = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
2026-08-14T10:00:00.000Z;GPSP-11111111-1111-1111-1111-111111111111;Telefono Test
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
TEST-001;CasaPacico;42.982646;12.775651;;;;;
RF-002;Monte Test;43.1;12.2;;1234.5;;;
''';

  group('RadioBeaconFileParser', () {
    test('parses a valid version 3 file with provenance', () {
      final result = RadioBeaconFileParser().parse(validFile);

      expect(result.formatVersion, 3);
      expect(result.deviceName, 'Telefono Test');
      expect(result.deviceId, 'GPSP-11111111-1111-1111-1111-111111111111');
      expect(result.exportedAtUtc, DateTime.utc(2026, 8, 14, 10));
      expect(result.beacons, hasLength(2));
      expect(result.beacons.first.id, 'TEST-001');
      expect(result.beacons.first.name, 'CasaPacico');
      expect(result.beacons.first.position.latitude, 42.982646);
      expect(result.beacons.first.position.longitude, 12.775651);
      expect(result.beacons.first.poleHeightMeters, 0);
      expect(result.beacons.last.poleHeightMeters, 1234.5);
      expect(result.beacons.first.terrainElevationMeters, isNull);
      expect(result.beacons.first.antennaElevationMeters, isNull);
    });

    test('supports semicolons and escaped quotes in a quoted name', () {
      const content = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
RF-1;"Monte; ""Nord""";43.0;12.0;;;;;
''';
      final beacon = RadioBeaconFileParser().parse(content).beacons.single;
      expect(beacon.name, 'Monte; "Nord"');
    });

    test('rejects comma decimal coordinates', () {
      const content = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
RF-1;Test;42,9;12.7;;;;;
''';
      expect(
        () => RadioBeaconFileParser().parse(content),
        throwsA(
          isA<RadioBeaconImportException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'codes',
            contains('invalid_latitude'),
          ),
        ),
      );
    });

    test('rejects case-insensitive duplicate identifiers', () {
      const content = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
RF-1;First;43.0;12.0;;;;;
rf-1;Second;44.0;13.0;;;;;
''';
      expect(
        () => RadioBeaconFileParser().parse(content),
        throwsA(
          isA<RadioBeaconImportException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'codes',
            contains('duplicate_id'),
          ),
        ),
      );
    });

    test('rejects an empty catalogue', () {
      const content = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
''';
      expect(
        () => RadioBeaconFileParser().parse(content),
        throwsA(isA<RadioBeaconImportException>()),
      );
    });

    test('accepts missing provenance values for first import', () {
      const content = '''GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
RF-1;Test;43.0;12.0;;;;;
''';
      final result = RadioBeaconFileParser().parse(content);
      expect(result.exportedAtUtc, isNull);
      expect(result.deviceId, isNull);
      expect(result.deviceName, isNull);
    });

    test('rejects the obsolete version 2 signature', () {
      const content = '''GPS_POINTER_RADIOFARI;2
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
RF-1;Test;43.0;12.0;;;;;
''';
      expect(
        () => RadioBeaconFileParser().parse(content),
        throwsA(isA<RadioBeaconImportException>()),
      );
    });
  });
}
