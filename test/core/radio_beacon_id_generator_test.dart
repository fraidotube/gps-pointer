import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/core/core.dart';

void main() {
  test('generates a readable identifier from the beacon name', () {
    expect(
      RadioBeaconIdGenerator.generate(
        name: 'Croce di Pale',
        existingIds: const [],
      ),
      'CROCE-DI-PALE',
    );
  });

  test('removes accents and resolves collisions case-insensitively', () {
    expect(
      RadioBeaconIdGenerator.generate(
        name: 'Monte Caffè',
        existingIds: const ['monte-caffe', 'MONTE-CAFFE-2'],
      ),
      'MONTE-CAFFE-3',
    );
  });

  test('uses a safe fallback for a name without ASCII letters or numbers', () {
    expect(
      RadioBeaconIdGenerator.generate(name: '---', existingIds: const []),
      'RADIOFARO',
    );
  });
}
