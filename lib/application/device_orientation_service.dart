import 'device_location_service.dart';

final class DeviceOrientationInfo {
  const DeviceOrientationInfo({
    required this.hasMagnetometer,
    required this.declinationDegrees,
  });

  final bool hasMagnetometer;
  final double declinationDegrees;
}

abstract interface class DeviceOrientationService {
  Future<DeviceOrientationInfo> readInfo(DeviceLocationReading location);
}

final class DeviceOrientationException implements Exception {
  const DeviceOrientationException(this.message);

  final String message;
}
