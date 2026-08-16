import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../application/pointing_controller.dart';
import '../application/guidance_audio_controller.dart';
import '../core/core.dart';
import 'guidance_overlay.dart';

final class AntennaTiltScreen extends StatefulWidget {
  const AntennaTiltScreen({
    required this.beacon,
    required this.controller,
    required this.observerHeightMeters,
    super.key,
  });

  final RadioBeacon beacon;
  final PointingController controller;
  final double observerHeightMeters;

  @override
  State<AntennaTiltScreen> createState() => _AntennaTiltScreenState();
}

final class _AntennaTiltScreenState extends State<AntennaTiltScreen> {
  StreamSubscription<AccelerometerEvent>? _subscription;
  Timer? _sensorTimeout;
  AntennaTiltEngine? _engine;
  AntennaTiltReading? _reading;
  String? _sensorError;
  bool _showGuide = true;
  final GuidanceAudioController _audio = GuidanceAudioController();

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(_prepare());
  }

  Future<void> _prepare({bool refreshPosition = false}) async {
    _stopSensor();
    setState(() {
      _engine = null;
      _reading = null;
      _sensorError = null;
    });
    await widget.controller.prepare(
      beacon: widget.beacon,
      observerHeightMeters: widget.observerHeightMeters,
      refreshPosition: refreshPosition,
    );
    if (!mounted || widget.controller.solution == null) return;
    _createEngine();
    if (!_showGuide) _startSensor();
    setState(() {});
  }

  void _createEngine() {
    _engine = AntennaTiltEngine(
      targetTiltDegrees: widget.controller.solution!.elevationAngleDegrees,
    );
    _reading = null;
    _sensorError = null;
  }

  void _acceptGuide() {
    if (widget.controller.solution == null) return;
    setState(() => _showGuide = false);
    _createEngine();
    _startSensor();
  }

  void _startSensor() {
    _stopSensor();
    _subscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen(
          _onAccelerometer,
          onError: (_) {
            if (mounted) {
              setState(() => _sensorError = 'Lettura inclinazione interrotta.');
            }
          },
        );
    _sensorTimeout = Timer(const Duration(seconds: 5), () {
      if (mounted && _reading == null) {
        setState(() {
          _sensorError =
              'L’accelerometro non invia dati. Il tilt resta disabilitato.';
        });
      }
    });
  }

  void _onAccelerometer(AccelerometerEvent event) {
    final engine = _engine;
    if (!mounted || engine == null) return;
    _sensorTimeout?.cancel();
    final pose = AntennaTiltCalculator.fromGravity(
      x: event.x,
      y: event.y,
      z: event.z,
    );
    final reading = engine.update(pose: pose);
    setState(() {
      _reading = reading;
      _sensorError = null;
    });
    _updateAudio();
  }

  void _restart() {
    _stopSensor();
    _createEngine();
    _startSensor();
    setState(() {});
  }

  void _stopSensor() {
    _audio.stopOutput();
    _sensorTimeout?.cancel();
    _sensorTimeout = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  @override
  void dispose() {
    _stopSensor();
    _audio.dispose();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text('Tilt • ${widget.beacon.name}'),
        actions: [
          IconButton(
            tooltip: _audio.enabled
                ? 'Disattiva guida sonora'
                : 'Attiva guida sonora',
            onPressed: widget.controller.busy || _showGuide
                ? null
                : () {
                    setState(() => _audio.setEnabled(!_audio.enabled));
                    _updateAudio();
                  },
            icon: Icon(_audio.enabled ? Icons.volume_up : Icons.volume_off),
          ),
          IconButton(
            tooltip: 'Istruzioni',
            onPressed: () {
              _stopSensor();
              setState(() => _showGuide = true);
            },
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Ristabilizza inclinometro',
            onPressed: widget.controller.busy || _showGuide ? null : _restart,
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            tooltip: 'Aggiorna posizione osservatore',
            onPressed: widget.controller.busy
                ? null
                : () => _prepare(refreshPosition: true),
            icon: const Icon(Icons.gps_fixed),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _body(context),
            if (_showGuide &&
                !widget.controller.busy &&
                widget.controller.solution != null)
              GuidanceOverlay(
                title: 'Tilt dell’antenna',
                illustration: GuidanceIllustration.antennaTilt,
                steps: const [
                  'Appoggia il retro del telefono contro il retro piano dell’antenna.',
                  'Tieni lo schermo verso di te e il bordo superiore rivolto verso l’alto.',
                  'Non usare il telefono in landscape: questa modalità è portrait.',
                  'Lascia telefono e antenna fermi durante la stabilizzazione iniziale.',
                ],
                actionLabel: 'Inizia stabilizzazione',
                onAction: _acceptGuide,
              ),
          ],
        ),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    if (widget.controller.busy) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(widget.controller.busyMessage, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    final error = widget.controller.errorMessage;
    if (error != null) return _message(error);
    final solution = widget.controller.solution;
    if (solution == null) return _message('Puntamento non disponibile.');
    if (_sensorError != null) return _message(_sensorError!);
    final reading = _reading;
    final ready = reading?.state == AntennaTiltState.ready;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  widget.beacon.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tilt richiesto '
                  '${solution.elevationAngleDegrees.toStringAsFixed(1)}°',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text('Misura gravitazionale • magnetometro escluso'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1.25,
          child: CustomPaint(
            painter: _TiltGaugePainter(
              targetDegrees: solution.elevationAngleDegrees,
              measuredDegrees: ready && reading != null
                  ? reading.measuredTiltDegrees
                  : null,
              centered: reading?.centered ?? false,
              colors: Theme.of(context).colorScheme,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _guidance(reading),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _guidanceColor(context, reading),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (reading == null ||
                    reading.state == AntennaTiltState.warmingUp) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: reading?.warmupProgress ?? 0),
                ],
                if (reading != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Inclinazione rilevata '
                    '${reading.measuredTiltDegrees.toStringAsFixed(1)}°',
                  ),
                  Text(
                    'Differenza ${reading.deltaDegrees.toStringAsFixed(1)}°',
                    style: TextStyle(
                      color: reading.centered
                          ? const Color(0xFF63D98A)
                          : const Color(0xFFFFB454),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Il telefono deve restare solidale con il retro '
                  'dell’antenna, in verticale portrait.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _guidance(AntennaTiltReading? reading) {
    if (reading == null) return 'Appoggia il telefono e tienilo fermo';
    if (!reading.mountingValid) {
      return 'Metti il telefono verticale, diritto e con il bordo superiore in alto';
    }
    if (reading.state == AntennaTiltState.warmingUp) {
      return 'Non muovere antenna e telefono: stabilizzazione '
          '${(reading.warmupProgress * 100).round()}%';
    }
    if (reading.state == AntennaTiltState.unstable) {
      return 'Misura instabile: ferma l’antenna e ristabilizza';
    }
    if (reading.centered) return 'TILT CENTRATO';
    return reading.deltaDegrees > 0
        ? 'Alza ${reading.deltaDegrees.abs().toStringAsFixed(1)}°'
        : 'Abbassa ${reading.deltaDegrees.abs().toStringAsFixed(1)}°';
  }

  Color _guidanceColor(BuildContext context, AntennaTiltReading? reading) {
    final colors = Theme.of(context).colorScheme;
    if (reading == null || reading.state == AntennaTiltState.warmingUp) {
      return colors.primary;
    }
    if (!reading.mountingValid || reading.state == AntennaTiltState.unstable) {
      return colors.error;
    }
    if (reading.centered) return const Color(0xFF63D98A);
    if (reading.deltaDegrees.abs() >= 15) return const Color(0xFFFF7A6E);
    return const Color(0xFFFFB454);
  }

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  void _updateAudio() {
    final reading = _reading;
    final stable =
        !_showGuide &&
        reading?.state == AntennaTiltState.ready &&
        (reading?.mountingValid ?? false);
    _audio.update(
      stable: stable,
      centered: stable && (reading?.centered ?? false),
      absoluteErrorDegrees: reading?.deltaDegrees.abs() ?? double.infinity,
    );
  }
}

final class _TiltGaugePainter extends CustomPainter {
  const _TiltGaugePainter({
    required this.targetDegrees,
    required this.measuredDegrees,
    required this.centered,
    required this.colors,
  });

  final double targetDegrees;
  final double? measuredDegrees;
  final bool centered;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.82);
    final radius = math.min(size.width * 0.42, size.height * 0.72);
    final ring = Paint()
      ..color = colors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      ring,
    );
    for (var degrees = -60; degrees <= 60; degrees += 10) {
      final angle = _angle(degrees.toDouble());
      final outer = _point(center, radius, angle);
      final inner = _point(center, radius - 14, angle);
      canvas.drawLine(inner, outer, ring);
    }
    final targetAngle = _angle(targetDegrees.clamp(-60, 60).toDouble());
    final tolerancePaint = Paint()
      ..color = const Color(0xFF63D98A).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      targetAngle - math.pi / 180,
      2 * math.pi / 180,
      false,
      tolerancePaint,
    );

    _needle(canvas, center, radius, targetDegrees, colors.primary, 5);
    if (measuredDegrees != null) {
      _needle(
        canvas,
        center,
        radius - 18,
        measuredDegrees!,
        centered ? const Color(0xFF63D98A) : const Color(0xFFFFB454),
        7,
      );
    }
    canvas.drawCircle(center, 7, Paint()..color = colors.onSurface);
  }

  void _needle(
    Canvas canvas,
    Offset center,
    double radius,
    double degrees,
    Color color,
    double width,
  ) {
    final clamped = degrees.clamp(-60, 60).toDouble();
    canvas.drawLine(
      center,
      _point(center, radius, _angle(clamped)),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  static double _angle(double degrees) =>
      -math.pi / 2 + degrees * math.pi / 180;

  static Offset _point(Offset center, double radius, double angle) => Offset(
    center.dx + math.cos(angle) * radius,
    center.dy + math.sin(angle) * radius,
  );

  @override
  bool shouldRepaint(_TiltGaugePainter oldDelegate) =>
      oldDelegate.targetDegrees != targetDegrees ||
      oldDelegate.measuredDegrees != measuredDegrees ||
      oldDelegate.centered != centered ||
      oldDelegate.colors != colors;
}
