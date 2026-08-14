import '../domain/radio_beacon.dart';
import '../domain/radio_beacon_catalogue.dart';
import '../import/radio_beacon_file_parser.dart';

final class RadioBeaconFileExporter {
  const RadioBeaconFileExporter();

  String export(
    RadioBeaconCatalogue catalogue, {
    required DateTime exportedAtUtc,
    required String deviceId,
    required String deviceName,
  }) {
    return [
      RadioBeaconFileParser.signature,
      RadioBeaconFileParser.metadataHeader,
      [
        exportedAtUtc.toUtc().toIso8601String(),
        deviceId,
        _escape(deviceName),
      ].join(';'),
      RadioBeaconFileParser.header,
      ...catalogue.beacons.map(_row),
      '',
    ].join('\n');
  }

  static String _row(RadioBeacon beacon) => [
    beacon.id,
    _escape(beacon.name),
    beacon.position.latitude.toString(),
    beacon.position.longitude.toString(),
    beacon.terrainElevationMeters?.toString() ?? '',
    beacon.poleHeightMeters.toString(),
    beacon.elevationSource ?? '',
    beacon.horizontalAccuracyMeters?.toString() ?? '',
    beacon.verticalAccuracyMeters?.toString() ?? '',
  ].join(';');

  static String _escape(String value) =>
      value.contains(';') || value.contains('"')
      ? '"${value.replaceAll('"', '""')}"'
      : value;
}
