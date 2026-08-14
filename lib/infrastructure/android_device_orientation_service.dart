import 'package:flutter/services.dart';

import '../application/device_location_service.dart';
import '../application/device_orientation_service.dart';

final class AndroidDeviceOrientationService
    implements DeviceOrientationService {
  static const _channel = MethodChannel(
    'io.github.fraidotube.gpspointer/device_orientation',
  );

  @override
  Future<DeviceOrientationInfo> readInfo(DeviceLocationReading location) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readOrientationInfo',
        <String, dynamic>{
          'latitude': location.latitude,
          'longitude': location.longitude,
          'altitudeMeters': location.altitudeMeters,
          'timestampMillis': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (result == null) {
        throw const DeviceOrientationException(
          'Informazioni bussola non disponibili.',
        );
      }
      return DeviceOrientationInfo(
        hasMagnetometer: result['hasMagnetometer'] == true,
        declinationDegrees:
            (result['declinationDegrees'] as num?)?.toDouble() ?? 0,
      );
    } on PlatformException catch (error) {
      throw DeviceOrientationException(
        'Controllo bussola non riuscito: ${error.code}.',
      );
    }
  }
}
