import 'package:share_plus/share_plus.dart';

import '../core/domain/geo_point.dart';

abstract final class LocationShareService {
  static Future<void> share({
    required String label,
    required GeoPoint point,
  }) async {
    final lat = point.latitude.toStringAsFixed(7);
    final lon = point.longitude.toStringAsFixed(7);
    final maps = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    await SharePlus.instance.share(
      ShareParams(
        title: 'GPS Pointer - $label',
        subject: label,
        text: '$label\n$lat, $lon\n$maps',
      ),
    );
  }
}
