import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  test('smooths abrupt sensor changes', () {
    final stabilizer = ArGuidanceStabilizer();
    stabilizer.update(
      horizontalDeltaDegrees: 0,
      cameraElevationDegrees: 0,
      targetElevationDegrees: 0,
    );
    final result = stabilizer.update(
      horizontalDeltaDegrees: 30,
      cameraElevationDegrees: 30,
      targetElevationDegrees: 0,
    );
    expect(result.horizontalDeltaDegrees, 1.5);
    expect(result.cameraElevationDegrees, 1.5);
  });

  test('uses hysteresis to keep a centered state stable', () {
    final stabilizer = ArGuidanceStabilizer(
      smoothingFactor: 1,
      maximumStepDegrees: 100,
    );
    final centered = stabilizer.update(
      horizontalDeltaDegrees: 2,
      cameraElevationDegrees: 1,
      targetElevationDegrees: 0,
    );
    expect(centered.centered, isTrue);

    final smallNoise = stabilizer.update(
      horizontalDeltaDegrees: 2.8,
      cameraElevationDegrees: 1.4,
      targetElevationDegrees: 0,
    );
    expect(smallNoise.centered, isTrue);

    final outsideExitThreshold = stabilizer.update(
      horizontalDeltaDegrees: 3.2,
      cameraElevationDegrees: 1.6,
      targetElevationDegrees: 0,
    );
    expect(outsideExitThreshold.centered, isFalse);
  });
}
