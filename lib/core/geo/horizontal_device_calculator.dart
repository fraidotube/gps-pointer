import 'dart:math' as math;

/// Calculates how far the device screen is from a horizontal position.
abstract final class HorizontalDeviceCalculator {
  static double tiltFromHorizontalDegrees({
    required double x,
    required double y,
    required double z,
  }) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (!magnitude.isFinite || magnitude == 0) return 90;
    final cosine = (z.abs() / magnitude).clamp(0.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }
}
