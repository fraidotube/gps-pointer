import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'app_auth.dart';

enum ComidaSource { openStreetMap, gpsPointer }

enum ComidaBadge { gold, silver, bronze, sconsigliato }

extension ComidaBadgeUi on ComidaBadge {
  String get apiValue => name;
  String get label => switch (this) {
    ComidaBadge.gold => 'GOLD',
    ComidaBadge.silver => 'SILVER',
    ComidaBadge.bronze => 'BRONZE',
    ComidaBadge.sconsigliato => 'SCONSIGLIATO',
  };
  String get assetPath => switch (this) {
    ComidaBadge.gold => 'asset/comida_gold.png',
    ComidaBadge.silver => 'asset/comida_silver.png',
    ComidaBadge.bronze => 'asset/comida_bronze.png',
    ComidaBadge.sconsigliato => 'asset/comida_sconsigliato.png',
  };
}

ComidaBadge comidaBadgeFromText(String? value) =>
    switch ((value ?? '').trim().toLowerCase()) {
      'gold' => ComidaBadge.gold,
      'silver' => ComidaBadge.silver,
      'sconsigliato' => ComidaBadge.sconsigliato,
      _ => ComidaBadge.bronze,
    };

final class ComidaPlace {
  const ComidaPlace({
    required this.id,
    required this.source,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.serverId,
    this.sourceRef,
    this.badge,
    this.cuisine,
    this.address,
    this.phone,
    this.website,
    this.openingHours,
    this.priceRange,
    this.review,
  });

  final String id;
  final ComidaSource source;
  final int? serverId;
  final String? sourceRef;
  final ComidaBadge? badge;
  final String name;
  final String category;
  final String? cuisine;
  final String? address;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? priceRange;
  final String? review;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  bool get isGpsPointer => source == ComidaSource.gpsPointer;
}

final class ComidaSearchResult {
  const ComidaSearchResult({required this.places, required this.warnings});
  final List<ComidaPlace> places;
  final List<String> warnings;
}

final class ComidaGeocodeResult {
  const ComidaGeocodeResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
  final String displayName;
  final double latitude;
  final double longitude;
}

final class ComidaResolvedPosition {
  const ComidaResolvedPosition({
    required this.latitude,
    required this.longitude,
  });
  final double latitude;
  final double longitude;
}

final class ComidaDraft {
  const ComidaDraft({
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.badge,
    this.sourceRef,
    this.cuisine,
    this.address,
    this.phone,
    this.website,
    this.openingHours,
    this.priceEuro,
    this.review,
  });

  final String name;
  final String category;
  final String? sourceRef;
  final String? cuisine;
  final String? address;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? priceEuro;
  final String? review;
  final ComidaBadge badge;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'category': category.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'badge': badge.apiValue,
    if (sourceRef != null && sourceRef!.trim().isNotEmpty)
      'source_ref': sourceRef!.trim(),
    if (cuisine != null && cuisine!.trim().isNotEmpty)
      'cuisine': cuisine!.trim(),
    if (address != null && address!.trim().isNotEmpty)
      'address': address!.trim(),
    if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
    if (website != null && website!.trim().isNotEmpty)
      'website': website!.trim(),
    if (openingHours != null && openingHours!.trim().isNotEmpty)
      'opening_hours': openingHours!.trim(),
    if (priceEuro != null && priceEuro!.trim().isNotEmpty)
      'price_range': priceEuro!.trim(),
    if (review != null && review!.trim().isNotEmpty) 'review': review!.trim(),
  };
}

final class ComidaService {
  ComidaService(
    this._client, {
    required this.serverBaseUri,
    required this.authController,
  });

  static const String userAgent =
      'GPSPointer/2.4 https://github.com/fraidotube/gps-pointer';
  static final List<Uri> _overpassUris = [
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.private.coffee/api/interpreter'),
    Uri.parse('https://maps.mail.ru/osm/tools/overpass/api/interpreter'),
  ];
  static const Duration _osmCacheDuration = Duration(minutes: 10);
  static const Duration _osmFailureCooldown = Duration(seconds: 30);
  static final Map<String, _OsmCacheEntry> _osmCache = {};
  static DateTime? _osmFailureUntil;

  final http.Client _client;
  final Uri serverBaseUri;
  final AppAuthController authController;

  Future<ComidaSearchResult> nearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    final warnings = <String>[];
    final all = <ComidaPlace>[];

    try {
      all.addAll(
        await _fromGpsPointerServer(
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
          allDistances: false,
        ),
      );
    } catch (error) {
      warnings.add('Server GPS Pointer non disponibile: $error');
    }

    try {
      all.addAll(
        await _fromOpenStreetMap(
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
        ),
      );
    } catch (error) {
      warnings.add('OpenStreetMap non disponibile: $error');
    }

    final deduped = _deduplicate(all);
    deduped.sort((a, b) {
      if (a.isGpsPointer != b.isGpsPointer) return a.isGpsPointer ? -1 : 1;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });
    return ComidaSearchResult(places: deduped, warnings: warnings);
  }

  Future<List<ComidaPlace>> recommended({
    required double latitude,
    required double longitude,
  }) async {
    final places = await _fromGpsPointerServer(
      latitude: latitude,
      longitude: longitude,
      radiusKm: 10,
      allDistances: true,
    );
    places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return places;
  }

  Future<ComidaPlace> createOrPromote({
    required ComidaDraft draft,
    required double originLatitude,
    required double originLongitude,
  }) async {
    final response = await _authorizedJson(
      method: 'POST',
      uri: serverBaseUri.resolve('/api/v1/comida/restaurants'),
      body: draft.toJson(),
    );
    return _serverPlace(
      response,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );
  }

  Future<ComidaPlace> update({
    required int serverId,
    required ComidaDraft draft,
    required double originLatitude,
    required double originLongitude,
  }) async {
    final response = await _authorizedJson(
      method: 'PATCH',
      uri: serverBaseUri.resolve('/api/v1/comida/restaurants/$serverId'),
      body: draft.toJson(),
    );
    return _serverPlace(
      response,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );
  }

  Future<List<ComidaGeocodeResult>> geocode(String query) async {
    final text = query.trim();
    if (text.length < 3) {
      throw const FormatException('Inserisci almeno 3 caratteri.');
    }
    final uri = serverBaseUri
        .resolve('/api/v1/comida/geocode')
        .replace(queryParameters: {'q': text});
    final body = await _authorizedJson(method: 'GET', uri: uri);
    final raw = body['results'];
    if (raw is! List) {
      throw const FormatException('Risultati non validi.');
    }
    final results = <ComidaGeocodeResult>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final lat = _number(item['latitude']);
      final lon = _number(item['longitude']);
      if (lat == null || lon == null) continue;
      results.add(
        ComidaGeocodeResult(
          displayName: _text(item['display_name']) ?? 'Risultato',
          latitude: lat,
          longitude: lon,
        ),
      );
    }
    return results;
  }

  Future<ComidaResolvedPosition> resolveMapsLink(String link) async {
    final body = await _authorizedJson(
      method: 'POST',
      uri: serverBaseUri.resolve('/api/v1/comida/resolve-map-link'),
      body: {'link': link.trim()},
    );
    final latitude = _number(body['latitude']);
    final longitude = _number(body['longitude']);
    if (latitude == null || longitude == null) {
      throw const FormatException('Coordinate non trovate nel link.');
    }
    return ComidaResolvedPosition(latitude: latitude, longitude: longitude);
  }

  Future<Map<String, dynamic>> _authorizedJson({
    required String method,
    required Uri uri,
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> send(String token) {
      final headers = {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      };
      final encoded = body == null ? null : jsonEncode(body);
      return switch (method) {
        'POST' =>
          _client
              .post(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 15)),
        'PATCH' =>
          _client
              .patch(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 15)),
        _ =>
          _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15)),
      };
    }

    var token = authController.accessToken;
    if (token == null || token.isEmpty) {
      final refreshed = await authController.refreshAccessToken();
      if (!refreshed) throw StateError('Sessione app non disponibile.');
      token = authController.accessToken;
    }
    if (token == null || token.isEmpty) {
      throw StateError('Sessione app non disponibile.');
    }

    var response = await send(token);
    if (response.statusCode == 401) {
      final refreshed = await authController.refreshAccessToken();
      final retryToken = authController.accessToken;
      if (refreshed && retryToken != null && retryToken.isNotEmpty) {
        response = await send(retryToken);
      }
    }

    final decoded = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          _text(decoded['message']) ??
          _text(decoded['detail']) ??
          _text(decoded['error']) ??
          'HTTP ${response.statusCode}';
      throw StateError(message);
    }
    return decoded;
  }

  static Map<String, dynamic> _decodeJson(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {'message': 'Risposta server non valida.'};
  }

  Future<List<ComidaPlace>> _fromOpenStreetMap({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    final cacheKey = _osmCacheKey(latitude, longitude, radiusKm);
    final now = DateTime.now();
    final cached = _osmCache[cacheKey];
    if (cached != null &&
        now.difference(cached.fetchedAt) < _osmCacheDuration) {
      return cached.places
          .map(
            (place) => _withDistance(
              place,
              originLatitude: latitude,
              originLongitude: longitude,
            ),
          )
          .toList(growable: false);
    }

    final failureUntil = _osmFailureUntil;
    if (failureUntil != null && now.isBefore(failureUntil)) {
      throw StateError(
        'Overpass temporaneamente occupato; riprova tra pochi secondi.',
      );
    }

    final radiusMeters = (radiusKm * 1000).round().clamp(250, 100000);
    final lat = latitude.toStringAsFixed(6);
    final lon = longitude.toStringAsFixed(6);
    final query =
        '''
[out:json][timeout:12];
(
  node["amenity"~"^(restaurant|fast_food|cafe|pub|bar|food_court|ice_cream)\$"](around:$radiusMeters,$lat,$lon);
  way["amenity"~"^(restaurant|fast_food|cafe|pub|bar|food_court|ice_cream)\$"](around:$radiusMeters,$lat,$lon);
  relation["amenity"~"^(restaurant|fast_food|cafe|pub|bar|food_court|ice_cream)\$"](around:$radiusMeters,$lat,$lon);
);
out center tags;
''';

    Object? lastError;
    for (final endpoint in _overpassUris) {
      try {
        final response = await _client
            .post(
              endpoint,
              headers: const {
                'User-Agent': userAgent,
                'Accept': 'application/json',
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          lastError = StateError(
            '${endpoint.host} HTTP ${response.statusCode}',
          );
          continue;
        }
        final places = _parseOverpassPlaces(
          response.body,
          originLatitude: latitude,
          originLongitude: longitude,
        );
        _osmCache[cacheKey] = _OsmCacheEntry(
          fetchedAt: DateTime.now(),
          places: places,
        );
        _osmFailureUntil = null;
        return places;
      } catch (error) {
        lastError = error;
      }
    }

    _osmFailureUntil = DateTime.now().add(_osmFailureCooldown);
    throw StateError(
      'tutte le istanze Overpass non disponibili${lastError == null ? '' : ': $lastError'}',
    );
  }

  List<ComidaPlace> _parseOverpassPlaces(
    String body, {
    required double originLatitude,
    required double originLongitude,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('risposta Overpass non valida');
    }
    final elements = decoded['elements'];
    if (elements is! List) return const [];

    final places = <ComidaPlace>[];
    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) continue;
      final tagsRaw = raw['tags'];
      if (tagsRaw is! Map<String, dynamic>) continue;
      final tags = tagsRaw;
      final name = _text(tags['name']);
      if (name == null || name.isEmpty) continue;

      final centerRaw = raw['center'];
      final center = centerRaw is Map<String, dynamic>
          ? centerRaw
          : const <String, dynamic>{};
      final itemLat = _number(raw['lat']) ?? _number(center['lat']);
      final itemLon = _number(raw['lon']) ?? _number(center['lon']);
      if (itemLat == null || itemLon == null) continue;

      final amenity = _text(tags['amenity']) ?? 'restaurant';
      places.add(
        ComidaPlace(
          id: 'osm:${raw['type']}:${raw['id']}',
          source: ComidaSource.openStreetMap,
          sourceRef: 'osm:${raw['type']}:${raw['id']}',
          name: name,
          category: _categoryLabel(amenity),
          cuisine: _cleanCuisine(_text(tags['cuisine'])),
          address: _osmAddress(tags),
          phone: _text(tags['contact:phone']) ?? _text(tags['phone']),
          website: _text(tags['contact:website']) ?? _text(tags['website']),
          openingHours: _text(tags['opening_hours']),
          priceRange: _text(tags['price_range']),
          latitude: itemLat,
          longitude: itemLon,
          distanceMeters: distanceMeters(
            originLatitude,
            originLongitude,
            itemLat,
            itemLon,
          ),
        ),
      );
    }
    return places;
  }

  Future<List<ComidaPlace>> _fromGpsPointerServer({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required bool allDistances,
  }) async {
    final query = <String, String>{
      'lat': latitude.toStringAsFixed(6),
      'lon': longitude.toStringAsFixed(6),
      'radius_km': radiusKm.toStringAsFixed(1),
      if (allDistances) 'all_distances': 'true',
    };
    final uri = serverBaseUri
        .resolve('/api/v1/comida/restaurants')
        .replace(queryParameters: query);

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
      throw StateError('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> rows;
    if (decoded is Map<String, dynamic> && decoded['restaurants'] is List) {
      rows = decoded['restaurants'] as List<dynamic>;
    } else if (decoded is List) {
      rows = decoded;
    } else {
      throw const FormatException('elenco ristoranti non valido');
    }

    final result = <ComidaPlace>[];
    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        result.add(
          _serverPlace(
            raw,
            originLatitude: latitude,
            originLongitude: longitude,
          ),
        );
      } catch (_) {}
    }
    return result;
  }

  ComidaPlace _serverPlace(
    Map<String, dynamic> raw, {
    required double originLatitude,
    required double originLongitude,
  }) {
    final latitude = _number(raw['latitude']) ?? _number(raw['lat']);
    final longitude = _number(raw['longitude']) ?? _number(raw['lon']);
    final name = _text(raw['name']);
    final serverId = _integer(raw['id']);
    if (latitude == null ||
        longitude == null ||
        name == null ||
        name.isEmpty ||
        serverId == null) {
      throw const FormatException('record server incompleto');
    }

    return ComidaPlace(
      id: 'server:$serverId',
      source: ComidaSource.gpsPointer,
      serverId: serverId,
      sourceRef: _text(raw['source_ref']),
      badge: comidaBadgeFromText(_text(raw['badge'])),
      name: name,
      category: _text(raw['category']) ?? 'Ristorante',
      cuisine: _text(raw['cuisine']),
      address: _text(raw['address']),
      phone: _text(raw['phone']),
      website: _text(raw['website']),
      openingHours: _text(raw['opening_hours']),
      priceRange: _text(raw['price_range']),
      review: _text(raw['review']),
      latitude: latitude,
      longitude: longitude,
      distanceMeters:
          _number(raw['distance_m']) ??
          distanceMeters(originLatitude, originLongitude, latitude, longitude),
    );
  }

  static ComidaPlace _withDistance(
    ComidaPlace place, {
    required double originLatitude,
    required double originLongitude,
  }) => ComidaPlace(
    id: place.id,
    source: place.source,
    serverId: place.serverId,
    sourceRef: place.sourceRef,
    badge: place.badge,
    name: place.name,
    category: place.category,
    cuisine: place.cuisine,
    address: place.address,
    phone: place.phone,
    website: place.website,
    openingHours: place.openingHours,
    priceRange: place.priceRange,
    review: place.review,
    latitude: place.latitude,
    longitude: place.longitude,
    distanceMeters: distanceMeters(
      originLatitude,
      originLongitude,
      place.latitude,
      place.longitude,
    ),
  );

  static List<ComidaPlace> _deduplicate(List<ComidaPlace> input) {
    final result = <ComidaPlace>[];
    for (final candidate in input) {
      final normalized = _normalize(candidate.name);
      final duplicateIndex = result.indexWhere(
        (existing) =>
            _normalize(existing.name) == normalized &&
            distanceMeters(
                  existing.latitude,
                  existing.longitude,
                  candidate.latitude,
                  candidate.longitude,
                ) <
                80,
      );
      if (duplicateIndex < 0) {
        result.add(candidate);
      } else if (candidate.isGpsPointer) {
        result[duplicateIndex] = candidate;
      }
    }
    return result;
  }

  static String _osmCacheKey(
    double latitude,
    double longitude,
    double radiusKm,
  ) =>
      '${latitude.toStringAsFixed(3)}:${longitude.toStringAsFixed(3)}:${radiusKm.toStringAsFixed(1)}';

  static String _categoryLabel(String value) => switch (value) {
    'restaurant' => 'Ristorante',
    'fast_food' => 'Fast food',
    'cafe' => 'Bar / caffè',
    'pub' => 'Pub',
    'bar' => 'Bar',
    'food_court' => 'Food court',
    'ice_cream' => 'Gelateria',
    _ => value,
  };

  static String? _cleanCuisine(String? value) {
    if (value == null) return null;
    return value
        .split(';')
        .map((item) => item.trim().replaceAll('_', ' '))
        .where((item) => item.isNotEmpty)
        .join(', ');
  }

  static String? _osmAddress(Map<String, dynamic> tags) {
    final full = _text(tags['addr:full']);
    if (full != null) return full;
    final street = _text(tags['addr:street']);
    final number = _text(tags['addr:housenumber']);
    final postcode = _text(tags['addr:postcode']);
    final city = _text(tags['addr:city']);
    final first = [?street, ?number].join(' ');
    final second = [?postcode, ?city].join(' ');
    final address = [
      if (first.isNotEmpty) first,
      if (second.isNotEmpty) second,
    ].join(', ');
    return address.isEmpty ? null : address;
  }

  static int? _integer(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _text(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), '').trim();

  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

final class _OsmCacheEntry {
  const _OsmCacheEntry({required this.fetchedAt, required this.places});
  final DateTime fetchedAt;
  final List<ComidaPlace> places;
}
