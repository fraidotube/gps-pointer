final class DeviceLocationReading {
  const DeviceLocationReading({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.horizontalAccuracyMeters,
    required this.verticalAccuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double horizontalAccuracyMeters;
  final double verticalAccuracyMeters;
}

abstract interface class DeviceLocationService {
  Future<DeviceLocationReading> readCurrentPosition();
}

final class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message);

  final String message;
}
