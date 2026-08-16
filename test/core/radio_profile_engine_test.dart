import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  test('same numeric fixtures as server Python engine', () {
    final cases =
        jsonDecode(
              File('test/fixtures/radio_profile_cases.json').readAsStringSync(),
            )
            as List<dynamic>;
    for (final rawCase in cases) {
      final item = Map<String, dynamic>.from(rawCase as Map);
      final input = Map<String, dynamic>.from(item['input'] as Map);
      final expected = Map<String, dynamic>.from(item['expected'] as Map);
      final result = RadioProfileEngine.build(
        distanceMeters: (input['distance_m'] as num).toDouble(),
        elevationsMeters: (input['elevations_m'] as List<dynamic>)
            .map((value) => (value as num).toDouble())
            .toList(),
        installerAntennaHeightMeters:
            (input['installer_antenna_height_m'] as num).toDouble(),
        targetAntennaHeightMeters: (input['target_antenna_height_m'] as num)
            .toDouble(),
        frequencyGhz: (input['frequency_ghz'] as num?)?.toDouble(),
      );
      expect(
        result.minimumLosClearanceMeters,
        closeTo((expected['minimum_los_clearance_m'] as num).toDouble(), 1e-9),
      );
      expect(
        result.minimumFresnelClearanceMeters,
        closeTo(
          (expected['minimum_fresnel_clearance_m'] as num).toDouble(),
          1e-9,
        ),
      );
      expect(result.lineOfSightClear, expected['line_of_sight_clear']);
      expect(result.firstFresnelClear, expected['first_fresnel_clear']);
    }
  });

  test('sampling matches server rules', () {
    expect(RadioProfileEngine.sampleCountForDistance(900), 11);
    expect(RadioProfileEngine.sampleCountForDistance(100000), 500);
    expect(
      () => RadioProfileEngine.sampleCountForDistance(1),
      throwsFormatException,
    );
  });

  test('geodesic sampling preserves endpoints', () {
    final start = GeoPoint.validated(latitude: 42.98, longitude: 12.77);
    final end = GeoPoint.validated(latitude: 43.05, longitude: 12.67);
    final points = RadioProfileEngine.geodesicCoordinates(start, end, 25);
    expect(points.length, 25);
    expect(points.first.latitude, closeTo(start.latitude, 1e-10));
    expect(points.first.longitude, closeTo(start.longitude, 1e-10));
    expect(points.last.latitude, closeTo(end.latitude, 1e-10));
    expect(points.last.longitude, closeTo(end.longitude, 1e-10));
  });
}
