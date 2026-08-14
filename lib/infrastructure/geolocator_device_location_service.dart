import 'package:geolocator/geolocator.dart';

import '../application/device_location_service.dart';

final class GeolocatorDeviceLocationService implements DeviceLocationService {
  @override
  Future<DeviceLocationReading> readCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(
        'Attiva la posizione del telefono e riprova.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException('Permesso di posizione negato.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        'Permesso di posizione bloccato. Abilitalo nelle impostazioni Android.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 30),
        useMSLAltitude: true,
      ),
    );
    return DeviceLocationReading(
      latitude: position.latitude,
      longitude: position.longitude,
      altitudeMeters: position.altitude,
      horizontalAccuracyMeters: position.accuracy,
      verticalAccuracyMeters: position.altitudeAccuracy,
    );
  }
}
