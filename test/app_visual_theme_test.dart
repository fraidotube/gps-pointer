import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/application/app_visual_theme.dart';

void main() {
  test('visual theme defaults to classic and persists Radar Pro', () async {
    final directory = await Directory.systemTemp.createTemp('gpsp-theme-test-');
    addTearDown(() => directory.delete(recursive: true));

    final bridge = _FakeLauncherIconBridge();
    final file = File('${directory.path}/theme.txt');
    final controller = AppVisualThemeController(
      storageFile: file,
      launcherIconBridge: bridge,
    );

    await controller.initialize();
    expect(controller.theme, AppVisualTheme.classic);

    await controller.setTheme(AppVisualTheme.radarPro);
    expect(controller.theme, AppVisualTheme.radarPro);
    expect(await file.readAsString(), 'radarPro');
    expect(bridge.lastTheme, AppVisualTheme.radarPro);

    final reloaded = AppVisualThemeController(
      storageFile: file,
      launcherIconBridge: bridge,
    );
    await reloaded.initialize();
    expect(reloaded.theme, AppVisualTheme.radarPro);
  });

  test('unknown persisted theme safely falls back to classic', () async {
    final directory = await Directory.systemTemp.createTemp('gpsp-theme-test-');
    addTearDown(() => directory.delete(recursive: true));

    final file = File('${directory.path}/theme.txt');
    await file.writeAsString('future-theme');

    final controller = AppVisualThemeController(
      storageFile: file,
      launcherIconBridge: _FakeLauncherIconBridge(),
    );
    await controller.initialize();

    expect(controller.theme, AppVisualTheme.classic);
  });
}

final class _FakeLauncherIconBridge implements LauncherIconBridge {
  AppVisualTheme? lastTheme;

  @override
  Future<void> apply(AppVisualTheme theme) async {
    lastTheme = theme;
  }
}
