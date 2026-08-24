import 'dart:io';

import 'package:flutter/services.dart';

enum ApkInstallLaunchResult { started, permissionRequired }

final class AndroidApkInstaller {
  const AndroidApkInstaller();

  static const MethodChannel _channel = MethodChannel(
    'io.github.fraidotube.gpspointer/apk_installer',
  );

  Future<ApkInstallLaunchResult> install(File apkFile) async {
    final result = await _channel.invokeMethod<String>(
      'installApk',
      <String, Object?>{'path': apkFile.path},
    );
    switch (result) {
      case 'started':
        return ApkInstallLaunchResult.started;
      case 'permission_required':
        return ApkInstallLaunchResult.permissionRequired;
      default:
        throw StateError('Risposta installer Android non valida: $result');
    }
  }
}
