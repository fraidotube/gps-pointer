import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/core.dart';

final class OpenMeteoElevationProvider implements TerrainElevationProvider {
  OpenMeteoElevationProvider(this._client);

  final http.Client _client;

  @override
  Future<double> getTerrainElevationMeters(GeoPoint position) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/elevation', {
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
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
    if (values.length != 1 || values.single is! num) {
      throw const FormatException('Quota Open-Meteo assente.');
    }
    return (values.single as num).toDouble();
  }
}
