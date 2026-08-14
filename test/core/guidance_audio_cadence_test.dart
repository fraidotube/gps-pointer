import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  test('beep cadence accelerates while approaching the target', () {
    final far = GuidanceAudioCadence.intervalFor(40);
    final medium = GuidanceAudioCadence.intervalFor(10);
    final near = GuidanceAudioCadence.intervalFor(2);

    expect(far, greaterThan(medium));
    expect(medium, greaterThan(near));
  });

  test('invalid angular errors are rejected', () {
    expect(() => GuidanceAudioCadence.intervalFor(-1), throwsArgumentError);
  });
}
