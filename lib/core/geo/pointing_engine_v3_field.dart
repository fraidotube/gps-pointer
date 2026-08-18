import 'dart:math' as math;

final class PointingEngineV3FieldSnapshot {
  const PointingEngineV3FieldSnapshot({
    required this.anchored,
    required this.anchorTrueHeadingDegrees,
    required this.gyroHeadingDegrees,
    required this.guardedFusionHeadingDegrees,
    required this.lastProjectedYawRateDegreesPerSecond,
    required this.lastCorrectionDegrees,
  });

  final bool anchored;
  final double? anchorTrueHeadingDegrees;
  final double? gyroHeadingDegrees;
  final double? guardedFusionHeadingDegrees;
  final double lastProjectedYawRateDegreesPerSecond;
  final double lastCorrectionDegrees;
}

/// Field candidate derived from the +43/+44 experiments.
///
/// V2 remains untouched and is used in parallel as the control reference.
/// This engine uses the absolute magnetic/geomagnetic heading only to:
/// - establish the initial anchor while the phone is stationary and stable;
/// - slowly correct the guarded fusion while the phone is stationary.
/// During movement, relative heading comes from the gyroscope projected on
/// the gravity axis.
final class PointingEngineV3Field {
  PointingEngineV3Field({
    this.maximumStationaryCorrectionRateDegreesPerSecond = 0.45,
    this.maximumCorrectionDisagreementDegrees = 18.0,
  });

  final double maximumStationaryCorrectionRateDegreesPerSecond;
  final double maximumCorrectionDisagreementDegrees;

  double? _anchorTrueHeading;
  double? _gyroHeading;
  double? _guardedFusionHeading;
  double _lastProjectedYawRateDegreesPerSecond = 0;
  double _lastCorrectionDegrees = 0;

  bool get anchored => _gyroHeading != null && _guardedFusionHeading != null;

  void reset() {
    _anchorTrueHeading = null;
    _gyroHeading = null;
    _guardedFusionHeading = null;
    _lastProjectedYawRateDegreesPerSecond = 0;
    _lastCorrectionDegrees = 0;
  }

  void anchorAbsolute(double trueHeadingDegrees) {
    final heading = normalize(trueHeadingDegrees);
    _anchorTrueHeading = heading;
    _gyroHeading = heading;
    _guardedFusionHeading = heading;
    _lastCorrectionDegrees = 0;
  }

  PointingEngineV3FieldSnapshot update({
    required double projectedYawRateRadiansPerSecond,
    required double deltaSeconds,
    required bool deviceStationary,
    double? stableAbsoluteTrueHeadingDegrees,
  }) {
    if (!deltaSeconds.isFinite || deltaSeconds <= 0 || deltaSeconds > 0.25) {
      return snapshot;
    }

    final yawRateDegrees = projectedYawRateRadiansPerSecond * 180.0 / math.pi;
    _lastProjectedYawRateDegreesPerSecond = yawRateDegrees;

    // Same sign convention validated in the +43/+44 lab.
    final headingDelta = -yawRateDegrees * deltaSeconds;

    if (_gyroHeading != null) {
      _gyroHeading = normalize(_gyroHeading! + headingDelta);
    }

    _lastCorrectionDegrees = 0;
    if (_guardedFusionHeading != null) {
      var next = normalize(_guardedFusionHeading! + headingDelta);
      final absolute = stableAbsoluteTrueHeadingDegrees;
      if (deviceStationary && absolute != null && absolute.isFinite) {
        final error = signedAngle(normalize(absolute) - next);
        if (error.abs() <= maximumCorrectionDisagreementDegrees) {
          final maxCorrection =
              maximumStationaryCorrectionRateDegreesPerSecond * deltaSeconds;
          final correction = error
              .clamp(-maxCorrection, maxCorrection)
              .toDouble();
          next = normalize(next + correction);
          _lastCorrectionDegrees = correction;
        }
      }
      _guardedFusionHeading = next;
    }

    return snapshot;
  }

  PointingEngineV3FieldSnapshot get snapshot => PointingEngineV3FieldSnapshot(
    anchored: anchored,
    anchorTrueHeadingDegrees: _anchorTrueHeading,
    gyroHeadingDegrees: _gyroHeading,
    guardedFusionHeadingDegrees: _guardedFusionHeading,
    lastProjectedYawRateDegreesPerSecond: _lastProjectedYawRateDegreesPerSecond,
    lastCorrectionDegrees: _lastCorrectionDegrees,
  );

  static double normalize(double degrees) => (degrees % 360 + 360) % 360;

  static double signedAngle(double degrees) => (degrees + 540) % 360 - 180;
}
