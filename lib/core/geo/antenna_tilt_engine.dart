import 'dart:math' as math;

final class AntennaTiltPose {
  const AntennaTiltPose({
    required this.tiltDegrees,
    required this.rollDegrees,
    required this.mountingValid,
  });

  final double tiltDegrees;
  final double rollDegrees;
  final bool mountingValid;
}

abstract final class AntennaTiltCalculator {
  static AntennaTiltPose fromGravity({
    required double x,
    required double y,
    required double z,
    double maximumRollDegrees = 12,
  }) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) {
      throw const FormatException('Accelerometer values must be finite.');
    }
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (magnitude < 0.1) {
      return const AntennaTiltPose(
        tiltDegrees: 0,
        rollDegrees: 90,
        mountingValid: false,
      );
    }
    final verticalPlaneMagnitude = math.sqrt(x * x + y * y);
    final tilt = -math.atan2(z, verticalPlaneMagnitude) * 180 / math.pi;
    final roll = math.atan2(x, y) * 180 / math.pi;
    return AntennaTiltPose(
      tiltDegrees: tilt,
      rollDegrees: roll,
      mountingValid: y > 0 && roll.abs() <= maximumRollDegrees,
    );
  }
}

enum AntennaTiltState { warmingUp, ready, unstable }

final class AntennaTiltReading {
  const AntennaTiltReading({
    required this.state,
    required this.warmupProgress,
    required this.mountingValid,
    required this.measuredTiltDegrees,
    required this.deltaDegrees,
    required this.centered,
  });

  final AntennaTiltState state;
  final double warmupProgress;
  final bool mountingValid;
  final double measuredTiltDegrees;
  final double deltaDegrees;
  final bool centered;
}

final class AntennaTiltEngine {
  AntennaTiltEngine({
    required this.targetTiltDegrees,
    this.minimumWarmupSamples = 24,
    this.minimumStableDuration = const Duration(milliseconds: 1500),
    this.maximumWarmupDuration = const Duration(seconds: 12),
    this.maximumWarmupSpreadDegrees = 0.8,
  });

  final double targetTiltDegrees;
  final int minimumWarmupSamples;
  final Duration minimumStableDuration;
  final Duration maximumWarmupDuration;
  final double maximumWarmupSpreadDegrees;

  final List<double> _samples = <double>[];
  final List<DateTime> _timestamps = <DateTime>[];
  AntennaTiltState _state = AntennaTiltState.warmingUp;
  DateTime? _startedAt;
  double? _filteredTilt;
  bool _centered = false;

  void reset() {
    _samples.clear();
    _timestamps.clear();
    _state = AntennaTiltState.warmingUp;
    _startedAt = null;
    _filteredTilt = null;
    _centered = false;
  }

  AntennaTiltReading update({
    required AntennaTiltPose pose,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    if (!pose.mountingValid) {
      reset();
      return _reading(
        measured: pose.tiltDegrees,
        mountingValid: false,
        progress: 0,
      );
    }

    if (_state == AntennaTiltState.warmingUp) {
      _startedAt ??= now;
      _samples.add(pose.tiltDegrees);
      _timestamps.add(now);
      while (_samples.length > 1 &&
          _spread(_samples) > maximumWarmupSpreadDegrees) {
        _samples.removeAt(0);
        _timestamps.removeAt(0);
      }
      if (_samples.length >= minimumWarmupSamples &&
          now.difference(_timestamps.first) >= minimumStableDuration) {
        _filteredTilt = _average(_samples);
        _state = AntennaTiltState.ready;
      } else if (now.difference(_startedAt!) >= maximumWarmupDuration) {
        _state = AntennaTiltState.unstable;
      }
    } else if (_state == AntennaTiltState.ready) {
      final previous = _filteredTilt!;
      final delta = pose.tiltDegrees - previous;
      if (delta.abs() >= 0.08) {
        final alpha = delta.abs() >= 8
            ? 0.65
            : delta.abs() >= 3
            ? 0.4
            : 0.2;
        _filteredTilt = previous + delta * alpha;
      }
    }

    final measured = _filteredTilt ?? pose.tiltDegrees;
    final delta = targetTiltDegrees - measured;
    if (_state == AntennaTiltState.ready) {
      _centered = _centered ? delta.abs() <= 1 : delta.abs() <= 0.5;
    } else {
      _centered = false;
    }
    return _reading(
      measured: measured,
      mountingValid: true,
      progress: _progress(now),
    );
  }

  AntennaTiltReading _reading({
    required double measured,
    required bool mountingValid,
    required double progress,
  }) => AntennaTiltReading(
    state: _state,
    warmupProgress: progress,
    mountingValid: mountingValid,
    measuredTiltDegrees: measured,
    deltaDegrees: targetTiltDegrees - measured,
    centered: mountingValid && _centered,
  );

  double _progress(DateTime now) {
    if (_state == AntennaTiltState.ready) return 1;
    if (_samples.isEmpty) return 0;
    final samples = (_samples.length / minimumWarmupSamples).clamp(0, 1);
    final duration = minimumStableDuration == Duration.zero
        ? 1.0
        : (now.difference(_timestamps.first).inMilliseconds /
                  minimumStableDuration.inMilliseconds)
              .clamp(0, 1);
    return math.min(samples, duration).toDouble();
  }

  static double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  static double _spread(List<double> values) {
    final mean = _average(values);
    return values
        .map((value) => (value - mean).abs())
        .fold<double>(0, (maximum, value) => value > maximum ? value : maximum);
  }
}
