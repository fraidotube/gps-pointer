import 'dart:math' as math;

final class PointingEngineV3Snapshot {
  const PointingEngineV3Snapshot({
    required this.anchored,
    required this.anchorTrueHeadingDegrees,
    required this.gyroHeadingDegrees,
    required this.fusionHeadingDegrees,
    required this.manualHeadingDegrees,
    required this.lastProjectedYawRateDegreesPerSecond,
  });

  final bool anchored;
  final double? anchorTrueHeadingDegrees;
  final double? gyroHeadingDegrees;
  final double? fusionHeadingDegrees;
  final double? manualHeadingDegrees;
  final double lastProjectedYawRateDegreesPerSecond;
}

/// Motore sperimentale V3 usato esclusivamente dall'Azimuth Lab.
///
/// Principi:
/// - heading assoluto solo per l'ancora iniziale e per una correzione lenta;
/// - movimento relativo dal giroscopio proiettato sull'asse di gravita';
/// - nessun offset fisso e nessuna modifica al PointingEngineV2.
final class PointingEngineV3Experimental {
  PointingEngineV3Experimental({
    this.maximumFusionCorrectionRateDegreesPerSecond = 0.35,
    this.maximumFusionDisagreementDegrees = 25,
  });

  final double maximumFusionCorrectionRateDegreesPerSecond;
  final double maximumFusionDisagreementDegrees;

  double? _anchorTrueHeading;
  double? _gyroHeading;
  double? _fusionHeading;
  double? _manualHeading;
  double _lastProjectedYawRateDegreesPerSecond = 0;

  bool get anchored => _gyroHeading != null && _fusionHeading != null;

  void reset() {
    _anchorTrueHeading = null;
    _gyroHeading = null;
    _fusionHeading = null;
    _manualHeading = null;
    _lastProjectedYawRateDegreesPerSecond = 0;
  }

  void anchorAbsolute(double trueHeadingDegrees) {
    final heading = normalize(trueHeadingDegrees);
    _anchorTrueHeading = heading;
    _gyroHeading = heading;
    _fusionHeading = heading;
  }

  void anchorManual(double knownTrueHeadingDegrees) {
    _manualHeading = normalize(knownTrueHeadingDegrees);
  }

  void clearManualAnchor() {
    _manualHeading = null;
  }

  PointingEngineV3Snapshot update({
    required double projectedYawRateRadiansPerSecond,
    required double deltaSeconds,
    double? absoluteTrueHeadingDegrees,
    bool absoluteHeadingStable = false,
  }) {
    if (!deltaSeconds.isFinite || deltaSeconds <= 0 || deltaSeconds > 0.25) {
      return snapshot;
    }

    final yawRateDegrees = projectedYawRateRadiansPerSecond * 180.0 / math.pi;
    _lastProjectedYawRateDegreesPerSecond = yawRateDegrees;

    // Android/sensors_plus usa la convenzione destrorsa. Nei test +42 una
    // rotazione positiva attorno alla gravita' corrisponde a una diminuzione
    // dell'azimuth bussola, quindi il segno viene invertito qui.
    final headingDelta = -yawRateDegrees * deltaSeconds;

    if (_gyroHeading != null) {
      _gyroHeading = normalize(_gyroHeading! + headingDelta);
    }
    if (_fusionHeading != null) {
      var next = normalize(_fusionHeading! + headingDelta);
      final absolute = absoluteTrueHeadingDegrees;
      if (absolute != null && absoluteHeadingStable && absolute.isFinite) {
        final error = signedAngle(normalize(absolute) - next);
        if (error.abs() <= maximumFusionDisagreementDegrees) {
          final maxCorrection =
              maximumFusionCorrectionRateDegreesPerSecond * deltaSeconds;
          final correction = error
              .clamp(-maxCorrection, maxCorrection)
              .toDouble();
          next = normalize(next + correction);
        }
      }
      _fusionHeading = next;
    }
    if (_manualHeading != null) {
      _manualHeading = normalize(_manualHeading! + headingDelta);
    }

    return snapshot;
  }

  PointingEngineV3Snapshot get snapshot => PointingEngineV3Snapshot(
    anchored: anchored,
    anchorTrueHeadingDegrees: _anchorTrueHeading,
    gyroHeadingDegrees: _gyroHeading,
    fusionHeadingDegrees: _fusionHeading,
    manualHeadingDegrees: _manualHeading,
    lastProjectedYawRateDegreesPerSecond: _lastProjectedYawRateDegreesPerSecond,
  );

  static double normalize(double degrees) => (degrees % 360 + 360) % 360;

  static double signedAngle(double degrees) => (degrees + 540) % 360 - 180;
}
