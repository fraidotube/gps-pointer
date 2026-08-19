import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/domain/geo_point.dart';

final class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureCelsius,
    required this.apparentTemperatureCelsius,
    required this.relativeHumidityPercent,
    required this.weatherCode,
    required this.cloudCoverPercent,
    required this.windSpeedKmh,
    required this.windGustKmh,
    required this.precipitationMm,
    required this.fetchedAt,
  });

  final double temperatureCelsius;
  final double? apparentTemperatureCelsius;
  final double relativeHumidityPercent;
  final int weatherCode;
  final double cloudCoverPercent;
  final double windSpeedKmh;
  final double windGustKmh;
  final double precipitationMm;
  final DateTime fetchedAt;

  String get description => WeatherCodeText.describe(weatherCode);
}

abstract interface class WeatherService {
  Future<WeatherSnapshot> current(GeoPoint point);
}

class MetNoWeatherService implements WeatherService {
  MetNoWeatherService(
    this._client, {
    this.cacheDuration = const Duration(minutes: 10),
  });

  static const String userAgent =
      'GPSPointer/2.3 https://github.com/fraidotube/gps-pointer';

  final http.Client _client;
  final Duration cacheDuration;
  final Map<String, _WeatherCacheEntry> _cache = {};

  @override
  Future<WeatherSnapshot> current(GeoPoint point) async {
    final key = _cacheKey(point);
    final cached = _cache[key];
    final now = DateTime.now();
    if (cached != null &&
        now.difference(cached.snapshot.fetchedAt) < cacheDuration) {
      return cached.snapshot;
    }

    final uri =
        Uri.https('api.met.no', '/weatherapi/locationforecast/2.0/compact', {
          'lat': point.latitude.toStringAsFixed(4),
          'lon': point.longitude.toStringAsFixed(4),
        });

    final response = await _client
        .get(
          uri,
          headers: const {
            'User-Agent': userAgent,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw WeatherServiceException(
        'Meteo non disponibile (MET Norway HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const WeatherServiceException('Risposta meteo non valida.');
    }
    final properties = decoded['properties'];
    if (properties is! Map<String, dynamic>) {
      throw const WeatherServiceException('Dati MET Norway mancanti.');
    }
    final timeseries = properties['timeseries'];
    if (timeseries is! List || timeseries.isEmpty) {
      throw const WeatherServiceException('Serie meteo non disponibile.');
    }

    final first = timeseries.first;
    if (first is! Map<String, dynamic>) {
      throw const WeatherServiceException('Primo dato meteo non valido.');
    }
    final data = first['data'];
    if (data is! Map<String, dynamic>) {
      throw const WeatherServiceException('Dettagli meteo mancanti.');
    }
    final instant = data['instant'];
    if (instant is! Map<String, dynamic>) {
      throw const WeatherServiceException('Dati meteo istantanei mancanti.');
    }
    final details = instant['details'];
    if (details is! Map<String, dynamic>) {
      throw const WeatherServiceException('Dettagli istantanei mancanti.');
    }

    final next1h = data['next_1_hours'];
    final next1hMap = next1h is Map<String, dynamic> ? next1h : null;
    final next1hDetails = next1hMap?['details'];
    final next1hDetailsMap = next1hDetails is Map<String, dynamic>
        ? next1hDetails
        : null;
    final summary = next1hMap?['summary'];
    final summaryMap = summary is Map<String, dynamic> ? summary : null;
    final symbol = summaryMap?['symbol_code'];

    final windMs = _number(details, 'wind_speed');
    final gustMs = _optionalNumber(details, 'wind_speed_of_gust') ?? windMs;

    final snapshot = WeatherSnapshot(
      temperatureCelsius: _number(details, 'air_temperature'),
      apparentTemperatureCelsius: null,
      relativeHumidityPercent:
          _optionalNumber(details, 'relative_humidity') ?? 0,
      weatherCode: WeatherCodeText.fromMetSymbol(
        symbol is String ? symbol : 'cloudy',
      ),
      cloudCoverPercent: _optionalNumber(details, 'cloud_area_fraction') ?? 0,
      windSpeedKmh: windMs * 3.6,
      windGustKmh: gustMs * 3.6,
      precipitationMm:
          _optionalNumber(next1hDetailsMap, 'precipitation_amount') ?? 0,
      fetchedAt: now,
    );
    _cache[key] = _WeatherCacheEntry(snapshot);
    return snapshot;
  }

  static String _cacheKey(GeoPoint point) =>
      '${point.latitude.toStringAsFixed(3)}:${point.longitude.toStringAsFixed(3)}';

  static double _number(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is num) return value.toDouble();
    throw WeatherServiceException('Dato meteo mancante: $key.');
  }

  static double? _optionalNumber(Map<String, dynamic>? source, String key) {
    if (source == null) return null;
    final value = source[key];
    return value is num ? value.toDouble() : null;
  }
}

/// Compatibilità con la baseline esistente: il nome storico resta valido,
/// ma da +54 il provider meteo reale è MET Norway, non Open-Meteo.
final class OpenMeteoWeatherService extends MetNoWeatherService {
  OpenMeteoWeatherService(super.client, {super.cacheDuration});
}

final class WeatherServiceException implements Exception {
  const WeatherServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class WeatherCodeText {
  const WeatherCodeText._();

  static String describe(int code) {
    if (code == 0) return 'Sereno';
    if (code == 1) return 'Prevalentemente sereno';
    if (code == 2) return 'Parzialmente nuvoloso';
    if (code == 3) return 'Coperto';
    if (code == 45 || code == 48) return 'Nebbia';
    if (code == 51 || code == 53 || code == 55) return 'Pioviggine';
    if (code == 56 || code == 57) return 'Pioviggine gelata';
    if (code == 61 || code == 63 || code == 65) return 'Pioggia';
    if (code == 66 || code == 67) return 'Pioggia gelata';
    if (code == 71 || code == 73 || code == 75 || code == 77) return 'Neve';
    if (code == 80 || code == 81 || code == 82) return 'Rovesci';
    if (code == 85 || code == 86) return 'Rovesci di neve';
    if (code == 95) return 'Temporale';
    if (code == 96 || code == 99) return 'Temporale con grandine';
    return 'Meteo variabile';
  }

  static int fromMetSymbol(String symbolCode) {
    final code = symbolCode.toLowerCase();
    if (code.contains('thunder')) return 95;
    if (code.contains('snow')) return 71;
    if (code.contains('sleet')) return 66;
    if (code.contains('rainshowers') || code.contains('showers')) return 80;
    if (code.contains('heavyrain')) return 65;
    if (code.contains('lightrain')) return 61;
    if (code.contains('rain')) return 63;
    if (code.contains('fog')) return 45;
    if (code.contains('partlycloudy')) return 2;
    if (code.contains('fair')) return 1;
    if (code.contains('cloudy')) return 3;
    if (code.contains('clearsky')) return 0;
    return 3;
  }
}

final class _WeatherCacheEntry {
  const _WeatherCacheEntry(this.snapshot);

  final WeatherSnapshot snapshot;
}
