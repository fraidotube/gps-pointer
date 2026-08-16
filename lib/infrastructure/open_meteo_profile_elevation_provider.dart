import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/domain/geo_point.dart';
import '../core/elevation/terrain_profile_elevation_provider.dart';

final class OpenMeteoProfileElevationProvider
    implements TerrainProfileElevationProvider {
  OpenMeteoProfileElevationProvider(this._client);

  final http.Client _client;

  @override
  Future<List<double>> getElevations(List<GeoPoint> coordinates) async {
    if (coordinates.isEmpty) return const [];
    final result = <double>[];
    for (var offset = 0; offset < coordinates.length; offset += 100) {
      final end = (offset + 100).clamp(0, coordinates.length).toInt();
      final batch = coordinates.sublist(offset, end);
      final uri = Uri.https('api.open-meteo.com', '/v1/elevation', {
        'latitude': batch
            .map((point) => point.latitude.toStringAsFixed(7))
            .join(','),
        'longitude': batch
            .map((point) => point.longitude.toStringAsFixed(7))
            .join(','),
      });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Open-Meteo HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['elevation'] is! List) {
        throw const FormatException('Risposta Open-Meteo non valida.');
      }
      final values = decoded['elevation'] as List<dynamic>;
      if (values.length != batch.length) {
        throw const FormatException('Risposta Open-Meteo incompleta.');
      }
      for (final value in values) {
        if (value is! num || !value.toDouble().isFinite) {
          throw const FormatException('Quota Open-Meteo non valida.');
        }
        result.add(value.toDouble());
      }
    }
    return result;
  }
}
