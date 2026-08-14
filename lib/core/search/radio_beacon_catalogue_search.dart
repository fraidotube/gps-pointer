import '../domain/radio_beacon.dart';
import '../domain/geo_point.dart';
import '../geo/geo_calculator.dart';

final class RadioBeaconSearchResult {
  const RadioBeaconSearchResult({
    required this.beacon,
    required this.distanceMeters,
  });

  final RadioBeacon beacon;
  final double? distanceMeters;
}

/// Pure, side-effect-free catalogue search.
abstract final class RadioBeaconCatalogueSearch {
  static List<RadioBeacon> filter(Iterable<RadioBeacon> beacons, String query) {
    return List<RadioBeacon>.unmodifiable(
      search(beacons: beacons, query: query).map((result) => result.beacon),
    );
  }

  static List<RadioBeaconSearchResult> search({
    required Iterable<RadioBeacon> beacons,
    required String query,
    GeoPoint? origin,
    double? maximumDistanceMeters,
  }) {
    if (maximumDistanceMeters != null && origin == null) {
      throw ArgumentError('Il filtro di distanza richiede una posizione.');
    }
    if (maximumDistanceMeters != null &&
        (!maximumDistanceMeters.isFinite || maximumDistanceMeters < 0)) {
      throw ArgumentError.value(maximumDistanceMeters, 'maximumDistanceMeters');
    }

    final needle = query.trim().toLowerCase();
    final results = <RadioBeaconSearchResult>[];
    for (final beacon in beacons) {
      if (needle.isNotEmpty && !_matches(beacon, needle)) continue;
      final distance = origin == null
          ? null
          : GeoCalculator.distanceMeters(origin, beacon.position);
      if (maximumDistanceMeters != null && distance! > maximumDistanceMeters) {
        continue;
      }
      results.add(
        RadioBeaconSearchResult(beacon: beacon, distanceMeters: distance),
      );
    }
    if (origin != null) {
      results.sort(
        (first, second) =>
            first.distanceMeters!.compareTo(second.distanceMeters!),
      );
    }
    return List<RadioBeaconSearchResult>.unmodifiable(results);
  }

  static bool _matches(RadioBeacon beacon, String needle) {
    final searchable = <String>[
      beacon.id,
      beacon.name,
      beacon.position.latitude.toString(),
      beacon.position.longitude.toString(),
    ].join(' ').toLowerCase();
    return searchable.contains(needle);
  }
}
