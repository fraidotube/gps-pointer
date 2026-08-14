import 'dart:math' as math;

enum PointingEngineState { warmingUp, ready, unstable }

final class PointingEngineReading {
  const PointingEngineReading({
    required this.state,
    required this.warmupProgress,
    required this.magneticHeadingDegrees,
    required this.trueHeadingDegrees,
    required this.horizontalDeltaDegrees,
    required this.cameraElevationDegrees,
    required this.verticalDeltaDegrees,
    required this.centered,
  });

  final PointingEngineState state;
  final double warmupProgress;
  final double magneticHeadingDegrees;
  final double trueHeadingDegrees;
  final double horizontalDeltaDegrees;
  final double cameraElevationDegrees;
  final double verticalDeltaDegrees;
  final bool centered;
}

/// Motore V2: warm-up reale, media circolare e filtro adattivo.
final class PointingEngineV2 {
  PointingEngineV2({
    required this.targetAzimuthDegrees,
    required this.targetElevationDegrees,
    required this.declinationDegrees,
    this.minimumWarmupSamples = 24,
    this.maximumWarmupSamples = 600,
    this.maximumWarmupSpreadDegrees = 3,
    this.minimumStableDuration = const Duration(seconds: 2),
    this.maximumWarmupDuration = const Duration(seconds: 12),
  });

  final double targetAzimuthDegrees;
  final double targetElevationDegrees;
  final double declinationDegrees;
  final int minimumWarmupSamples;
  final int maximumWarmupSamples;
  final double maximumWarmupSpreadDegrees;
  final Duration minimumStableDuration;
  final Duration maximumWarmupDuration;

  final List<double> _warmupHeadings = <double>[];
  final List<double> _warmupElevations = <double>[];
  final List<DateTime> _warmupTimestamps = <DateTime>[];
  int _warmupAttempts = 0;
  DateTime? _warmupStartedAt;
  PointingEngineState _state = PointingEngineState.warmingUp;
  double? _filteredTrueHeading;
  double? _filteredCameraElevation;
  bool _centered = false;

  PointingEngineState get state => _state;

  PointingEngineReading update({
    required double magneticHeadingDegrees,
    required double cameraElevationDegrees,
    DateTime? timestamp,
  }) {
    final sampleTime = timestamp ?? DateTime.now();
    final magnetic = normalize(magneticHeadingDegrees);
    final trueHeading = normalize(magnetic + declinationDegrees);

    if (_state == PointingEngineState.warmingUp) {
      _warmupStartedAt ??= sampleTime;
      _warmupAttempts++;
      _warmupHeadings.add(trueHeading);
      _warmupElevations.add(cameraElevationDegrees);
      _warmupTimestamps.add(sampleTime);
      while (_warmupHeadings.length > 1 &&
          _circularSpread(_warmupHeadings) > maximumWarmupSpreadDegrees) {
        _warmupHeadings.removeAt(0);
        _warmupElevations.removeAt(0);
        _warmupTimestamps.removeAt(0);
      }
      if (_warmupHeadings.length >= minimumWarmupSamples) {
        final mean = _circularMean(_warmupHeadings);
        final stableDuration = sampleTime.difference(_warmupTimestamps.first);
        if (stableDuration >= minimumStableDuration) {
          _filteredTrueHeading = mean;
          _filteredCameraElevation = _average(_warmupElevations);
          _state = PointingEngineState.ready;
        }
      }
      if (_state == PointingEngineState.warmingUp &&
          (_warmupAttempts >= maximumWarmupSamples ||
              sampleTime.difference(_warmupStartedAt!) >=
                  maximumWarmupDuration)) {
        _state = PointingEngineState.unstable;
      }
    } else if (_state == PointingEngineState.ready) {
      _filteredTrueHeading = _adaptiveCircularFilter(
        previous: _filteredTrueHeading!,
        current: trueHeading,
      );
      _filteredCameraElevation = _adaptiveLinearFilter(
        previous: _filteredCameraElevation!,
        current: cameraElevationDegrees,
      );
    }

    final filteredHeading = _filteredTrueHeading ?? trueHeading;
    final filteredElevation =
        _filteredCameraElevation ?? cameraElevationDegrees;
    final horizontalDelta = signedAngle(targetAzimuthDegrees - filteredHeading);
    final verticalDelta = targetElevationDegrees - filteredElevation;

    if (_state == PointingEngineState.ready) {
      if (_centered) {
        _centered = horizontalDelta.abs() <= 3 && verticalDelta.abs() <= 1.5;
      } else {
        _centered = horizontalDelta.abs() <= 2 && verticalDelta.abs() <= 1;
      }
    } else {
      _centered = false;
    }

    final samplesProgress = (_warmupHeadings.length / minimumWarmupSamples)
        .clamp(0, 1)
        .toDouble();
    final durationProgress =
        minimumStableDuration == Duration.zero || _warmupTimestamps.isEmpty
        ? 1.0
        : (sampleTime.difference(_warmupTimestamps.first).inMilliseconds /
                  minimumStableDuration.inMilliseconds)
              .clamp(0, 1)
              .toDouble();
    return PointingEngineReading(
      state: _state,
      warmupProgress: math.min(samplesProgress, durationProgress).toDouble(),
      magneticHeadingDegrees: magnetic,
      trueHeadingDegrees: filteredHeading,
      horizontalDeltaDegrees: horizontalDelta,
      cameraElevationDegrees: filteredElevation,
      verticalDeltaDegrees: verticalDelta,
      centered: _centered,
    );
  }

  static double normalize(double degrees) => (degrees % 360 + 360) % 360;

  static double signedAngle(double degrees) => (degrees + 540) % 360 - 180;

  static double _circularMean(List<double> values) {
    var x = 0.0;
    var y = 0.0;
    for (final value in values) {
      final radians = value * math.pi / 180;
      x += math.cos(radians);
      y += math.sin(radians);
    }
    return normalize(math.atan2(y, x) * 180 / math.pi);
  }

  static double _circularSpread(List<double> values) {
    final mean = _circularMean(values);
    return values
        .map((value) => signedAngle(value - mean).abs())
        .fold<double>(0, (maximum, value) => value > maximum ? value : maximum);
  }

  static double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  static double _adaptiveCircularFilter({
    required double previous,
    required double current,
  }) {
    final delta = signedAngle(current - previous);
    if (delta.abs() < 0.25) return previous;
    return normalize(previous + delta * _alpha(delta.abs()));
  }

  static double _adaptiveLinearFilter({
    required double previous,
    required double current,
  }) {
    final delta = current - previous;
    if (delta.abs() < 0.15) return previous;
    return previous + delta * _alpha(delta.abs());
  }

  static double _alpha(double absoluteDelta) {
    if (absoluteDelta >= 45) return 0.75;
    if (absoluteDelta >= 20) return 0.55;
    if (absoluteDelta >= 8) return 0.38;
    if (absoluteDelta >= 3) return 0.24;
    return 0.14;
  }
}
