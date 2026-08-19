import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../application/device_location_service.dart';
import '../application/weather_service.dart';
import '../core/domain/geo_point.dart';

final class WeatherRadarScreen extends StatefulWidget {
  const WeatherRadarScreen({
    required this.locationService,
    this.initialPoint,
    this.initialLabel,
    super.key,
  });

  final DeviceLocationService locationService;
  final GeoPoint? initialPoint;
  final String? initialLabel;

  @override
  State<WeatherRadarScreen> createState() => _WeatherRadarScreenState();
}

final class _WeatherRadarScreenState extends State<WeatherRadarScreen> {
  static final Uri _rainViewerHome = Uri.parse('https://www.rainviewer.com/');

  final http.Client _client = http.Client();

  GoogleMapController? _mapController;
  GeoPoint? _point;
  String _pointLabel = 'Posizione corrente';
  _RainViewerTimeline? _timeline;
  int _frameIndex = 0;
  int _forecastHours = 12;
  List<_ForecastHour> _forecast = const [];
  bool _loading = true;
  bool _forecastLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final point = widget.initialPoint ?? await _readCurrentPoint();
      final label = widget.initialPoint == null
          ? 'Posizione corrente'
          : (widget.initialLabel?.trim().isNotEmpty == true
                ? widget.initialLabel!.trim()
                : 'Punto selezionato');
      final timeline = await _loadTimeline();
      if (!mounted) return;
      setState(() {
        _point = point;
        _pointLabel = label;
        _timeline = timeline;
        _frameIndex = timeline.frames.isEmpty ? 0 : timeline.frames.length - 1;
        _loading = false;
        _error = null;
      });
      await _loadForecast();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Radar meteo non disponibile: $error';
      });
    }
  }

  Future<GeoPoint> _readCurrentPoint() async {
    final reading = await widget.locationService.readCurrentPosition();
    return GeoPoint.validated(
      latitude: reading.latitude,
      longitude: reading.longitude,
    );
  }

  Future<_RainViewerTimeline> _loadTimeline() async {
    final response = await _client
        .get(Uri.parse('https://api.rainviewer.com/public/weather-maps.json'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('RainViewer HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('metadata RainViewer non validi');
    }
    final host = decoded['host'];
    final radar = decoded['radar'];
    if (host is! String || radar is! Map<String, dynamic>) {
      throw const FormatException('timeline RainViewer incompleta');
    }
    final past = radar['past'];
    if (past is! List) {
      throw const FormatException('frame radar RainViewer mancanti');
    }
    final frames = <_RainViewerFrame>[];
    for (final item in past) {
      if (item is! Map<String, dynamic>) continue;
      final time = item['time'];
      final path = item['path'];
      if (time is num && path is String) {
        frames.add(_RainViewerFrame(time.round(), path));
      }
    }
    frames.sort((a, b) => a.unixTime.compareTo(b.unixTime));
    if (frames.isEmpty) {
      throw const FormatException('nessun frame radar disponibile');
    }
    return _RainViewerTimeline(host: host, frames: frames);
  }

  Future<void> _useCurrentPosition() async {
    setState(() => _loading = true);
    try {
      final point = await _readCurrentPoint();
      if (!mounted) return;
      setState(() {
        _point = point;
        _pointLabel = 'Posizione corrente';
        _loading = false;
        _error = null;
      });
      await _centerMap(point);
      await _loadForecast();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Posizione non disponibile: $error';
      });
    }
  }

  Future<void> _selectPoint(LatLng position) async {
    final point = GeoPoint.validated(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    setState(() {
      _point = point;
      _pointLabel = 'Punto selezionato';
    });
    await _loadForecast();
  }

  Future<void> _centerMap(GeoPoint point) async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(point.latitude, point.longitude), 7),
    );
  }

  Future<void> _loadForecast() async {
    final point = _point;
    if (point == null || _forecastLoading) return;
    setState(() => _forecastLoading = true);
    try {
      final uri =
          Uri.https('api.met.no', '/weatherapi/locationforecast/2.0/compact', {
            'lat': point.latitude.toStringAsFixed(4),
            'lon': point.longitude.toStringAsFixed(4),
          });

      final response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'GPSPointer/2.3 https://github.com/fraidotube/gps-pointer',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw StateError('MET Norway HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('previsioni MET Norway non valide');
      }
      final properties = decoded['properties'];
      if (properties is! Map<String, dynamic>) {
        throw const FormatException('properties MET Norway mancanti');
      }
      final timeseries = properties['timeseries'];
      if (timeseries is! List) {
        throw const FormatException('timeseries MET Norway mancante');
      }

      final values = <_ForecastHour>[];
      for (final raw in timeseries.take(24)) {
        if (raw is! Map<String, dynamic>) continue;
        final time = raw['time'];
        final data = raw['data'];
        if (time is! String || data is! Map<String, dynamic>) continue;

        final instant = data['instant'];
        if (instant is! Map<String, dynamic>) continue;
        final instantDetails = instant['details'];
        if (instantDetails is! Map<String, dynamic>) continue;

        final next1h = data['next_1_hours'];
        final next1hMap = next1h is Map<String, dynamic> ? next1h : null;
        final nextDetails = next1hMap?['details'];
        final nextDetailsMap = nextDetails is Map<String, dynamic>
            ? nextDetails
            : null;
        final summary = next1hMap?['summary'];
        final summaryMap = summary is Map<String, dynamic> ? summary : null;

        final temperature = instantDetails['air_temperature'];
        final windMs = instantDetails['wind_speed'];
        if (temperature is! num || windMs is! num) continue;

        final precipitation = nextDetailsMap?['precipitation_amount'];
        final probability = nextDetailsMap?['probability_of_precipitation'];
        final symbol = summaryMap?['symbol_code'];

        values.add(
          _ForecastHour(
            time: time,
            temperatureCelsius: temperature.toDouble(),
            precipitationProbability: probability is num
                ? probability.toDouble()
                : 0,
            precipitationMm: precipitation is num
                ? precipitation.toDouble()
                : 0,
            weatherCode: WeatherCodeText.fromMetSymbol(
              symbol is String ? symbol : 'cloudy',
            ),
            windSpeedKmh: windMs.toDouble() * 3.6,
          ),
        );
      }

      if (!mounted) return;
      setState(() => _forecast = values);
    } catch (_) {
      if (!mounted) return;
      setState(() => _forecast = const []);
    } finally {
      if (mounted) setState(() => _forecastLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    final timeline = _timeline;
    final frame = timeline == null || timeline.frames.isEmpty
        ? null
        : timeline.frames[_frameIndex.clamp(0, timeline.frames.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar meteo'),
        actions: [
          IconButton(
            tooltip: 'Posizione corrente',
            onPressed: _loading ? null : _useCurrentPosition,
            icon: const Icon(Icons.my_location),
          ),
          IconButton(
            tooltip: 'RainViewer',
            onPressed: () => launchUrl(
              _rainViewerHome,
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : point == null || timeline == null
          ? _RadarError(message: _error ?? 'Radar meteo non disponibile.')
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  _PointHeader(label: _pointLabel, point: point),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 390,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(point.latitude, point.longitude),
                          zoom: 7,
                        ),
                        minMaxZoomPreference: const MinMaxZoomPreference(2, 7),
                        mapType: MapType.normal,
                        compassEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                        markers: {
                          Marker(
                            markerId: const MarkerId('radar_point'),
                            position: LatLng(point.latitude, point.longitude),
                            infoWindow: InfoWindow(title: _pointLabel),
                          ),
                        },
                        tileOverlays: frame == null
                            ? const <TileOverlay>{}
                            : {
                                TileOverlay(
                                  tileOverlayId: TileOverlayId(
                                    'rainviewer-${frame.unixTime}',
                                  ),
                                  tileProvider: _RainViewerTileProvider(
                                    client: _client,
                                    host: timeline.host,
                                    path: frame.path,
                                  ),
                                  transparency: .12,
                                  zIndex: 1,
                                  fadeIn: false,
                                ),
                              },
                        onMapCreated: (controller) =>
                            _mapController = controller,
                        onTap: _selectPoint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RadarTimelineCard(
                    timeline: timeline,
                    selectedIndex: _frameIndex,
                    onChanged: (value) => setState(() => _frameIndex = value),
                  ),
                  const SizedBox(height: 12),
                  _ForecastCard(
                    hours: _forecastHours,
                    loading: _forecastLoading,
                    forecast: _forecast,
                    onHoursChanged: (hours) =>
                        setState(() => _forecastHours = hours),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ],
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => launchUrl(
                      _rainViewerHome,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text(
                      'Radar: RainViewer · Previsioni: MET Norway',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF79E2F3),
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Il radar RainViewer mostra i frame disponibili delle '
                    'ultime 2 ore. Le ore future sotto la mappa sono previsioni '
                    'Open-Meteo per il punto selezionato.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9FB6C2), fontSize: 11),
                  ),
                ],
              ),
            ),
    );
  }
}

final class _RainViewerTileProvider extends TileProvider {
  _RainViewerTileProvider({
    required this.client,
    required this.host,
    required this.path,
  });

  static final Map<String, Uint8List> _tileCache = <String, Uint8List>{};

  final http.Client client;
  final String host;
  final String path;

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null || zoom < 0 || zoom > 7) {
      return TileProvider.noTile;
    }
    try {
      final uri = Uri.parse('$host$path/256/$zoom/$x/$y/2/1_1.png');
      final key = uri.toString();
      final cached = _tileCache[key];
      if (cached != null) return Tile(256, 256, cached);

      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return TileProvider.noTile;
      }
      if (_tileCache.length >= 96) _tileCache.clear();
      _tileCache[key] = response.bodyBytes;
      return Tile(256, 256, response.bodyBytes);
    } catch (_) {
      return TileProvider.noTile;
    }
  }
}

final class _RainViewerTimeline {
  const _RainViewerTimeline({required this.host, required this.frames});

  final String host;
  final List<_RainViewerFrame> frames;
}

final class _RainViewerFrame {
  const _RainViewerFrame(this.unixTime, this.path);

  final int unixTime;
  final String path;

  DateTime get localTime => DateTime.fromMillisecondsSinceEpoch(
    unixTime * 1000,
    isUtc: true,
  ).toLocal();
}

final class _ForecastHour {
  const _ForecastHour({
    required this.time,
    required this.temperatureCelsius,
    required this.precipitationProbability,
    required this.precipitationMm,
    required this.weatherCode,
    required this.windSpeedKmh,
  });

  final String time;
  final double temperatureCelsius;
  final double precipitationProbability;
  final double precipitationMm;
  final int weatherCode;
  final double windSpeedKmh;

  String get clock {
    final separator = time.indexOf('T');
    if (separator < 0 || separator + 6 > time.length) return time;
    return time.substring(separator + 1, separator + 6);
  }
}

final class _PointHeader extends StatelessWidget {
  const _PointHeader({required this.label, required this.point});

  final String label;
  final GeoPoint point;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.radar, color: Color(0xFF79E2F3)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${point.latitude.toStringAsFixed(6)}, '
                  '${point.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: Color(0xFF9FB6C2),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

final class _RadarTimelineCard extends StatelessWidget {
  const _RadarTimelineCard({
    required this.timeline,
    required this.selectedIndex,
    required this.onChanged,
  });

  final _RainViewerTimeline timeline;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final frames = timeline.frames;
    final frame = frames[selectedIndex.clamp(0, frames.length - 1)];
    final time =
        '${frame.localTime.hour.toString().padLeft(2, '0')}:'
        '${frame.localTime.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Radar · ultime 2 ore',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(time, style: const TextStyle(color: Color(0xFF79E2F3))),
              ],
            ),
            Slider(
              value: selectedIndex.toDouble(),
              min: 0,
              max: (frames.length - 1).toDouble(),
              divisions: frames.length > 1 ? frames.length - 1 : null,
              label: time,
              onChanged: frames.length <= 1
                  ? null
                  : (value) => onChanged(value.round()),
            ),
            const Text(
              'Sposta il cursore per vedere i frame radar disponibili. '
              'Il cambio frame è manuale per ridurre traffico e richieste.',
              style: TextStyle(color: Color(0xFF9FB6C2), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.hours,
    required this.loading,
    required this.forecast,
    required this.onHoursChanged,
  });

  final int hours;
  final bool loading;
  final List<_ForecastHour> forecast;
  final ValueChanged<int> onHoursChanged;

  @override
  Widget build(BuildContext context) {
    final visible = forecast.take(hours).toList(growable: false);
    final sampled = <_ForecastHour>[
      for (var i = 0; i < visible.length; i += 3) visible[i],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Previsioni punto',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final option in const [6, 12, 24])
                  ChoiceChip(
                    label: Text('$option h'),
                    selected: hours == option,
                    onSelected: (_) => onHoursChanged(option),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (loading)
              const LinearProgressIndicator()
            else if (sampled.isEmpty)
              const Text('Previsioni non disponibili.')
            else
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sampled.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = sampled[index];
                    return Container(
                      width: 118,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x55162D3A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x332BC5E8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.clock,
                            style: const TextStyle(
                              color: Color(0xFF79E2F3),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${item.temperatureCelsius.toStringAsFixed(0)} °C · '
                            '${WeatherCodeText.describe(item.weatherCode)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const Spacer(),
                          Text(
                            'Pioggia ${item.precipitationProbability.toStringAsFixed(0)}%'
                            ' · ${item.precipitationMm.toStringAsFixed(1)} mm',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                          Text(
                            'Vento ${item.windSpeedKmh.toStringAsFixed(0)} km/h',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _RadarError extends StatelessWidget {
  const _RadarError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
