import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  test('screen-up gravity vector is horizontal', () {
    expect(
      HorizontalDeviceCalculator.tiltFromHorizontalDegrees(x: 0, y: 0, z: 9.81),
      closeTo(0, 0.001),
    );
  });

  test('vertical device is ninety degrees from horizontal', () {
    expect(
      HorizontalDeviceCalculator.tiltFromHorizontalDegrees(x: 0, y: 9.81, z: 0),
      closeTo(90, 0.001),
    );
  });

  test('invalid zero vector fails closed', () {
    expect(
      HorizontalDeviceCalculator.tiltFromHorizontalDegrees(x: 0, y: 0, z: 0),
      90,
    );
  });
}
