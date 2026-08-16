import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/simulation_export_service.dart';
import '../core/geo/radio_profile_engine.dart';
import '../core/simulation/radio_link_simulation.dart';
import '../core/simulation/radio_link_simulation_repository.dart';

final class SimulationsScreen extends StatefulWidget {
  const SimulationsScreen({
    required this.repository,
    required this.exportService,
    required this.deviceId,
    required this.deviceName,
    super.key,
  });

  final RadioLinkSimulationRepository repository;
  final SimulationExportService exportService;
  final String deviceId;
  final String deviceName;

  @override
  State<SimulationsScreen> createState() => _SimulationsScreenState();
}

final class _SimulationsScreenState extends State<SimulationsScreen> {
  late Future<List<RadioLinkSimulation>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = widget.repository.loadAll();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Simulazioni')),
    body: SafeArea(
      child: FutureBuilder<List<RadioLinkSimulation>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Errore archivio simulazioni: ${snapshot.error}'),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('Nessuna simulazione salvata.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => _SimulationCard(
              simulation: items[index],
              onOpen: () => _openDetail(items[index]),
              onDelete: () => _delete(items[index]),
              onExport: () => _export(items[index]),
            ),
          );
        },
      ),
    ),
  );

  Future<void> _openDetail(RadioLinkSimulation simulation) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SimulationDetailScreen(
          simulation: simulation,
          onExport: () => _export(simulation),
          onDelete: () => _deleteFromDetail(simulation),
        ),
      ),
    );
    if (deleted == true && mounted) setState(_reload);
  }

  Future<void> _export(RadioLinkSimulation simulation) =>
      widget.exportService.export(
        simulation: simulation,
        deviceId: widget.deviceId,
        deviceName: widget.deviceName,
      );

  Future<bool> _confirmDelete(RadioLinkSimulation simulation) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Elimina simulazione'),
          content: Text('Eliminare “${simulation.name}”?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _delete(RadioLinkSimulation simulation) async {
    if (!await _confirmDelete(simulation)) return;
    await widget.repository.delete(simulation.id);
    if (!mounted) return;
    setState(_reload);
  }

  Future<bool> _deleteFromDetail(RadioLinkSimulation simulation) async {
    if (!await _confirmDelete(simulation)) return false;
    await widget.repository.delete(simulation.id);
    return true;
  }
}

final class _SimulationCard extends StatelessWidget {
  const _SimulationCard({
    required this.simulation,
    required this.onOpen,
    required this.onDelete,
    required this.onExport,
  });

  final RadioLinkSimulation simulation;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      title: Text(simulation.name),
      subtitle: Text(
        '${simulation.beaconName} • ${_localDate(simulation.createdAtUtc)}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _line(
          'Distanza',
          '${simulation.profile.distanceKm.toStringAsFixed(2)} km',
        ),
        _line(
          'Azimut vero',
          '${simulation.azimuthDegrees.toStringAsFixed(2)}°',
        ),
        _line(
          'Tilt teorico',
          '${simulation.profile.tiltDegrees >= 0 ? '+' : ''}${simulation.profile.tiltDegrees.toStringAsFixed(2)}°',
        ),
        _line(
          'Linea ottica',
          simulation.profile.lineOfSightClear ? 'Libera' : 'Ostruita',
        ),
        if (simulation.profile.firstFresnelClear != null)
          _line(
            'Prima Fresnel',
            simulation.profile.firstFresnelClear! ? 'Libera' : 'Ostruita',
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: const Text('APRI DETTAGLIO'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onExport,
                icon: const Icon(Icons.ios_share),
                label: const Text('Esporta'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

final class SimulationDetailScreen extends StatelessWidget {
  const SimulationDetailScreen({
    required this.simulation,
    required this.onExport,
    required this.onDelete,
    super.key,
  });

  final RadioLinkSimulation simulation;
  final Future<void> Function() onExport;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final profile = simulation.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio simulazione')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              simulation.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${simulation.beaconName} • ${_localDate(simulation.createdAtUtc)}',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Risultato',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _DetailLine(
                      'Distanza',
                      '${profile.distanceKm.toStringAsFixed(2)} km',
                    ),
                    _DetailLine(
                      'Azimut vero',
                      '${simulation.azimuthDegrees.toStringAsFixed(2)}°',
                    ),
                    _DetailLine(
                      'Tilt teorico',
                      '${profile.tiltDegrees >= 0 ? '+' : ''}${profile.tiltDegrees.toStringAsFixed(2)}°',
                    ),
                    _DetailLine(
                      'Linea ottica',
                      profile.lineOfSightClear ? 'Libera' : 'Ostruita',
                    ),
                    if (profile.firstFresnelClear != null)
                      _DetailLine(
                        'Prima Fresnel',
                        profile.firstFresnelClear! ? 'Libera' : 'Ostruita',
                      ),
                    _DetailLine(
                      'Margine LOS minimo',
                      '${_signed(profile.minimumLosClearanceMeters)} m a ${profile.minimumLosClearanceDistanceKm.toStringAsFixed(2)} km',
                    ),
                    if (profile.minimumFresnelClearanceMeters != null)
                      _DetailLine(
                        'Margine Fresnel minimo',
                        '${_signed(profile.minimumFresnelClearanceMeters!)} m a ${profile.minimumFresnelClearanceDistanceKm!.toStringAsFixed(2)} km',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Profilo altimetrico',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('${profile.sampleCount} campioni'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 340,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _DetailedProfilePainter(profile),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _Legend('Terreno', Color(0xFFFF765F)),
                        _Legend('Linea ottica', Color(0xFF4DDCF0)),
                        _Legend('Prima Fresnel', Color(0xFF65DF87)),
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
                      'Dati tecnici',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _DetailLine(
                      'Partenza',
                      '${simulation.startPosition.latitude.toStringAsFixed(7)}, ${simulation.startPosition.longitude.toStringAsFixed(7)}',
                    ),
                    _DetailLine(
                      'Quota terreno partenza',
                      '${simulation.startGroundElevationMeters.toStringAsFixed(1)} m',
                    ),
                    _DetailLine(
                      'Altezza edificio / antenna',
                      '${simulation.buildingHeightMeters.toStringAsFixed(1)} m',
                    ),
                    _DetailLine(
                      'Quota antenna partenza',
                      '${profile.installerAntennaElevationMeters.toStringAsFixed(1)} m',
                    ),
                    _DetailLine(
                      'Radiofaro',
                      '${simulation.targetPosition.latitude.toStringAsFixed(7)}, ${simulation.targetPosition.longitude.toStringAsFixed(7)}',
                    ),
                    _DetailLine(
                      'Quota terreno radiofaro',
                      '${simulation.targetGroundElevationMeters.toStringAsFixed(1)} m',
                    ),
                    _DetailLine(
                      'Altezza palo',
                      '${simulation.targetPoleHeightMeters.toStringAsFixed(1)} m',
                    ),
                    _DetailLine(
                      'Quota antenna radiofaro',
                      '${profile.targetAntennaElevationMeters.toStringAsFixed(1)} m',
                    ),
                    _DetailLine(
                      'Frequenza',
                      simulation.frequencyGhz == null
                          ? 'Non indicata'
                          : '${simulation.frequencyGhz!.toStringAsFixed(3)} GHz',
                    ),
                    _DetailLine(
                      'Fattore K',
                      profile.kFactor.toStringAsFixed(3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onExport,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Esporta'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final deleted = await onDelete();
                      if (deleted && context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Elimina'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

final class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
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

final class _DetailedProfilePainter extends CustomPainter {
  _DetailedProfilePainter(this.profile);
  final RadioProfileResult profile;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.points.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    const left = 44.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 30.0;
    final usableWidth = math.max(1.0, size.width - left - right);
    final usableHeight = math.max(1.0, size.height - top - bottom);

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
      final x = left + (point.distanceKm / profile.distanceKm) * usableWidth;
      final normalized = (y - minY) / (maxY - minY);
      return Offset(x, top + usableHeight * (1 - normalized));
    }

    final gridPaint = Paint()
      ..color = const Color(0xFF2A4657)
      ..strokeWidth = .8;
    for (var i = 0; i <= 4; i++) {
      final y = top + usableHeight * i / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + usableWidth, y),
        gridPaint,
      );
      final value = maxY - (maxY - minY) * i / 4;
      _paintText(canvas, '${value.toStringAsFixed(0)} m', Offset(0, y - 7), 10);
    }
    for (var i = 0; i <= 4; i++) {
      final x = left + usableWidth * i / 4;
      canvas.drawLine(Offset(x, top), Offset(x, top + usableHeight), gridPaint);
      final km = profile.distanceKm * i / 4;
      _paintText(
        canvas,
        '${km.toStringAsFixed(profile.distanceKm < 10 ? 1 : 0)} km',
        Offset(math.max(0, x - 14), top + usableHeight + 6),
        9,
      );
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
        ..strokeWidth = 2.3,
    );
    canvas.drawPath(
      los,
      Paint()
        ..color = const Color(0xFF4DDCF0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3,
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

    final worst = profile.points.reduce((a, b) {
      final aClear = a.lineOfSightMeters - a.adjustedTerrainMeters;
      final bClear = b.lineOfSightMeters - b.adjustedTerrainMeters;
      return aClear <= bClear ? a : b;
    });
    final worstOffset = offset(worst, worst.adjustedTerrainMeters);
    canvas.drawCircle(
      worstOffset,
      4.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      worstOffset,
      4.5,
      Paint()
        ..color = const Color(0xFFFF3045)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintText(Canvas canvas, String text, Offset offset, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: const Color(0xFF91A5B8), fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DetailedProfilePainter oldDelegate) =>
      oldDelegate.profile != profile;
}

String _signed(double value) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';

String _localDate(DateTime utc) {
  final value = utc.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year}, ${two(value.hour)}:${two(value.minute)}';
}
