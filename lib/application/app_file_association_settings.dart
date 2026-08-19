import 'package:flutter/services.dart';

final class AppFileAssociationSettings {
  const AppFileAssociationSettings._();

  static const MethodChannel _channel = MethodChannel(
    'io.github.fraidotube.gpspointer/app_settings',
  );

  static Future<bool> openAndroidAppSettings() async =>
      await _channel.invokeMethod<bool>('openAppSettings') ?? false;
}
