import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'catalogue UX keeps header and controls inside the scrolling surface',
    () {
      final source = File(
        'lib/presentation/gps_pointer_app.dart',
      ).readAsStringSync();

      expect(source, contains("CustomScrollView("));
      expect(
        source,
        contains("key: const PageStorageKey<String>('catalogue-scroll')"),
      );
      expect(source, contains("SliverToBoxAdapter("));
      expect(source, contains("_beaconListSliver(catalogue)"));
      expect(
        source,
        isNot(contains("Expanded(child: _beaconList(catalogue))")),
      );
    },
  );

  test('location acquired notice auto-hides almost immediately', () {
    final source = File(
      'lib/presentation/gps_pointer_app.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("'Posizione per distanze e ordinamento acquisita.'"),
    );
    expect(source, contains("Duration(milliseconds: 450)"));
  });

  test('native launcher aliases are not reintroduced', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, isNot(contains('LauncherClassic')));
    expect(manifest, isNot(contains('LauncherRadar')));
  });
}
