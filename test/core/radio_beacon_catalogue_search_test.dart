import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  const first = RadioBeacon(
    id: 'TEST-001',
    name: 'CasaPacico',
    position: GeoPoint(latitude: 42.982646, longitude: 12.775651),
  );
  const second = RadioBeacon(
    id: 'CROCE-PALE-001',
    name: 'Croce di Pale',
    position: GeoPoint(latitude: 42.989033, longitude: 12.777068),
  );

  test('empty query preserves every beacon', () {
    expect(RadioBeaconCatalogueSearch.filter([first, second], ''), [
      first,
      second,
    ]);
  });

  test('search is case insensitive across name and identifier', () {
    expect(RadioBeaconCatalogueSearch.filter([first, second], 'croce'), [
      second,
    ]);
    expect(RadioBeaconCatalogueSearch.filter([first, second], 'test-001'), [
      first,
    ]);
  });

  test('search accepts a coordinate fragment', () {
    expect(RadioBeaconCatalogueSearch.filter([first, second], '12.777'), [
      second,
    ]);
  });

  test('radius filter excludes distant beacons and sorts nearest first', () {
    const origin = GeoPoint(latitude: 42.9827, longitude: 12.7757);
    final results = RadioBeaconCatalogueSearch.search(
      beacons: [second, first],
      query: '',
      origin: origin,
      maximumDistanceMeters: 2000,
    );

    expect(results.map((result) => result.beacon), [first, second]);
    expect(
      results.first.distanceMeters,
      lessThan(results.last.distanceMeters!),
    );
  });

  test('origin keeps distances and nearest sorting without a radius limit', () {
    const origin = GeoPoint(latitude: 42.9827, longitude: 12.7757);
    final results = RadioBeaconCatalogueSearch.search(
      beacons: [second, first],
      query: '',
      origin: origin,
    );

    expect(results.map((result) => result.beacon), [first, second]);
    expect(results.every((result) => result.distanceMeters != null), isTrue);
  });

  test('text search and radius filter are combined', () {
    const origin = GeoPoint(latitude: 42.9827, longitude: 12.7757);
    final results = RadioBeaconCatalogueSearch.search(
      beacons: [first, second],
      query: 'croce',
      origin: origin,
      maximumDistanceMeters: 2000,
    );

    expect(results.map((result) => result.beacon), [second]);
  });

  test('distance filter without an origin is rejected', () {
    expect(
      () => RadioBeaconCatalogueSearch.search(
        beacons: [first],
        query: '',
        maximumDistanceMeters: 1000,
      ),
      throwsArgumentError,
    );
  });
}
