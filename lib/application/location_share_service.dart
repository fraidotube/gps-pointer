import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static Future<bool> openDrivingDirections({required GeoPoint point}) async {
    final lat = point.latitude.toStringAsFixed(7);
    final lon = point.longitude.toStringAsFixed(7);

    // Su Android Google Maps riconosce questo URI e apre la destinazione
    // direttamente in modalità navigazione stradale.
    final navigationUri = Uri.parse('google.navigation:q=$lat,$lon&mode=d');
    if (await launchUrl(navigationUri, mode: LaunchMode.externalApplication)) {
      return true;
    }

    // Fallback: qualunque browser/app compatibile con Google Maps URL.
    final webDirectionsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon'
      '&travelmode=driving',
    );
    return launchUrl(webDirectionsUri, mode: LaunchMode.externalApplication);
  }
}
