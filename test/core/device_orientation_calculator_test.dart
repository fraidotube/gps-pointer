import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  group('DeviceOrientationCalculator', () {
    test('portrait vertical phone looks at the horizon', () {
      final angle = DeviceOrientationCalculator.cameraElevationDegrees(
        x: 0,
        y: 9.81,
        z: 0,
      );
      expect(angle, closeTo(0, 0.000001));
    });

    test('rear camera aimed down returns a negative angle', () {
      final angle = DeviceOrientationCalculator.cameraElevationDegrees(
        x: 0,
        y: 0,
        z: 9.81,
      );
      expect(angle, closeTo(-90, 0.000001));
    });

    test('rear camera aimed up returns a positive angle', () {
      final angle = DeviceOrientationCalculator.cameraElevationDegrees(
        x: 0,
        y: 0,
        z: -9.81,
      );
      expect(angle, closeTo(90, 0.000001));
    });

    test('rear camera halfway down returns minus forty five degrees', () {
      final angle = DeviceOrientationCalculator.cameraElevationDegrees(
        x: 0,
        y: 9.81,
        z: 9.81,
      );
      expect(angle, closeTo(-45, 0.000001));
    });

    test('rejects non finite sensor values', () {
      expect(
        () => DeviceOrientationCalculator.cameraElevationDegrees(
          x: double.nan,
          y: 0,
          z: 0,
        ),
        throwsFormatException,
      );
    });
  });
}
