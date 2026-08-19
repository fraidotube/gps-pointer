import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../application/device_location_service.dart';
import '../application/simulation_export_service.dart';
import '../application/server_upload_services.dart';
import '../application/location_share_service.dart';
import '../core/domain/geo_point.dart';
import '../core/elevation/terrain_profile_elevation_provider.dart';
import '../core/geo/geo_calculator.dart';
import '../core/geo/radio_profile_engine.dart';
import '../core/simulation/radio_link_simulation.dart';
import '../core/simulation/radio_link_simulation_repository.dart';

enum _PointMode { currentPosition, coordinates, mapsLink }

final class PtpScreen extends StatefulWidget {
  const PtpScreen({
    required this.locationService,
    required this.profileElevationProvider,
    required this.simulationRepository,
    required this.exportService,
    required this.deviceId,
    required this.deviceName,
    required this.serverUploadService,
    super.key,
  });

  final DeviceLocationService locationService;
  final TerrainProfileElevationProvider profileElevationProvider;
  final RadioLinkSimulationRepository simulationRepository;
  final SimulationExportService exportService;
  final String deviceId;
  final String deviceName;
  final GpsPointerServerUploadService serverUploadService;

  @override
  State<PtpScreen> createState() => _PtpScreenState();
}

final class _PtpScreenState extends State<PtpScreen> {
  final _aLat = TextEditingController();
  final _aLon = TextEditingController();
  final _aLink = TextEditingController();
  final _aHeight = TextEditingController(text: '0');

  final _bLat = TextEditingController();
  final _bLon = TextEditingController();
  final _bLink = TextEditingController();
  final _bHeight = TextEditingController(text: '0');

  final _frequency = TextEditingController(text: '5.8');
  final _name = TextEditingController();

  _PointMode _modeA = _PointMode.currentPosition;
  _PointMode _modeB = _PointMode.coordinates;

  DeviceLocationReading? _currentLocation;
  bool _loadingLocation = false;
  bool _busy = false;
  bool _saved = false;
  String? _resultSimulationId;
  DateTime? _resultCreatedAtUtc;
  String? _error;

  GeoPoint? _pointA;
  GeoPoint? _pointB;
  RadioProfileResult? _profile;
  double? _azimuthAtoB;
  double? _azimuthBtoA;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocation());
  }

  @override
  void dispose() {
    for (final controller in [
      _aLat,
      _aLon,
      _aLink,
      _aHeight,
      _bLat,
      _bLon,
      _bLink,
      _bHeight,
      _frequency,
      _name,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loadingLocation = true;
      _error = null;
    });
    try {
      final reading = await widget.locationService.readCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentLocation = reading;
        _loadingLocation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _error = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Punto Punto • PTP')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _pointCard(
              context,
              title: '1. Punto A',
              mode: _modeA,
              onModeChanged: (mode) => setState(() {
                _modeA = mode;
                _clearResult();
              }),
              lat: _aLat,
              lon: _aLon,
              link: _aLink,
              height: _aHeight,
            ),
            const SizedBox(height: 12),
            _pointCard(
              context,
              title: '2. Punto B',
              mode: _modeB,
              onModeChanged: (mode) => setState(() {
                _modeB = mode;
                _clearResult();
              }),
              lat: _bLat,
              lon: _bLon,
              link: _bLink,
              height: _bHeight,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '3. Parametri collegamento',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _frequency,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Frequenza (GHz)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.waves),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _calculate,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('CALCOLA PUNTO-PUNTO'),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Acquisizione quote e calcolo profilo...'),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_profile != null &&
                _pointA != null &&
                _pointB != null &&
                _azimuthAtoB != null &&
                _azimuthBtoA != null) ...[
              const SizedBox(height: 12),
              _ResultCard(
                profile: _profile!,
                azimuthAtoB: _azimuthAtoB!,
                azimuthBtoA: _azimuthBtoA!,
              ),
              const SizedBox(height: 12),
              _section(
                context,
                'Profilo altimetrico',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 300,
                      child: CustomPaint(
                        painter: _PtpProfilePainter(_profile!),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _Legend(label: 'Terreno', color: Color(0xFFFF765F)),
                        _Legend(
                          label: 'Linea ottica',
                          color: Color(0xFF4DDCF0),
                        ),
                        _Legend(
                          label: 'Prima Fresnel',
                          color: Color(0xFF65DF87),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                context,
                'Mappa collegamento',
                SizedBox(
                  height: 320,
                  child: _PtpMap(a: _pointA!, b: _pointB!, detailPointA: false),
                ),
              ),
              const SizedBox(height: 12),
              _section(
                context,
                'Dettaglio Punto A',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Vista ibrida ravvicinata con direttrice verso il Punto B.',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 330,
                      child: _PtpMap(
                        a: _pointA!,
                        b: _pointB!,
                        detailPointA: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => LocationShareService.share(
                          label: 'Location A - PTP',
                          point: _pointA!,
                        ),
                        icon: const Icon(Icons.share_location_outlined),
                        label: const Text('CONDIVIDI POSIZIONE A'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                context,
                'Dettaglio Punto B',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Vista ibrida ravvicinata con direttrice verso il Punto A.',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 330,
                      child: _PtpMap(
                        a: _pointB!,
                        b: _pointA!,
                        detailPointA: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => LocationShareService.share(
                          label: 'Location B - PTP',
                          point: _pointB!,
                        ),
                        icon: const Icon(Icons.share_location_outlined),
                        label: const Text('CONDIVIDI POSIZIONE B'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                context,
                'Salva e condividi',
                Column(
                  children: [
                    TextField(
                      controller: _name,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nome simulazione',
                        hintText: 'Es. Sede A - Sede B',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_saved ? 'SALVATA' : 'SALVA'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _share,
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('CONDIVIDI'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _uploadSimulation,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('INVIA AL SERVER'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pointCard(
    BuildContext context, {
    required String title,
    required _PointMode mode,
    required ValueChanged<_PointMode> onModeChanged,
    required TextEditingController lat,
    required TextEditingController lon,
    required TextEditingController link,
    required TextEditingController height,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: mode == _PointMode.currentPosition,
                  avatar: const Icon(Icons.my_location, size: 18),
                  label: const Text('Posizione attuale'),
                  onSelected: _busy
                      ? null
                      : (_) => onModeChanged(_PointMode.currentPosition),
                ),
                ChoiceChip(
                  selected: mode == _PointMode.coordinates,
                  avatar: const Icon(Icons.pin_drop_outlined, size: 18),
                  label: const Text('Coordinate'),
                  onSelected: _busy
                      ? null
                      : (_) => onModeChanged(_PointMode.coordinates),
                ),
                ChoiceChip(
                  selected: mode == _PointMode.mapsLink,
                  avatar: const Icon(Icons.link, size: 18),
                  label: const Text('Link Maps'),
                  onSelected: _busy
                      ? null
                      : (_) => onModeChanged(_PointMode.mapsLink),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (mode == _PointMode.currentPosition)
              _CurrentPositionPanel(
                reading: _currentLocation,
                loading: _loadingLocation,
                onRefresh: _loadLocation,
              ),
            if (mode == _PointMode.coordinates)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: lat,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitudine',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lon,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitudine',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            if (mode == _PointMode.mapsLink)
              TextField(
                controller: link,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Link Google Maps / WhatsApp',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: height,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Altezza antenna da terra (m)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.height),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  void _clearResult() {
    _pointA = null;
    _pointB = null;
    _profile = null;
    _azimuthAtoB = null;
    _azimuthBtoA = null;
    _saved = false;
    _resultSimulationId = null;
    _resultCreatedAtUtc = null;
  }

  Future<void> _calculate() async {
    setState(() {
      _busy = true;
      _error = null;
      _saved = false;
    });
    try {
      final a = await _resolvePoint(
        mode: _modeA,
        lat: _aLat,
        lon: _aLon,
        link: _aLink,
      );
      final b = await _resolvePoint(
        mode: _modeB,
        lat: _bLat,
        lon: _bLon,
        link: _bLink,
      );
      if (a.latitude == b.latitude && a.longitude == b.longitude) {
        throw const FormatException('Punto A e Punto B coincidono.');
      }

      final heightA = _parseHeight(_aHeight.text, 'Punto A');
      final heightB = _parseHeight(_bHeight.text, 'Punto B');
      final frequency = _parseFrequency();

      final distance = RadioProfileEngine.haversineDistanceMeters(a, b);
      final count = RadioProfileEngine.sampleCountForDistance(distance);
      final coordinates = RadioProfileEngine.geodesicCoordinates(a, b, count);
      final elevations = await widget.profileElevationProvider.getElevations(
        coordinates,
      );
      final profile = RadioProfileEngine.build(
        distanceMeters: distance,
        elevationsMeters: elevations,
        installerAntennaHeightMeters: heightA,
        targetAntennaHeightMeters: heightB,
        frequencyGhz: frequency,
      );

      final ab = GeoCalculator.initialBearingDegrees(a, b);
      final ba = GeoCalculator.initialBearingDegrees(b, a);

      if (!mounted) return;
      final created = DateTime.now().toUtc();
      setState(() {
        _pointA = a;
        _pointB = b;
        _profile = profile;
        _azimuthAtoB = ab;
        _azimuthBtoA = ba;
        _resultSimulationId = '${created.microsecondsSinceEpoch}';
        _resultCreatedAtUtc = created;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<GeoPoint> _resolvePoint({
    required _PointMode mode,
    required TextEditingController lat,
    required TextEditingController lon,
    required TextEditingController link,
  }) async {
    switch (mode) {
      case _PointMode.currentPosition:
        final reading =
            _currentLocation ??
            await widget.locationService.readCurrentPosition();
        if (mounted) setState(() => _currentLocation = reading);
        return GeoPoint.validated(
          latitude: reading.latitude,
          longitude: reading.longitude,
        );
      case _PointMode.coordinates:
        return _parseCoordinates(lat.text.trim(), lon.text.trim());
      case _PointMode.mapsLink:
        return _parseMapsLink(link.text.trim());
    }
  }

  GeoPoint _parseCoordinates(String latText, String lonText) {
    final lat = double.tryParse(latText.replaceAll(',', '.'));
    final lon = double.tryParse(lonText.replaceAll(',', '.'));
    if (lat == null || lon == null) {
      throw const FormatException('Coordinate non valide.');
    }
    return GeoPoint.validated(latitude: lat, longitude: lon);
  }

  GeoPoint _parseMapsLink(String raw) {
    if (raw.isEmpty) {
      throw const FormatException('Incolla un link Google Maps.');
    }
    String decoded;
    try {
      decoded = Uri.decodeFull(raw);
    } catch (_) {
      decoded = raw;
    }

    final uri = Uri.tryParse(raw);
    final q = uri?.queryParameters['q'] ?? uri?.queryParameters['query'];
    if (q != null) {
      final point = _firstCoordinatePair(q);
      if (point != null) return point;
    }

    final at = RegExp(
      r'@(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(decoded);
    if (at != null) {
      return _parseCoordinates(at.group(1)!, at.group(2)!);
    }

    final point = _firstCoordinatePair(decoded);
    if (point != null) return point;

    throw const FormatException(
      'Il link non contiene coordinate leggibili. Usa coordinate manuali '
      'oppure un link Maps che le contenga.',
    );
  }

  GeoPoint? _firstCoordinatePair(String value) {
    final match = RegExp(
      r'(-?\d{1,2}(?:\.\d+)?)\s*[, ]\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(value);
    if (match == null) return null;
    try {
      return _parseCoordinates(match.group(1)!, match.group(2)!);
    } on FormatException {
      return null;
    }
  }

  double _parseHeight(String raw, String pointName) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0 || value > 1000) {
      throw FormatException(
        'Altezza antenna $pointName non valida (0-1000 m).',
      );
    }
    return value;
  }

  double? _parseFrequency() {
    final raw = _frequency.text.trim();
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0.001 || value > 300) {
      throw const FormatException('Frequenza non valida.');
    }
    return value;
  }

  RadioLinkSimulation _buildSimulation({required bool requireName}) {
    final a = _pointA;
    final b = _pointB;
    final profile = _profile;
    final azimuth = _azimuthAtoB;
    if (a == null || b == null || profile == null || azimuth == null) {
      throw const FormatException('Calcola prima il collegamento PTP.');
    }
    var name = _name.text.trim();
    if (name.isEmpty && !requireName) {
      name =
          'PTP ${DateTime.now().toLocal().toIso8601String().substring(0, 16)}';
    }
    if (name.isEmpty || name.length > 120) {
      throw const FormatException(
        'Inserisci un nome simulazione da 1 a 120 caratteri.',
      );
    }
    final now = _resultCreatedAtUtc ?? DateTime.now().toUtc();
    final resultId = _resultSimulationId ?? '${now.microsecondsSinceEpoch}';
    return RadioLinkSimulation(
      id: resultId,
      name: name,
      kind: RadioLinkSimulationKind.ptp,
      beaconId: 'PTP-$resultId',
      beaconName: 'Punto B',
      startPosition: a,
      startGroundElevationMeters: profile.installerGroundElevationMeters,
      buildingHeightMeters: profile.installerAntennaHeightMeters,
      targetPosition: b,
      targetGroundElevationMeters: profile.targetGroundElevationMeters,
      targetPoleHeightMeters: profile.targetAntennaHeightMeters,
      frequencyGhz: profile.frequencyGhz,
      azimuthDegrees: azimuth,
      profile: profile,
      createdAtUtc: now,
    );
  }

  Future<void> _save() async {
    try {
      final simulation = _buildSimulation(requireName: true);
      await widget.simulationRepository.save(simulation);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _error = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Simulazione PTP salvata.')));
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _share() async {
    try {
      final simulation = _buildSimulation(requireName: false);
      await widget.exportService.export(
        simulation: simulation,
        deviceId: widget.deviceId,
        deviceName: widget.deviceName,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _uploadSimulation() async {
    try {
      setState(() {
        _busy = true;
        _error = null;
      });
      final simulation = _buildSimulation(requireName: false);
      await widget.serverUploadService.uploadSimulation(simulation);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PTP inviato al server.')));
    } on ServerUploadException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is DeviceLocationException) return error.message;
    if (error is FormatException) return error.message;
    return 'Operazione non riuscita: $error';
  }
}

final class _CurrentPositionPanel extends StatelessWidget {
  const _CurrentPositionPanel({
    required this.reading,
    required this.loading,
    required this.onRefresh,
  });

  final DeviceLocationReading? reading;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Acquisizione posizione...'),
        ],
      );
    }
    if (reading == null) {
      return OutlinedButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.my_location),
        label: const Text('Acquisisci posizione'),
      );
    }
    return Row(
      children: [
        const Icon(Icons.gps_fixed),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${reading!.latitude.toStringAsFixed(7)}, '
            '${reading!.longitude.toStringAsFixed(7)}  '
            '±${reading!.horizontalAccuracyMeters.toStringAsFixed(0)} m',
          ),
        ),
        IconButton(
          tooltip: 'Aggiorna posizione',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

final class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.profile,
    required this.azimuthAtoB,
    required this.azimuthBtoA,
  });

  final RadioProfileResult profile;
  final double azimuthAtoB;
  final double azimuthBtoA;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Distanza', '${profile.distanceKm.toStringAsFixed(2)} km'),
      MapEntry('Azimut A → B', '${azimuthAtoB.toStringAsFixed(2)}°'),
      MapEntry('Azimut B → A', '${azimuthBtoA.toStringAsFixed(2)}°'),
      MapEntry(
        'Tilt A → B',
        '${profile.tiltDegrees >= 0 ? '+' : ''}${profile.tiltDegrees.toStringAsFixed(2)}°',
      ),
      MapEntry(
        'Quota terreno A',
        '${profile.installerGroundElevationMeters.toStringAsFixed(0)} m',
      ),
      MapEntry(
        'Quota terreno B',
        '${profile.targetGroundElevationMeters.toStringAsFixed(0)} m',
      ),
      MapEntry('LOS', profile.lineOfSightClear ? 'Libera' : 'Ostruita'),
      if (profile.firstFresnelClear != null)
        MapEntry(
          'Prima Fresnel',
          profile.firstFresnelClear! ? 'Libera' : 'Ostruita',
        ),
      MapEntry(
        'Margine LOS minimo',
        '${profile.minimumLosClearanceMeters >= 0 ? '+' : ''}'
            '${profile.minimumLosClearanceMeters.toStringAsFixed(1)} m',
      ),
      if (profile.minimumFresnelClearanceMeters != null)
        MapEntry(
          'Margine Fresnel minimo',
          '${profile.minimumFresnelClearanceMeters! >= 0 ? '+' : ''}'
              '${profile.minimumFresnelClearanceMeters!.toStringAsFixed(1)} m',
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Risultato Punto-Punto',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(row.key)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
}

final class _PtpMap extends StatefulWidget {
  const _PtpMap({required this.a, required this.b, required this.detailPointA});

  final GeoPoint a;
  final GeoPoint b;
  final bool detailPointA;

  @override
  State<_PtpMap> createState() => _PtpMapState();
}

final class _PtpMapState extends State<_PtpMap> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = LatLng(widget.a.latitude, widget.a.longitude);
    final b = LatLng(widget.b.latitude, widget.b.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GoogleMap(
        mapType: widget.detailPointA ? MapType.hybrid : MapType.normal,
        initialCameraPosition: CameraPosition(
          target: widget.detailPointA
              ? a
              : LatLng(
                  (a.latitude + b.latitude) / 2,
                  (a.longitude + b.longitude) / 2,
                ),
          zoom: widget.detailPointA ? 19 : 11,
        ),
        zoomControlsEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        markers: {
          Marker(
            markerId: const MarkerId('a'),
            position: a,
            infoWindow: const InfoWindow(title: 'Punto A'),
          ),
          Marker(
            markerId: const MarkerId('b'),
            position: b,
            infoWindow: const InfoWindow(title: 'Punto B'),
          ),
        },
        polylines: {
          Polyline(
            polylineId: const PolylineId('ptp'),
            points: [a, b],
            width: 4,
          ),
        },
        onMapCreated: (controller) {
          _controller = controller;
          if (!widget.detailPointA) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final bounds = LatLngBounds(
                southwest: LatLng(
                  math.min(a.latitude, b.latitude),
                  math.min(a.longitude, b.longitude),
                ),
                northeast: LatLng(
                  math.max(a.latitude, b.latitude),
                  math.max(a.longitude, b.longitude),
                ),
              );
              unawaited(
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(bounds, 48),
                ),
              );
            });
          }
        },
      ),
    );
  }
}

final class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 22, height: 3, color: color),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

final class _PtpProfilePainter extends CustomPainter {
  _PtpProfilePainter(this.profile);

  final RadioProfileResult profile;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.points.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }
    const padding = 12.0;
    final usableWidth = math.max(1.0, size.width - padding * 2);
    final usableHeight = math.max(1.0, size.height - padding * 2);

    final values = <double>[];
    for (final point in profile.points) {
      values.add(point.adjustedTerrainMeters);
      values.add(point.lineOfSightMeters);
      if (point.fresnelLowerMeters != null) {
        values.add(point.fresnelLowerMeters!);
      }
    }

    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    if ((maxY - minY).abs() < 1) {
      minY -= 1;
      maxY += 1;
    }
    final range = maxY - minY;
    minY -= range * .08;
    maxY += range * .08;

    Offset offset(RadioProfilePoint point, double y) {
      final x = padding + (point.distanceKm / profile.distanceKm) * usableWidth;
      final normalized = (y - minY) / (maxY - minY);
      return Offset(x, padding + usableHeight * (1 - normalized));
    }

    final terrain = Path();
    final los = Path();
    final fresnel = Path();

    for (var i = 0; i < profile.points.length; i++) {
      final point = profile.points[i];
      final t = offset(point, point.adjustedTerrainMeters);
      final l = offset(point, point.lineOfSightMeters);
      final f = point.fresnelLowerMeters == null
          ? null
          : offset(point, point.fresnelLowerMeters!);
      if (i == 0) {
        terrain.moveTo(t.dx, t.dy);
        los.moveTo(l.dx, l.dy);
        if (f != null) fresnel.moveTo(f.dx, f.dy);
      } else {
        terrain.lineTo(t.dx, t.dy);
        los.lineTo(l.dx, l.dy);
        if (f != null) fresnel.lineTo(f.dx, f.dy);
      }
    }

    canvas.drawPath(
      terrain,
      Paint()
        ..color = const Color(0xFFFF765F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawPath(
      los,
      Paint()
        ..color = const Color(0xFF4DDCF0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    if (profile.frequencyGhz != null) {
      canvas.drawPath(
        fresnel,
        Paint()
          ..color = const Color(0xFF65DF87)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PtpProfilePainter oldDelegate) =>
      oldDelegate.profile != profile;
}
