import '../domain/geo_point.dart';
import '../domain/radio_beacon.dart';
import 'radio_beacon_import_error.dart';

final class RadioBeaconFileParseResult {
  const RadioBeaconFileParseResult({
    required this.formatVersion,
    required this.beacons,
    this.exportedAtUtc,
    this.deviceId,
    this.deviceName,
  });

  final int formatVersion;
  final List<RadioBeacon> beacons;
  final DateTime? exportedAtUtc;
  final String? deviceId;
  final String? deviceName;
}

final class RadioBeaconFileParser {
  static const signature = 'GPS_POINTER_RADIOFARI;3';
  static const metadataHeader = 'esportato_utc;id_dispositivo;nome_dispositivo';
  static const header =
      'id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;'
      'fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m';
  static final _validId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
  static final _validDeviceId = RegExp(
    r'^GPSP-[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$',
  );

  RadioBeaconFileParseResult parse(String content) {
    final lines = content
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final issues = <RadioBeaconImportIssue>[];
    if (lines.isEmpty || lines.first != signature) {
      issues.add(
        const RadioBeaconImportIssue(
          code: 'invalid_signature',
          line: 1,
          message: 'Expected GPS_POINTER_RADIOFARI;3.',
        ),
      );
    }
    if (lines.length < 2 || lines[1] != metadataHeader) {
      issues.add(
        const RadioBeaconImportIssue(
          code: 'invalid_metadata_header',
          line: 2,
          message: 'Expected the GPS Pointer version 3 metadata header.',
        ),
      );
    }
    DateTime? exportedAtUtc;
    String? deviceId;
    String? deviceName;
    if (lines.length < 3) {
      issues.add(
        const RadioBeaconImportIssue(
          code: 'invalid_metadata',
          line: 3,
          message: 'Missing version 3 metadata values.',
        ),
      );
    } else {
      final metadata = _split(lines[2]);
      if (metadata.length != 3) {
        issues.add(
          const RadioBeaconImportIssue(
            code: 'invalid_metadata',
            line: 3,
            message: 'Expected timestamp, device identifier and device name.',
          ),
        );
      } else {
        final timestampText = metadata[0].trim();
        final deviceIdText = metadata[1].trim();
        final deviceNameText = metadata[2].trim();
        exportedAtUtc = timestampText.isEmpty
            ? null
            : DateTime.tryParse(timestampText)?.toUtc();
        deviceId = deviceIdText.isEmpty ? null : deviceIdText;
        deviceName = deviceNameText.isEmpty ? null : deviceNameText;
        if ((timestampText.isNotEmpty && exportedAtUtc == null) ||
            (deviceId != null && !_validDeviceId.hasMatch(deviceId)) ||
            (deviceName != null && deviceName.length > 80)) {
          issues.add(
            const RadioBeaconImportIssue(
              code: 'invalid_metadata',
              line: 3,
              message: 'Invalid timestamp, device identifier or device name.',
            ),
          );
        }
      }
    }
    const headerIndex = 3;
    if (lines.length <= headerIndex || lines[headerIndex] != header) {
      issues.add(
        RadioBeaconImportIssue(
          code: 'invalid_header',
          line: headerIndex + 1,
          message: 'Expected the GPS Pointer version 3 radio beacon header.',
        ),
      );
    }
    if (issues.isNotEmpty) throw RadioBeaconImportException(issues);

    final beacons = <RadioBeacon>[];
    final ids = <String>{};
    for (var index = headerIndex + 1; index < lines.length; index++) {
      if (lines[index].trim().isEmpty) continue;
      final line = index + 1;
      late final List<String> fields;
      try {
        fields = _split(lines[index]);
      } on FormatException catch (error) {
        issues.add(
          RadioBeaconImportIssue(
            code: 'malformed_row',
            line: line,
            message: error.message,
          ),
        );
        continue;
      }
      if (fields.length != 9) {
        issues.add(
          RadioBeaconImportIssue(
            code: 'wrong_field_count',
            line: line,
            message: 'Expected 9 fields, found ${fields.length}.',
          ),
        );
        continue;
      }
      final id = fields[0].trim();
      final name = fields[1].trim();
      final latitude = _decimal(fields[2]);
      final longitude = _decimal(fields[3]);
      final elevation = _optionalDecimal(fields[4]);
      final pole = fields[5].trim().isEmpty ? 0.0 : _decimal(fields[5]);
      final source = fields[6].trim();
      final horizontalAccuracy = _optionalDecimal(fields[7]);
      final verticalAccuracy = _optionalDecimal(fields[8]);
      var valid = true;

      void issue(String code, String field, String message) {
        valid = false;
        issues.add(
          RadioBeaconImportIssue(
            code: code,
            line: line,
            field: field,
            message: message,
          ),
        );
      }

      if (!_validId.hasMatch(id)) {
        issue('invalid_id', 'id', 'Invalid identifier.');
      } else if (!ids.add(id.toLowerCase())) {
        issue('duplicate_id', 'id', 'Duplicate identifier: $id.');
      }
      if (name.isEmpty || name.length > 120) {
        issue('invalid_name', 'nome', 'Name must contain 1-120 characters.');
      }
      if (latitude == null || latitude < -90 || latitude > 90) {
        issue('invalid_latitude', 'latitudine', 'Use -90 to 90.');
      }
      if (longitude == null || longitude < -180 || longitude > 180) {
        issue('invalid_longitude', 'longitudine', 'Use -180 to 180.');
      }
      if (fields[4].trim().isNotEmpty && elevation == null) {
        issue('invalid_elevation', 'quota_terreno_m', 'Use a decimal point.');
      }
      if (pole == null || pole < 0) {
        issue('invalid_pole_height', 'altezza_palo_m', 'Use zero or more.');
      }
      if (elevation == null && source.isNotEmpty) {
        issue('source_without_elevation', 'fonte_quota', 'Elevation is empty.');
      }
      if (horizontalAccuracy != null && horizontalAccuracy < 0) {
        issue(
          'invalid_accuracy',
          'accuratezza_orizzontale_m',
          'Use zero or more.',
        );
      }
      if (verticalAccuracy != null && verticalAccuracy < 0) {
        issue(
          'invalid_accuracy',
          'accuratezza_verticale_m',
          'Use zero or more.',
        );
      }
      if (valid) {
        beacons.add(
          RadioBeacon(
            id: id,
            name: name,
            position: GeoPoint.validated(
              latitude: latitude!,
              longitude: longitude!,
            ),
            terrainElevationMeters: elevation,
            poleHeightMeters: pole!,
            elevationSource: source.isEmpty ? null : source,
            horizontalAccuracyMeters: horizontalAccuracy,
            verticalAccuracyMeters: verticalAccuracy,
          ),
        );
      }
    }
    if (beacons.isEmpty && issues.isEmpty) {
      issues.add(
        const RadioBeaconImportIssue(
          code: 'empty_catalogue',
          message: 'The file must contain at least one radio beacon.',
        ),
      );
    }
    if (issues.isNotEmpty) throw RadioBeaconImportException(issues);
    return RadioBeaconFileParseResult(
      formatVersion: 3,
      beacons: List.unmodifiable(beacons),
      exportedAtUtc: exportedAtUtc,
      deviceId: deviceId,
      deviceName: deviceName,
    );
  }

  static double? _decimal(String value) {
    final text = value.trim();
    if (text.isEmpty || text.contains(',')) return null;
    final parsed = double.tryParse(text);
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static double? _optionalDecimal(String value) =>
      value.trim().isEmpty ? null : _decimal(value);

  static List<String> _split(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final character = line[i];
      if (character == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ';' && !quoted) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(character);
      }
    }
    if (quoted) throw const FormatException('Unclosed quoted field.');
    fields.add(buffer.toString());
    return fields;
  }
}
