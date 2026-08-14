import 'dart:math' as math;

/// Pure accelerometer calculations for a phone held in portrait orientation.
abstract final class DeviceOrientationCalculator {
  static double cameraElevationDegrees({
    required double x,
    required double y,
    required double z,
  }) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) {
      throw const FormatException('Accelerometer values must be finite.');
    }
    final verticalPlaneMagnitude = math.sqrt(x * x + y * y);
    // The rear camera optical axis has the opposite vertical convention to
    // the positive Z direction reported by the Android accelerometer.
    return -math.atan2(z, verticalPlaneMagnitude) * 180 / math.pi;
  }
}
