import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  group('AntennaTiltCalculator', () {
    test('vertical portrait mounting represents zero antenna tilt', () {
      final pose = AntennaTiltCalculator.fromGravity(x: 0, y: 9.81, z: 0);
      expect(pose.tiltDegrees, closeTo(0, 0.001));
      expect(pose.rollDegrees, closeTo(0, 0.001));
      expect(pose.mountingValid, isTrue);
    });

    test('top edge leaning backward represents positive antenna tilt', () {
      const degrees = 10.0;
      final radians = degrees * math.pi / 180;
      final pose = AntennaTiltCalculator.fromGravity(
        x: 0,
        y: 9.81 * math.cos(radians),
        z: -9.81 * math.sin(radians),
      );
      expect(pose.tiltDegrees, closeTo(degrees, 0.001));
      expect(pose.mountingValid, isTrue);
    });

    test('landscape mounting fails closed', () {
      final pose = AntennaTiltCalculator.fromGravity(x: 9.81, y: 0, z: 0);
      expect(pose.mountingValid, isFalse);
    });
  });

  test('tilt engine requires stable time and samples before ready', () {
    final engine = AntennaTiltEngine(
      targetTiltDegrees: 8,
      minimumWarmupSamples: 3,
      minimumStableDuration: const Duration(seconds: 1),
    );
    final start = DateTime.utc(2026, 8, 14);
    const pose = AntennaTiltPose(
      tiltDegrees: 8,
      rollDegrees: 0,
      mountingValid: true,
    );
    expect(
      engine.update(pose: pose, timestamp: start).state,
      AntennaTiltState.warmingUp,
    );
    engine.update(
      pose: pose,
      timestamp: start.add(const Duration(milliseconds: 500)),
    );
    final ready = engine.update(
      pose: pose,
      timestamp: start.add(const Duration(seconds: 1)),
    );
    expect(ready.state, AntennaTiltState.ready);
    expect(ready.centered, isTrue);
  });

  test('invalid mounting resets stabilization', () {
    final engine = AntennaTiltEngine(
      targetTiltDegrees: 0,
      minimumWarmupSamples: 1,
      minimumStableDuration: Duration.zero,
    );
    final ready = engine.update(
      pose: const AntennaTiltPose(
        tiltDegrees: 0,
        rollDegrees: 0,
        mountingValid: true,
      ),
    );
    expect(ready.state, AntennaTiltState.ready);
    final invalid = engine.update(
      pose: const AntennaTiltPose(
        tiltDegrees: 0,
        rollDegrees: 90,
        mountingValid: false,
      ),
    );
    expect(invalid.mountingValid, isFalse);
    expect(invalid.state, AntennaTiltState.warmingUp);
  });
}
