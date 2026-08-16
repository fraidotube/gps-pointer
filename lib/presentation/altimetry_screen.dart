import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/device_location_service.dart';
import '../application/simulation_export_service.dart';
import '../core/domain/geo_point.dart';
import '../core/domain/radio_beacon.dart';
import '../core/geo/geo_calculator.dart';
import '../core/geo/radio_profile_engine.dart';
import '../core/simulation/radio_link_simulation.dart';
import '../core/simulation/radio_link_simulation_repository.dart';
import '../core/elevation/terrain_profile_elevation_provider.dart';

final class AltimetryScreen extends StatefulWidget {
  const AltimetryScreen({
    required this.beacon,
    required this.locationService,
    required this.profileElevationProvider,
    required this.simulationRepository,
    required this.exportService,
    required this.deviceId,
    required this.deviceName,
    super.key,
  });

  final RadioBeacon beacon;
  final DeviceLocationService locationService;
  final TerrainProfileElevationProvider profileElevationProvider;
  final RadioLinkSimulationRepository simulationRepository;
  final SimulationExportService exportService;
  final String deviceId;
  final String deviceName;

  @override
  State<AltimetryScreen> createState() => _AltimetryScreenState();
}

final class _AltimetryScreenState extends State<AltimetryScreen> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _buildingHeight = TextEditingController(text: '0');
  final _frequency = TextEditingController(text: '5.8');
  final _simulationName = TextEditingController();
  RadioProfileResult? _profile;
  double? _azimuth;
  bool _busy = false;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _buildingHeight.dispose();
    _frequency.dispose();
    _simulationName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Altimetria • ${widget.beacon.name}')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Punto di partenza',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _buildingHeight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Altezza edificio / antenna (m)',
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
                            hintText: 'Opzionale',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _calculate(useGps: false),
                          icon: const Icon(Icons.calculate),
                          label: const Text('CALCOLA'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busy
                              ? null
                              : () => _calculate(useGps: true),
                          icon: const Icon(Icons.my_location),
                          label: const Text('CALCOLA DA QUI'),
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Acquisizione quote Open-Meteo / Copernicus DEM GLO-90…',
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
          ),
          if (_profile != null) ...[
            const SizedBox(height: 12),
            _ResultSummary(profile: _profile!, azimuthDegrees: _azimuth!),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Profilo altimetrico',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('${_profile!.sampleCount} campioni'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: CustomPaint(painter: _ProfilePainter(_profile!)),
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
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Salva simulazione',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _simulationName,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nome simulazione',
                        hintText: 'Es. Cliente Rossi - Monte Subasio',
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _saveSimulation,
                        icon: Icon(_saved ? Icons.check : Icons.save),
                        label: Text(_saved ? 'SALVATA' : 'SALVA SIMULAZIONE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Profilo indicativo: il DEM ha risoluzione 90 m e non include edifici, alberi o altri ostacoli. Non sostituisce un collaudo radio.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _calculate({required bool useGps}) async {
    setState(() {
      _busy = true;
      _error = null;
      _saved = false;
    });
    try {
      if (useGps) {
        final reading = await widget.locationService.readCurrentPosition();
        _latitude.text = reading.latitude.toStringAsFixed(7);
        _longitude.text = reading.longitude.toStringAsFixed(7);
      }
      final start = _parseStartPosition();
      final buildingHeight = _parseBuildingHeight();
      final frequency = _parseFrequency();
      final distance = RadioProfileEngine.haversineDistanceMeters(
        start,
        widget.beacon.position,
      );
      final coordinates = RadioProfileEngine.geodesicCoordinates(
        start,
        widget.beacon.position,
        RadioProfileEngine.sampleCountForDistance(distance),
      );
      final elevations = await widget.profileElevationProvider.getElevations(
        coordinates,
      );
      if (widget.beacon.terrainElevationMeters != null) {
        elevations[elevations.length - 1] =
            widget.beacon.terrainElevationMeters!;
      }
      final profile = RadioProfileEngine.build(
        distanceMeters: distance,
        elevationsMeters: elevations,
        installerAntennaHeightMeters: buildingHeight,
        targetAntennaHeightMeters: widget.beacon.poleHeightMeters,
        frequencyGhz: frequency,
      );
      final azimuth = GeoCalculator.initialBearingDegrees(
        start,
        widget.beacon.position,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _azimuth = azimuth;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  GeoPoint _parseStartPosition() {
    final lat = double.tryParse(_latitude.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_longitude.text.trim().replaceAll(',', '.'));
    if (lat == null || lon == null) {
      throw const FormatException(
        'Inserisci coordinate valide oppure usa CALCOLA DA QUI.',
      );
    }
    return GeoPoint.validated(latitude: lat, longitude: lon);
  }

  double _parseBuildingHeight() {
    final value = double.tryParse(
      _buildingHeight.text.trim().replaceAll(',', '.'),
    );
    if (value == null || !value.isFinite || value < 0 || value > 1000) {
      throw const FormatException(
        'Altezza edificio non valida. Inserisci un valore tra 0 e 1000 m.',
      );
    }
    return value;
  }

  double? _parseFrequency() {
    final raw = _frequency.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0.001 || value > 300) {
      throw const FormatException('Frequenza non valida.');
    }
    return value;
  }

  Future<void> _saveSimulation() async {
    final profile = _profile;
    final azimuth = _azimuth;
    if (profile == null || azimuth == null) {
      return;
    }
    final name = _simulationName.text.trim();
    if (name.isEmpty || name.length > 120) {
      setState(
        () => _error = 'Inserisci un nome simulazione da 1 a 120 caratteri.',
      );
      return;
    }
    final start = _parseStartPosition();
    final now = DateTime.now().toUtc();
    final simulation = RadioLinkSimulation(
      id: '${now.microsecondsSinceEpoch}',
      name: name,
      beaconId: widget.beacon.id,
      beaconName: widget.beacon.name,
      startPosition: start,
      startGroundElevationMeters: profile.installerGroundElevationMeters,
      buildingHeightMeters: profile.installerAntennaHeightMeters,
      targetPosition: widget.beacon.position,
      targetGroundElevationMeters: profile.targetGroundElevationMeters,
      targetPoleHeightMeters: profile.targetAntennaHeightMeters,
      frequencyGhz: profile.frequencyGhz,
      azimuthDegrees: azimuth,
      profile: profile,
      createdAtUtc: now,
    );
    await widget.simulationRepository.save(simulation);
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = true;
      _error = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Simulazione salvata.')));
  }

  String _friendlyError(Object error) {
    if (error is DeviceLocationException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    return 'Calcolo non riuscito: $error';
  }
}

final class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.profile, required this.azimuthDegrees});
  final RadioProfileResult profile;
  final double azimuthDegrees;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
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
        'Quota radiofaro',
        '${profile.targetGroundElevationMeters.toStringAsFixed(0)} m',
      ),
      MapEntry(
        'Quota antenna partenza',
        '${profile.installerAntennaElevationMeters.toStringAsFixed(1)} m',
      ),
      MapEntry(
        'Quota antenna radiofaro',
        '${profile.targetAntennaElevationMeters.toStringAsFixed(1)} m',
      ),
      MapEntry(
        'Linea ottica',
        profile.lineOfSightClear ? 'Libera' : 'Ostruita',
      ),
      if (profile.firstFresnelClear != null)
        MapEntry(
          'Prima Fresnel',
          profile.firstFresnelClear! ? 'Libera' : 'Ostruita',
        ),
      MapEntry(
        'Margine LOS minimo',
        '${profile.minimumLosClearanceMeters >= 0 ? '+' : ''}${profile.minimumLosClearanceMeters.toStringAsFixed(1)} m a ${profile.minimumLosClearanceDistanceKm.toStringAsFixed(2)} km',
      ),
      if (profile.minimumFresnelClearanceMeters != null)
        MapEntry(
          'Margine Fresnel minimo',
          '${profile.minimumFresnelClearanceMeters! >= 0 ? '+' : ''}${profile.minimumFresnelClearanceMeters!.toStringAsFixed(1)} m a ${profile.minimumFresnelClearanceDistanceKm!.toStringAsFixed(2)} km',
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

final class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.profile);
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
  bool shouldRepaint(covariant _ProfilePainter oldDelegate) =>
      oldDelegate.profile != profile;
}
