import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../application/app_visual_theme.dart';
import '../application/simulation_pdf_service.dart';
import '../core/simulation/radio_link_simulation.dart';

final class SimulationReviewScreen extends StatefulWidget {
  const SimulationReviewScreen({
    required this.simulation,
    required this.onExport,
    required this.onDuplicate,
    required this.onDelete,
    super.key,
  });

  final RadioLinkSimulation simulation;
  final Future<void> Function() onExport;
  final Future<void> Function() onDuplicate;
  final Future<bool> Function() onDelete;

  @override
  State<SimulationReviewScreen> createState() => _SimulationReviewScreenState();
}

final class _SimulationReviewScreenState extends State<SimulationReviewScreen> {
  final GlobalKey _profileKey = GlobalKey();
  GoogleMapController? _overview;
  GoogleMapController? _detailA;
  GoogleMapController? _detailB;
  bool _pdfBusy = false;

  @override
  void dispose() {
    _overview?.dispose();
    _detailA?.dispose();
    _detailB?.dispose();
    super.dispose();
  }

  RadioLinkSimulation get simulation => widget.simulation;

  @override
  Widget build(BuildContext context) {
    final p = simulation.profile;
    final isPtp = simulation.kind == RadioLinkSimulationKind.ptp;

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio simulazione')),
      body: GpsThemeBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              Text(
                simulation.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${simulation.beaconName} • ${_date(simulation.createdAtUtc)}',
              ),
              const SizedBox(height: 12),
              _card(context, 'Risultato', [
                _line('Tipo', isPtp ? 'Punto-Punto' : 'Copertura'),
                _line('Distanza', '${p.distanceKm.toStringAsFixed(2)} km'),
                _line(
                  'Azimut vero',
                  '${simulation.azimuthDegrees.toStringAsFixed(2)}°',
                ),
                _line(
                  'Tilt teorico',
                  '${p.tiltDegrees >= 0 ? '+' : ''}${p.tiltDegrees.toStringAsFixed(2)}°',
                ),
                _line('LOS', p.lineOfSightClear ? 'Libera' : 'Ostruita'),
                if (p.firstFresnelClear != null)
                  _line(
                    'Prima Fresnel',
                    p.firstFresnelClear! ? 'Libera' : 'Ostruita',
                  ),
                _line(
                  'Margine LOS minimo',
                  '${p.minimumLosClearanceMeters.toStringAsFixed(1)} m',
                ),
                if (p.minimumFresnelClearanceMeters != null)
                  _line(
                    'Margine Fresnel minimo',
                    '${p.minimumFresnelClearanceMeters!.toStringAsFixed(1)} m',
                  ),
              ]),
              const SizedBox(height: 12),
              _card(context, 'Profilo altimetrico', [
                RepaintBoundary(
                  key: _profileKey,
                  child: Container(
                    height: 250,
                    padding: const EdgeInsets.all(8),
                    color: Theme.of(context).colorScheme.surface,
                    child: CustomPaint(
                      painter: _SavedProfilePainter(p),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _Legend(label: 'Terreno', color: Color(0xFFB08A68)),
                    _Legend(label: 'LOS', color: Color(0xFF24B8FF)),
                    _Legend(
                      label: 'Fresnel inferiore',
                      color: Color(0xFF65DF87),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 12),
              _card(context, 'Mappa collegamento', [
                SizedBox(
                  height: 310,
                  child: _SavedMap(
                    a: simulation.startPosition,
                    b: simulation.targetPosition,
                    detail: _SavedMapDetail.overview,
                    onCreated: (c) => _overview = c,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _card(context, 'Dettaglio Punto A', [
                const Text(
                  'Vista ibrida ravvicinata con direttrice verso il Punto B.',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 320,
                  child: _SavedMap(
                    a: simulation.startPosition,
                    b: simulation.targetPosition,
                    detail: _SavedMapDetail.a,
                    onCreated: (c) => _detailA = c,
                  ),
                ),
              ]),
              if (isPtp) ...[
                const SizedBox(height: 12),
                _card(context, 'Dettaglio Punto B', [
                  const Text(
                    'Vista ibrida ravvicinata con direttrice verso il Punto A.',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 320,
                    child: _SavedMap(
                      a: simulation.startPosition,
                      b: simulation.targetPosition,
                      detail: _SavedMapDetail.b,
                      onCreated: (c) => _detailB = c,
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: widget.onExport,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('CONDIVIDI .GPSPSIM'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pdfBusy ? null : _createPdf,
                icon: _pdfBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('GENERA / CONDIVIDI PDF COMPLETO'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onDuplicate,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('DUPLICA'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final deleted = await widget.onDelete();
                  if (!mounted || !deleted) return;
                  Navigator.of(this.context).pop(true);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('ELIMINA'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPdf() async {
    setState(() => _pdfBusy = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final profilePng = await _captureProfile();
      final overviewPng = await _overview?.takeSnapshot();
      final detailAPng = await _detailA?.takeSnapshot();
      final detailBPng = await _detailB?.takeSnapshot();

      await const SimulationPdfService().createAndShare(
        simulation,
        profilePng: profilePng,
        overviewMapPng: overviewPng,
        detailAMapPng: detailAPng,
        detailBMapPng: detailBPng,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF non generato: $error')));
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<Uint8List?> _captureProfile() async {
    final boundary =
        _profileKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  static Widget _card(
    BuildContext context,
    String title,
    List<Widget> children,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );

  static Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
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

  static String _date(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

enum _SavedMapDetail { overview, a, b }

final class _SavedMap extends StatefulWidget {
  const _SavedMap({
    required this.a,
    required this.b,
    required this.detail,
    required this.onCreated,
  });

  final dynamic a;
  final dynamic b;
  final _SavedMapDetail detail;
  final ValueChanged<GoogleMapController> onCreated;

  @override
  State<_SavedMap> createState() => _SavedMapState();
}

final class _SavedMapState extends State<_SavedMap> {
  @override
  Widget build(BuildContext context) {
    final a = LatLng(widget.a.latitude as double, widget.a.longitude as double);
    final b = LatLng(widget.b.latitude as double, widget.b.longitude as double);
    final target = switch (widget.detail) {
      _SavedMapDetail.a => a,
      _SavedMapDetail.b => b,
      _SavedMapDetail.overview => LatLng(
        (a.latitude + b.latitude) / 2,
        (a.longitude + b.longitude) / 2,
      ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GoogleMap(
        mapType: widget.detail == _SavedMapDetail.overview
            ? MapType.normal
            : MapType.hybrid,
        initialCameraPosition: CameraPosition(
          target: target,
          zoom: widget.detail == _SavedMapDetail.overview ? 11 : 19,
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
            polylineId: const PolylineId('link'),
            points: [a, b],
            width: 4,
          ),
        },
        onMapCreated: (controller) {
          widget.onCreated(controller);
          if (widget.detail == _SavedMapDetail.overview) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              unawaited(
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(
                        a.latitude < b.latitude ? a.latitude : b.latitude,
                        a.longitude < b.longitude ? a.longitude : b.longitude,
                      ),
                      northeast: LatLng(
                        a.latitude > b.latitude ? a.latitude : b.latitude,
                        a.longitude > b.longitude ? a.longitude : b.longitude,
                      ),
                    ),
                    48,
                  ),
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

final class _SavedProfilePainter extends CustomPainter {
  _SavedProfilePainter(this.profile);
  final dynamic profile;

  @override
  void paint(Canvas canvas, Size size) {
    final points = profile.points as List;
    if (points.length < 2) return;

    const pad = 10.0;
    final width = size.width - pad * 2;
    final height = size.height - pad * 2;
    final values = <double>[];
    for (final point in points) {
      values.add(point.adjustedTerrainMeters as double);
      values.add(point.lineOfSightMeters as double);
      final f = point.fresnelLowerMeters as double?;
      if (f != null) values.add(f);
    }
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    if ((maxY - minY).abs() < 1) {
      minY -= 1;
      maxY += 1;
    }

    Offset pos(dynamic point, double y) {
      final x =
          pad +
          ((point.distanceKm as double) / (profile.distanceKm as double)) *
              width;
      final normalized = (y - minY) / (maxY - minY);
      return Offset(x, pad + height * (1 - normalized));
    }

    final terrain = Path();
    final los = Path();
    final fresnel = Path();
    var fresnelStarted = false;
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final t = pos(point, point.adjustedTerrainMeters as double);
      final l = pos(point, point.lineOfSightMeters as double);
      final fValue = point.fresnelLowerMeters as double?;
      if (i == 0) {
        terrain.moveTo(t.dx, t.dy);
        los.moveTo(l.dx, l.dy);
      } else {
        terrain.lineTo(t.dx, t.dy);
        los.lineTo(l.dx, l.dy);
      }
      if (fValue != null) {
        final f = pos(point, fValue);
        if (!fresnelStarted) {
          fresnel.moveTo(f.dx, f.dy);
          fresnelStarted = true;
        } else {
          fresnel.lineTo(f.dx, f.dy);
        }
      }
    }

    canvas.drawPath(
      terrain,
      Paint()
        ..color = const Color(0xFFB08A68)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      los,
      Paint()
        ..color = const Color(0xFF24B8FF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    if (fresnelStarted) {
      canvas.drawPath(
        fresnel,
        Paint()
          ..color = const Color(0xFF65DF87)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SavedProfilePainter oldDelegate) => false;
}
