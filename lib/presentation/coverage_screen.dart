import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../application/catalogue_controller.dart';
import '../application/device_location_service.dart';
import '../application/simulation_export_service.dart';
import '../core/domain/geo_point.dart';
import '../core/domain/radio_beacon.dart';
import '../core/elevation/terrain_profile_elevation_provider.dart';
import '../core/geo/geo_calculator.dart';
import '../core/geo/radio_profile_engine.dart';
import '../core/simulation/radio_link_simulation.dart';
import '../core/simulation/radio_link_simulation_repository.dart';

enum _StartMode { currentPosition, coordinates, mapsLink }

final class CoverageScreen extends StatefulWidget {
  const CoverageScreen({
    required this.catalogueController,
    required this.locationService,
    required this.profileElevationProvider,
    required this.simulationRepository,
    required this.exportService,
    required this.deviceId,
    required this.deviceName,
    super.key,
  });

  final CatalogueController catalogueController;
  final DeviceLocationService locationService;
  final TerrainProfileElevationProvider profileElevationProvider;
  final RadioLinkSimulationRepository simulationRepository;
  final SimulationExportService exportService;
  final String deviceId;
  final String deviceName;

  @override
  State<CoverageScreen> createState() => _CoverageScreenState();
}

final class _CoverageScreenState extends State<CoverageScreen> {
  static const double _defaultRadiusKm = 10;

  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _mapsLink = TextEditingController();
  final _buildingHeight = TextEditingController(text: '0');
  final _frequency = TextEditingController(text: '5.8');
  final _simulationName = TextEditingController();

  _StartMode _startMode = _StartMode.currentPosition;
  DeviceLocationReading? _currentLocation;
  RadioBeacon? _selectedBeacon;
  bool _showAllBeacons = false;
  bool _loadingLocation = false;
  bool _busy = false;
  bool _saved = false;
  String? _error;

  GeoPoint? _start;
  RadioProfileResult? _profile;
  double? _azimuth;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocation());
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _mapsLink.dispose();
    _buildingHeight.dispose();
    _frequency.dispose();
    _simulationName.dispose();
    super.dispose();
  }

  List<_BeaconDistance> get _orderedBeacons {
    final catalogue = widget.catalogueController.catalogue;
    if (catalogue == null) return const [];
    final location = _currentLocation;
    final origin = location == null
        ? null
        : GeoPoint.validated(
            latitude: location.latitude,
            longitude: location.longitude,
          );
    final items = catalogue.beacons
        .map(
          (beacon) => _BeaconDistance(
            beacon: beacon,
            distanceMeters: origin == null
                ? null
                : RadioProfileEngine.haversineDistanceMeters(
                    origin,
                    beacon.position,
                  ),
          ),
        )
        .toList(growable: false);
    items.sort((a, b) {
      final ad = a.distanceMeters;
      final bd = b.distanceMeters;
      if (ad != null && bd != null) return ad.compareTo(bd);
      if (ad != null) return -1;
      if (bd != null) return 1;
      return a.beacon.name.toLowerCase().compareTo(b.beacon.name.toLowerCase());
    });
    if (_showAllBeacons || origin == null) return items;
    return items
        .where(
          (item) =>
              item.distanceMeters != null &&
              item.distanceMeters! <= _defaultRadiusKm * 1000,
        )
        .toList(growable: false);
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
    final ordered = _orderedBeacons;
    return Scaffold(
      appBar: AppBar(title: const Text('Copertura')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              context,
              title: '1. Postazione Radio',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentLocation == null
                              ? 'Filtro 10 km in attesa della posizione'
                              : _showAllBeacons
                              ? 'Visualizzazione di tutte le postazioni'
                              : 'Postazioni entro 10 km dalla tua posizione',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _loadingLocation
                            ? null
                            : () => setState(
                                () => _showAllBeacons = !_showAllBeacons,
                              ),
                        icon: Icon(
                          _showAllBeacons ? Icons.filter_alt : Icons.public,
                        ),
                        label: Text(
                          _showAllBeacons ? 'Entro 10 km' : 'Visualizza tutte',
                        ),
                      ),
                    ],
                  ),
                  if (_loadingLocation) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<RadioBeacon>(
                    initialValue:
                        ordered.any(
                          (item) => item.beacon.id == _selectedBeacon?.id,
                        )
                        ? ordered
                              .firstWhere(
                                (item) => item.beacon.id == _selectedBeacon!.id,
                              )
                              .beacon
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Punto di arrivo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cell_tower),
                    ),
                    hint: Text(
                      ordered.isEmpty
                          ? 'Nessuna postazione nel filtro'
                          : 'Scegli la postazione radio',
                    ),
                    items: [
                      for (final item in ordered)
                        DropdownMenuItem(
                          value: item.beacon,
                          child: Text(
                            item.distanceMeters == null
                                ? item.beacon.name
                                : '${item.beacon.name}  •  ${(item.distanceMeters! / 1000).toStringAsFixed(1)} km',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _selectedBeacon = value;
                            _clearResult();
                          }),
                  ),
                  if (_currentLocation == null && !_loadingLocation) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loadLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Riprova posizione per filtro 10 km'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              context,
              title: '2. Punto di partenza',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        selected: _startMode == _StartMode.currentPosition,
                        avatar: const Icon(Icons.my_location, size: 18),
                        label: const Text('Posizione attuale'),
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                _startMode = _StartMode.currentPosition;
                                _clearResult();
                              }),
                      ),
                      ChoiceChip(
                        selected: _startMode == _StartMode.coordinates,
                        avatar: const Icon(Icons.pin_drop_outlined, size: 18),
                        label: const Text('Coordinate'),
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                _startMode = _StartMode.coordinates;
                                _clearResult();
                              }),
                      ),
                      ChoiceChip(
                        selected: _startMode == _StartMode.mapsLink,
                        avatar: const Icon(Icons.link, size: 18),
                        label: const Text('Link Maps'),
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                _startMode = _StartMode.mapsLink;
                                _clearResult();
                              }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_startMode == _StartMode.currentPosition)
                    _CurrentPositionPanel(
                      reading: _currentLocation,
                      loading: _loadingLocation,
                      onRefresh: _loadLocation,
                    ),
                  if (_startMode == _StartMode.coordinates)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latitude,
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
                            controller: _longitude,
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
                  if (_startMode == _StartMode.mapsLink) ...[
                    TextField(
                      controller: _mapsLink,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Link Google Maps / WhatsApp',
                        hintText:
                            'https://maps.google.com/maps?q=42.9613835%2C12.6997659...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sono accettati link che contengono le coordinate. '
                      'I link brevi che richiedono un redirect verranno gestiti '
                      'in uno step successivo.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              context,
              title: '3. Parametri collegamento',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _buildingHeight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Altezza da terra (m)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _frequency,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Frequenza (GHz)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _calculate,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('CALCOLA COPERTURA'),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Acquisizione quote e calcolo del profilo radio...',
                    ),
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
            if (_profile != null &&
                _azimuth != null &&
                _start != null &&
                _selectedBeacon != null) ...[
              const SizedBox(height: 12),
              _CoverageSummary(
                profile: _profile!,
                azimuthDegrees: _azimuth!,
                beacon: _selectedBeacon!,
              ),
              const SizedBox(height: 12),
              _section(
                context,
                title: 'Profilo altimetrico',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 300,
                      child: CustomPaint(
                        painter: _CoverageProfilePainter(_profile!),
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
                title: 'Mappa collegamento',
                child: SizedBox(
                  height: 310,
                  child: _LinkMap(
                    start: _start!,
                    target: _selectedBeacon!.position,
                    targetName: _selectedBeacon!.name,
                    detail: false,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _section(
                context,
                title: 'Dettaglio punto di partenza',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Vista ibrida ravvicinata del punto di partenza. '
                      'La direttrice indica la direzione verso la postazione radio.',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 330,
                      child: _LinkMap(
                        start: _start!,
                        target: _selectedBeacon!.position,
                        targetName: _selectedBeacon!.name,
                        detail: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                context,
                title: 'Salva e condividi',
                child: Column(
                  children: [
                    TextField(
                      controller: _simulationName,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nome simulazione',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _saveSimulation,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_saved ? 'SALVATA' : 'SALVA'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _shareSimulation,
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('CONDIVIDI'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'PDF e invio diretto al server saranno aggiunti nel '
                      'prossimo step senza cambiare il motore di calcolo.',
                      textAlign: TextAlign.center,
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

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) => Card(
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

  void _clearResult() {
    _profile = null;
    _azimuth = null;
    _start = null;
    _saved = false;
  }

  Future<void> _calculate() async {
    final beacon = _selectedBeacon;
    if (beacon == null) {
      setState(() => _error = 'Seleziona una Postazione Radio.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _saved = false;
    });
    try {
      final start = await _resolveStart();
      final buildingHeight = _parseBuildingHeight();
      final frequency = _parseFrequency();
      final distance = RadioProfileEngine.haversineDistanceMeters(
        start,
        beacon.position,
      );
      final count = RadioProfileEngine.sampleCountForDistance(distance);
      final coordinates = RadioProfileEngine.geodesicCoordinates(
        start,
        beacon.position,
        count,
      );
      final elevations = await widget.profileElevationProvider.getElevations(
        coordinates,
      );
      final profile = RadioProfileEngine.build(
        distanceMeters: distance,
        elevationsMeters: elevations,
        installerAntennaHeightMeters: buildingHeight,
        targetAntennaHeightMeters: beacon.poleHeightMeters,
        frequencyGhz: frequency,
      );
      final azimuth = GeoCalculator.initialBearingDegrees(
        start,
        beacon.position,
      );
      if (!mounted) return;
      setState(() {
        _start = start;
        _profile = profile;
        _azimuth = azimuth;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<GeoPoint> _resolveStart() async {
    switch (_startMode) {
      case _StartMode.currentPosition:
        final reading =
            _currentLocation ??
            await widget.locationService.readCurrentPosition();
        if (mounted) setState(() => _currentLocation = reading);
        return GeoPoint.validated(
          latitude: reading.latitude,
          longitude: reading.longitude,
        );
      case _StartMode.coordinates:
        return _parseCoordinates(_latitude.text.trim(), _longitude.text.trim());
      case _StartMode.mapsLink:
        return _parseMapsLink(_mapsLink.text.trim());
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

    final pair = _firstCoordinatePair(decoded);
    if (pair != null) return pair;

    throw const FormatException(
      'Il link non contiene coordinate leggibili. '
      'Apri Maps, condividi una posizione con coordinate oppure inseriscile manualmente.',
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

  double _parseBuildingHeight() {
    final value = double.tryParse(
      _buildingHeight.text.trim().replaceAll(',', '.'),
    );
    if (value == null || !value.isFinite || value < 0 || value > 1000) {
      throw const FormatException(
        'Altezza da terra non valida. Usa un valore tra 0 e 1000 m.',
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
    final profile = _profile;
    final azimuth = _azimuth;
    final start = _start;
    final beacon = _selectedBeacon;
    if (profile == null || azimuth == null || start == null || beacon == null) {
      throw const FormatException('Calcola prima la copertura.');
    }
    var name = _simulationName.text.trim();
    if (name.isEmpty && !requireName) {
      name =
          'Copertura ${beacon.name} ${DateTime.now().toLocal().toIso8601String().substring(0, 16)}';
    }
    if (name.isEmpty || name.length > 120) {
      throw const FormatException(
        'Inserisci un nome simulazione da 1 a 120 caratteri.',
      );
    }
    final now = DateTime.now().toUtc();
    return RadioLinkSimulation(
      id: '${now.microsecondsSinceEpoch}',
      name: name,
      kind: RadioLinkSimulationKind.coverage,
      beaconId: beacon.id,
      beaconName: beacon.name,
      startPosition: start,
      startGroundElevationMeters: profile.installerGroundElevationMeters,
      buildingHeightMeters: profile.installerAntennaHeightMeters,
      targetPosition: beacon.position,
      targetGroundElevationMeters: profile.targetGroundElevationMeters,
      targetPoleHeightMeters: profile.targetAntennaHeightMeters,
      frequencyGhz: profile.frequencyGhz,
      azimuthDegrees: azimuth,
      profile: profile,
      createdAtUtc: now,
    );
  }

  Future<void> _saveSimulation() async {
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
      ).showSnackBar(const SnackBar(content: Text('Simulazione salvata.')));
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _shareSimulation() async {
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

  String _friendlyError(Object error) {
    if (error is DeviceLocationException) return error.message;
    if (error is FormatException) return error.message;
    return 'Operazione non riuscita: $error';
  }
}

final class _BeaconDistance {
  const _BeaconDistance({required this.beacon, required this.distanceMeters});

  final RadioBeacon beacon;
  final double? distanceMeters;
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

final class _CoverageSummary extends StatelessWidget {
  const _CoverageSummary({
    required this.profile,
    required this.azimuthDegrees,
    required this.beacon,
  });

  final RadioProfileResult profile;
  final double azimuthDegrees;
  final RadioBeacon beacon;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Postazione', beacon.name),
      MapEntry('Distanza', '${profile.distanceKm.toStringAsFixed(2)} km'),
      MapEntry('Azimut vero', '${azimuthDegrees.toStringAsFixed(2)}°'),
      MapEntry(
        'Tilt teorico',
        '${profile.tiltDegrees >= 0 ? '+' : ''}${profile.tiltDegrees.toStringAsFixed(2)}°',
      ),
      MapEntry(
        'Quota partenza',
        '${profile.installerGroundElevationMeters.toStringAsFixed(0)} m',
      ),
      MapEntry(
        'Quota postazione',
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
            Text('Risultato', style: Theme.of(context).textTheme.titleLarge),
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

final class _LinkMap extends StatefulWidget {
  const _LinkMap({
    required this.start,
    required this.target,
    required this.targetName,
    required this.detail,
  });

  final GeoPoint start;
  final GeoPoint target;
  final String targetName;
  final bool detail;

  @override
  State<_LinkMap> createState() => _LinkMapState();
}

final class _LinkMapState extends State<_LinkMap> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = LatLng(widget.start.latitude, widget.start.longitude);
    final target = LatLng(widget.target.latitude, widget.target.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GoogleMap(
        mapType: widget.detail ? MapType.hybrid : MapType.normal,
        initialCameraPosition: CameraPosition(
          target: widget.detail
              ? start
              : LatLng(
                  (start.latitude + target.latitude) / 2,
                  (start.longitude + target.longitude) / 2,
                ),
          zoom: widget.detail ? 19 : 11,
        ),
        zoomControlsEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        markers: {
          Marker(
            markerId: const MarkerId('start'),
            position: start,
            infoWindow: const InfoWindow(title: 'Partenza'),
          ),
          Marker(
            markerId: const MarkerId('target'),
            position: target,
            infoWindow: InfoWindow(title: widget.targetName),
          ),
        },
        polylines: {
          Polyline(
            polylineId: const PolylineId('link'),
            points: [start, target],
            width: 4,
          ),
        },
        onMapCreated: (controller) {
          _controller = controller;
          if (!widget.detail) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final bounds = LatLngBounds(
                southwest: LatLng(
                  math.min(start.latitude, target.latitude),
                  math.min(start.longitude, target.longitude),
                ),
                northeast: LatLng(
                  math.max(start.latitude, target.latitude),
                  math.max(start.longitude, target.longitude),
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

final class _CoverageProfilePainter extends CustomPainter {
  _CoverageProfilePainter(this.profile);

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
      if (point.fresnelUpperMeters != null) {
        values.add(point.fresnelUpperMeters!);
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
      final terrainOffset = offset(point, point.adjustedTerrainMeters);
      final losOffset = offset(point, point.lineOfSightMeters);
      final fresnelOffset = point.fresnelLowerMeters == null
          ? null
          : offset(point, point.fresnelLowerMeters!);
      if (i == 0) {
        terrain.moveTo(terrainOffset.dx, terrainOffset.dy);
        los.moveTo(losOffset.dx, losOffset.dy);
        if (fresnelOffset != null) {
          fresnel.moveTo(fresnelOffset.dx, fresnelOffset.dy);
        }
      } else {
        terrain.lineTo(terrainOffset.dx, terrainOffset.dy);
        los.lineTo(losOffset.dx, losOffset.dy);
        if (fresnelOffset != null) {
          fresnel.lineTo(fresnelOffset.dx, fresnelOffset.dy);
        }
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
  bool shouldRepaint(covariant _CoverageProfilePainter oldDelegate) =>
      oldDelegate.profile != profile;
}
