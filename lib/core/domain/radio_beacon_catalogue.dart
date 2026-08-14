import 'radio_beacon.dart';

final class RadioBeaconCatalogue {
  RadioBeaconCatalogue({
    required List<RadioBeacon> beacons,
    required this.sourceFileName,
    required DateTime importedAt,
  }) : beacons = List.unmodifiable(beacons),
       importedAt = importedAt.toUtc();

  final List<RadioBeacon> beacons;
  final String sourceFileName;
  final DateTime importedAt;
}
