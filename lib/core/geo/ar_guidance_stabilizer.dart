final class StabilizedArGuidance {
  const StabilizedArGuidance({
    required this.horizontalDeltaDegrees,
    required this.cameraElevationDegrees,
    required this.verticalDeltaDegrees,
    required this.centered,
  });

  final double horizontalDeltaDegrees;
  final double cameraElevationDegrees;
  final double verticalDeltaDegrees;
  final bool centered;
}

/// Stateful low-pass filter and hysteresis for noisy phone orientation sensors.
final class ArGuidanceStabilizer {
  ArGuidanceStabilizer({
    this.smoothingFactor = 0.12,
    this.maximumStepDegrees = 1.5,
  });

  final double smoothingFactor;
  final double maximumStepDegrees;
  double? _horizontalDelta;
  double? _cameraElevation;
  bool _centered = false;

  StabilizedArGuidance update({
    required double horizontalDeltaDegrees,
    required double cameraElevationDegrees,
    required double targetElevationDegrees,
  }) {
    _horizontalDelta = _filtered(
      previous: _horizontalDelta,
      current: horizontalDeltaDegrees,
    );
    _cameraElevation = _filtered(
      previous: _cameraElevation,
      current: cameraElevationDegrees,
    );
    final verticalDelta = targetElevationDegrees - _cameraElevation!;
    if (_centered) {
      _centered = _horizontalDelta!.abs() <= 3 && verticalDelta.abs() <= 1.5;
    } else {
      _centered = _horizontalDelta!.abs() <= 2 && verticalDelta.abs() <= 1;
    }
    return StabilizedArGuidance(
      horizontalDeltaDegrees: _horizontalDelta!,
      cameraElevationDegrees: _cameraElevation!,
      verticalDeltaDegrees: verticalDelta,
      centered: _centered,
    );
  }

  double _filtered({required double? previous, required double current}) {
    if (previous == null) return current;
    final requestedStep = (current - previous) * smoothingFactor;
    final boundedStep = requestedStep
        .clamp(-maximumStepDegrees, maximumStepDegrees)
        .toDouble();
    return previous + boundedStep;
  }
}
