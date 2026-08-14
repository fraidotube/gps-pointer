import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  group('GeoCalculator', () {
    test('returns zero distance and bearing for equal points', () {
      const point = GeoPoint(latitude: 42.0, longitude: 12.0);
      final result = GeoCalculator.between(point, point);
      expect(result.distanceMeters, 0);
      expect(result.initialBearingDegrees, 0);
    });

    test('calculates one degree east on the equator', () {
      const origin = GeoPoint(latitude: 0, longitude: 0);
      const destination = GeoPoint(latitude: 0, longitude: 1);
      final result = GeoCalculator.between(origin, destination);
      expect(result.distanceMeters, closeTo(111195.08, 0.02));
      expect(result.initialBearingDegrees, closeTo(90, 0.000001));
    });

    test('calculates one degree north on the equator', () {
      const origin = GeoPoint(latitude: 0, longitude: 0);
      const destination = GeoPoint(latitude: 1, longitude: 0);
      final result = GeoCalculator.between(origin, destination);
      expect(result.distanceMeters, closeTo(111195.08, 0.02));
      expect(result.initialBearingDegrees, closeTo(0, 0.000001));
    });

    test('normalizes negative and overflowing angles', () {
      expect(GeoCalculator.normalizeDegrees(-1), 359);
      expect(GeoCalculator.normalizeDegrees(361), 1);
      expect(GeoCalculator.normalizeDegrees(720), 0);
    });

    test('calculates bearing, distance and positive elevation angle', () {
      const origin = GeoPoint(latitude: 0, longitude: 0);
      const destination = GeoPoint(latitude: 0, longitude: 0.001);
      final result = GeoCalculator.pointing(
        origin: origin,
        originElevationMeters: 100,
        destination: destination,
        destinationElevationMeters: 110,
      );
      expect(result.distanceMeters, closeTo(111.195, 0.01));
      expect(result.initialBearingDegrees, closeTo(90, 0.000001));
      expect(result.heightDifferenceMeters, 10);
      expect(result.elevationAngleDegrees, closeTo(5.138, 0.01));
    });
  });
}
