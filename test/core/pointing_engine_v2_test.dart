import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  test('warm-up uses a circular mean across north', () {
    final engine = PointingEngineV2(
      targetAzimuthDegrees: 0,
      targetElevationDegrees: 0,
      declinationDegrees: 0,
      minimumWarmupSamples: 4,
      maximumWarmupSamples: 8,
      minimumStableDuration: Duration.zero,
    );
    PointingEngineReading? reading;
    for (final heading in <double>[359, 1, 358, 2]) {
      reading = engine.update(
        magneticHeadingDegrees: heading,
        cameraElevationDegrees: 0,
      );
    }
    final result = reading!;
    expect(result.state, PointingEngineState.ready);
    expect(
      PointingEngineV2.signedAngle(result.trueHeadingDegrees),
      closeTo(0, 0.1),
    );
  });

  test('applies magnetic declination before computing target delta', () {
    final engine = PointingEngineV2(
      targetAzimuthDegrees: 103,
      targetElevationDegrees: 0,
      declinationDegrees: 3,
      minimumWarmupSamples: 1,
      minimumStableDuration: Duration.zero,
    );
    final reading = engine.update(
      magneticHeadingDegrees: 100,
      cameraElevationDegrees: 0,
    );
    expect(reading.trueHeadingDegrees, closeTo(103, 0.001));
    expect(reading.horizontalDeltaDegrees, closeTo(0, 0.001));
    expect(reading.centered, isTrue);
  });

  test('adaptive filter reacts quickly to a large rotation', () {
    final engine = PointingEngineV2(
      targetAzimuthDegrees: 90,
      targetElevationDegrees: 0,
      declinationDegrees: 0,
      minimumWarmupSamples: 1,
      minimumStableDuration: Duration.zero,
    );
    engine.update(magneticHeadingDegrees: 0, cameraElevationDegrees: 0);
    final reading = engine.update(
      magneticHeadingDegrees: 60,
      cameraElevationDegrees: 0,
    );
    expect(reading.trueHeadingDegrees, closeTo(45, 0.001));
  });

  test('rejects an unstable warm-up instead of showing a false target', () {
    final engine = PointingEngineV2(
      targetAzimuthDegrees: 0,
      targetElevationDegrees: 0,
      declinationDegrees: 0,
      minimumWarmupSamples: 3,
      maximumWarmupSamples: 4,
      maximumWarmupSpreadDegrees: 5,
      minimumStableDuration: Duration.zero,
    );
    PointingEngineReading? reading;
    for (final heading in <double>[0, 40, 80, 120]) {
      reading = engine.update(
        magneticHeadingDegrees: heading,
        cameraElevationDegrees: 0,
      );
    }
    final result = reading!;
    expect(result.state, PointingEngineState.unstable);
    expect(result.centered, isFalse);
  });

  test('forgets an initial bad sample after the phone becomes stable', () {
    final engine = PointingEngineV2(
      targetAzimuthDegrees: 45,
      targetElevationDegrees: 0,
      declinationDegrees: 0,
      minimumWarmupSamples: 3,
      maximumWarmupSamples: 8,
      maximumWarmupSpreadDegrees: 3,
      minimumStableDuration: Duration.zero,
    );
    PointingEngineReading? reading;
    for (final heading in <double>[180, 44, 45, 46]) {
      reading = engine.update(
        magneticHeadingDegrees: heading,
        cameraElevationDegrees: 0,
      );
    }
    final result = reading!;
    expect(result.state, PointingEngineState.ready);
    expect(result.horizontalDeltaDegrees, closeTo(0, 0.1));
  });

  test('requires a stable interval instead of accepting fast events', () {
    final engine = PointingEngineV2(
      targetAzimuthDegrees: 45,
      targetElevationDegrees: 0,
      declinationDegrees: 0,
      minimumWarmupSamples: 2,
      minimumStableDuration: const Duration(seconds: 2),
    );
    final start = DateTime.utc(2026, 8, 14, 20);
    engine.update(
      magneticHeadingDegrees: 45,
      cameraElevationDegrees: 0,
      timestamp: start,
    );
    final tooEarly = engine.update(
      magneticHeadingDegrees: 45.5,
      cameraElevationDegrees: 0,
      timestamp: start.add(const Duration(seconds: 1)),
    );
    expect(tooEarly.state, PointingEngineState.warmingUp);

    final ready = engine.update(
      magneticHeadingDegrees: 44.5,
      cameraElevationDegrees: 0,
      timestamp: start.add(const Duration(seconds: 2)),
    );
    expect(ready.state, PointingEngineState.ready);
  });
}
