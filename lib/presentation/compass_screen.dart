import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../application/pointing_controller.dart';
import '../application/guidance_audio_controller.dart';
import '../application/diagnostic_log_store.dart';
import '../core/core.dart';
import 'guidance_overlay.dart';

final class CompassScreen extends StatefulWidget {
  const CompassScreen({
    required this.beacon,
    required this.controller,
    required this.observerHeightMeters,
    super.key,
  });

  final RadioBeacon beacon;
  final PointingController controller;
  final double observerHeightMeters;

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

final class _CompassScreenState extends State<CompassScreen> {
  PointingEngineV2? _engine;
  PointingEngineReading? _reading;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _sensorTimeout;
  String? _sensorError;
  double? _screenPlaneTiltDegrees;
  bool _showGuide = true;
  bool _showCalibrationGuide = false;
  final GuidanceAudioController _audio = GuidanceAudioController();
  double? _rawMagneticHeadingDegrees;
  bool _showDebugPanel = true;
  final List<_AzimuthDebugMark> _debugMarks = <_AzimuthDebugMark>[];
  final DateTime _debugSessionStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    await _prepare();
  }

  Future<void> _prepare({bool refreshPosition = false}) async {
    _stopSensors();
    setState(() {
      _engine = null;
      _reading = null;
      _sensorError = null;
      _screenPlaneTiltDegrees = null;
    });
    await widget.controller.prepare(
      beacon: widget.beacon,
      observerHeightMeters: widget.observerHeightMeters,
      refreshPosition: refreshPosition,
    );
    if (!mounted || widget.controller.solution == null) return;
    if (widget.controller.hasMagnetometer == false) {
      setState(() {
        _sensorError =
            'Questo dispositivo non dispone di un magnetometro. '
            'Usa Mappa; la bussola non può fornire una direzione reale.';
      });
      return;
    }
    _engine = PointingEngineV2(
      targetAzimuthDegrees: widget.controller.solution!.initialBearingDegrees,
      targetElevationDegrees: 0,
      declinationDegrees: widget.controller.declinationDegrees,
    );
    if (!_showGuide) _startSensors();
    setState(() {});
  }

  void _acceptGuide() {
    setState(() => _showGuide = false);
    _restartSensors();
  }

  void _startSensors() {
    final events = FlutterCompass.events;
    if (events == null) {
      setState(() => _sensorError = 'Bussola non disponibile.');
      return;
    }
    _compassSubscription = events.listen(
      _onCompass,
      onError: (_) {
        if (mounted) {
          setState(() => _sensorError = 'Lettura bussola interrotta.');
        }
      },
    );
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccelerometer);
    _sensorTimeout = Timer(const Duration(seconds: 5), () {
      if (mounted && _reading == null) {
        setState(() {
          _sensorError =
              'Il sensore bussola non invia dati. La funzione resta '
              'disabilitata per evitare indicazioni false.';
        });
      }
    });
  }

  void _onCompass(CompassEvent event) {
    final heading = event.heading;
    final engine = _engine;
    if (!mounted || heading == null || engine == null) return;
    _sensorTimeout?.cancel();
    final reading = engine.update(
      magneticHeadingDegrees: heading,
      cameraElevationDegrees: 0,
    );
    setState(() {
      _rawMagneticHeadingDegrees = heading;
      _reading = reading;
      _sensorError = null;
      if (reading.state == PointingEngineState.unstable) {
        _showCalibrationGuide = true;
      }
    });
    _updateAudio();
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (!mounted) return;
    final tilt = HorizontalDeviceCalculator.tiltFromHorizontalDegrees(
      x: event.x,
      y: event.y,
      z: event.z,
    );
    if (_screenPlaneTiltDegrees == null ||
        (tilt - _screenPlaneTiltDegrees!).abs() >= 0.2) {
      setState(() => _screenPlaneTiltDegrees = tilt);
      _updateAudio();
    }
  }

  void _restartSensors() {
    if (widget.controller.solution == null) return;
    _stopSensors();
    setState(() {
      _reading = null;
      _sensorError = null;
      _showCalibrationGuide = false;
    });
    _engine = PointingEngineV2(
      targetAzimuthDegrees: widget.controller.solution!.initialBearingDegrees,
      targetElevationDegrees: 0,
      declinationDegrees: widget.controller.declinationDegrees,
    );
    _startSensors();
  }

  void _stopSensors() {
    _audio.stopOutput();
    _sensorTimeout?.cancel();
    _sensorTimeout = null;
    unawaited(_compassSubscription?.cancel());
    unawaited(_accelerometerSubscription?.cancel());
    _compassSubscription = null;
    _accelerometerSubscription = null;
  }

  @override
  void dispose() {
    _stopSensors();
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
        title: Text('Azimut • ${widget.beacon.name}'),
        actions: [
          IconButton(
            tooltip: 'Bandierina riferimento visivo',
            onPressed: widget.controller.busy || _showGuide
                ? null
                : _markVisualReference,
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: _showDebugPanel ? 'Nascondi debug' : 'Mostra debug',
            onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
            icon: Icon(
              _showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Esporta debug TXT',
            onPressed: _debugMarks.isEmpty ? null : _shareDebugLog,
            icon: const Icon(Icons.description_outlined),
          ),
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
              _stopSensors();
              setState(() => _showGuide = true);
            },
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Ristabilizza letture',
            onPressed: widget.controller.busy || _showGuide
                ? null
                : _restartSensors,
            icon: const Icon(Icons.compass_calibration),
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
                title: 'Azimut • telefono verticale sul lato lungo',
                illustration: GuidanceIllustration.horizontal,
                steps: const [
                  'Allontanati da antenna, metallo, magneti, cavi e correnti elettriche.',
                  'Tieni il telefono VERTICALE appoggiato o impugnato sul suo LATO LUNGO.',
                  'Lo schermo resta in landscape: il bordo lungo superiore è orizzontale.',
                  'Ruota tutto il telefono a destra o sinistra e lascialo fermo durante la stabilizzazione.',
                ],
                actionLabel: 'Inizia stabilizzazione',
                onAction: _acceptGuide,
              ),
            if (_showCalibrationGuide && !_showGuide)
              GuidanceOverlay(
                title: 'Calibra la bussola',
                illustration: GuidanceIllustration.figureEight,
                steps: const [
                  'Allontanati prima da antenna e oggetti metallici.',
                  'Muovi lentamente il telefono descrivendo una figura a 8.',
                  'Poi riportalo verticale sul lato lungo e lascialo fermo.',
                ],
                actionLabel: 'Ho calibrato: riprova',
                onAction: _restartSensors,
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
    final warming =
        reading == null || reading.state == PointingEngineState.warmingUp;
    final unstable = reading?.state == PointingEngineState.unstable;
    final screenPlaneTilt = _screenPlaneTiltDegrees;
    final isCorrectPose =
        screenPlaneTilt != null && (screenPlaneTilt - 90).abs() <= 18;
    final delta = reading?.horizontalDeltaDegrees;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final leftWidth = (constraints.maxWidth * 0.22)
            .clamp(165.0, 250.0)
            .toDouble();
        final rightWidth = (constraints.maxWidth * 0.27)
            .clamp(205.0, 300.0)
            .toDouble();
        final compassWidth = math.max(
          160.0,
          constraints.maxWidth - leftWidth - rightWidth - gap * 4,
        );
        final compassSize = math.min(
          compassWidth,
          math.max(160.0, constraints.maxHeight - gap * 2),
        );

        return Padding(
          padding: const EdgeInsets.all(gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: leftWidth,
                child: _targetPanel(
                  context,
                  distanceMeters: solution.distanceMeters,
                  targetAzimuthDegrees: solution.initialBearingDegrees,
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Center(
                  child: SizedBox.square(
                    dimension: compassSize,
                    child: CustomPaint(
                      painter: _CompassPainter(
                        headingDegrees: reading?.trueHeadingDegrees ?? 0,
                        targetDeltaDegrees: delta,
                        ready: !warming && !unstable,
                        centered: isCorrectPose && (reading?.centered ?? false),
                        colorScheme: Theme.of(context).colorScheme,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: gap),
              SizedBox(
                width: rightWidth,
                child: _statusPanel(
                  context,
                  reading: reading,
                  warming: warming,
                  unstable: unstable,
                  isCorrectPose: isCorrectPose,
                  screenPlaneTilt: screenPlaneTilt,
                  delta: delta,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _targetPanel(
    BuildContext context, {
    required double distanceMeters,
    required double targetAzimuthDegrees,
  }) => Card(
    margin: EdgeInsets.zero,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.beacon.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('${(distanceMeters / 1000).toStringAsFixed(2)} km'),
          Text(
            'Azimut vero ${targetAzimuthDegrees.toStringAsFixed(1)}°',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Declinazione magnetica '
            '${widget.controller.declinationDegrees.toStringAsFixed(1)}°',
          ),
          const Divider(height: 24),
          const Icon(Icons.screen_rotation_alt),
          const SizedBox(height: 6),
          const Text(
            'Telefono VERTICALE sul LATO LUNGO. Lo schermo resta in landscape; '
            'ruota tutto il telefono a destra o sinistra verso il bersaglio.',
          ),
        ],
      ),
    ),
  );

  Widget _statusPanel(
    BuildContext context, {
    required PointingEngineReading? reading,
    required bool warming,
    required bool unstable,
    required bool isCorrectPose,
    required double? screenPlaneTilt,
    required double? delta,
  }) => Card(
    margin: EdgeInsets.zero,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text(
            _guidance(
              warming: warming,
              unstable: unstable,
              isCorrectPose: isCorrectPose,
              delta: delta,
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _guidanceColor(
                context,
                warming: warming,
                unstable: unstable,
                isCorrectPose: isCorrectPose,
                delta: delta,
              ),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          if (warming)
            LinearProgressIndicator(value: reading?.warmupProgress ?? 0),
          if (reading != null) ...[
            const SizedBox(height: 8),
            Text(
              'Nord vero ${reading.trueHeadingDegrees.toStringAsFixed(1)}°',
              textAlign: TextAlign.center,
            ),
            Text(
              'Differenza '
              '${reading.horizontalDeltaDegrees.toStringAsFixed(1)}°',
              textAlign: TextAlign.center,
            ),
          ],
          if (screenPlaneTilt != null)
            Text(
              'Verticalità schermo ${screenPlaneTilt.toStringAsFixed(1)}° • ideale 90°',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          Text(
            warming
                ? 'Sensore in stabilizzazione'
                : unstable
                ? 'Sensore instabile'
                : 'Letture stabilizzate',
            textAlign: TextAlign.center,
          ),
          if (_showDebugPanel) ...[
            const Divider(height: 24),
            _debugPanel(context, reading),
          ],
          const Divider(height: 24),
          const Text(
            'Lontano da antenna, metallo, magneti e cavi elettrici.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Color _guidanceColor(
    BuildContext context, {
    required bool warming,
    required bool unstable,
    required bool isCorrectPose,
    required double? delta,
  }) {
    final colors = Theme.of(context).colorScheme;
    if (unstable || !isCorrectPose) return colors.error;
    if (warming || delta == null) return colors.primary;
    if (delta.abs() <= 2) return const Color(0xFF63D98A);
    if (delta.abs() >= 45) return const Color(0xFFFF7A6E);
    return const Color(0xFFFFB454);
  }

  void _markVisualReference() {
    final reading = _reading;
    final solution = widget.controller.solution;
    if (reading == null || solution == null) return;

    final tilt = _screenPlaneTiltDegrees;
    final mark = _AzimuthDebugMark(
      timestamp: DateTime.now(),
      rawMagneticHeadingDegrees: _rawMagneticHeadingDegrees,
      engineMagneticHeadingDegrees: reading.magneticHeadingDegrees,
      engineTrueHeadingDegrees: reading.trueHeadingDegrees,
      targetAzimuthDegrees: solution.initialBearingDegrees,
      deltaDegrees: reading.horizontalDeltaDegrees,
      screenPlaneTiltDegrees: tilt,
      correctVerticalLongEdgePose: tilt != null && (tilt - 90).abs() <= 18,
      engineState: reading.state.name,
    );

    setState(() => _debugMarks.add(mark));
    unawaited(_persistDebugLog());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bandierina #${_debugMarks.length}: errore '
          '${mark.deltaDegrees.toStringAsFixed(2)}°',
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Widget _debugPanel(BuildContext context, PointingEngineReading? reading) {
    final solution = widget.controller.solution;
    final tilt = _screenPlaneTiltDegrees;
    final poseOk = tilt != null && (tilt - 90).abs() <= 18;

    Text line(String label, String value) => Text(
      '$label: $value',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );

    return Column(
      children: [
        Text(
          'DEBUG AZIMUT • MOTORE 2.2 INVARIATO',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        line(
          'RAW magnetico',
          _rawMagneticHeadingDegrees == null
              ? '—'
              : '${_rawMagneticHeadingDegrees!.toStringAsFixed(2)}°',
        ),
        line(
          'Engine magnetico',
          reading == null
              ? '—'
              : '${reading.magneticHeadingDegrees.toStringAsFixed(2)}°',
        ),
        line(
          'Nord vero',
          reading == null
              ? '—'
              : '${reading.trueHeadingDegrees.toStringAsFixed(2)}°',
        ),
        line(
          'Target vero',
          solution == null
              ? '—'
              : '${solution.initialBearingDegrees.toStringAsFixed(2)}°',
        ),
        line(
          'Delta',
          reading == null
              ? '—'
              : '${reading.horizontalDeltaDegrees.toStringAsFixed(2)}°',
        ),
        line(
          'Posa',
          tilt == null
              ? '—'
              : '${tilt.toStringAsFixed(1)}° • ${poseOk ? "OK" : "NO"}',
        ),
        line('Stato', reading?.state.name ?? '—'),
        line('Bandierine', '${_debugMarks.length}'),
        const SizedBox(height: 6),
        Text(
          'Bandierina ed export sono nei pulsanti in alto.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _debugLogText() {
    final solution = widget.controller.solution;
    final location = widget.controller.location;
    final buffer = StringBuffer()
      ..writeln('GPS POINTER • AZIMUT DEBUG VERTICAL LONG EDGE')
      ..writeln('engine=release-2.2 unchanged')
      ..writeln('session_started=${_debugSessionStartedAt.toIso8601String()}')
      ..writeln('beacon=${widget.beacon.name}')
      ..writeln(
        'target_true_deg=${solution?.initialBearingDegrees.toStringAsFixed(6) ?? ""}',
      )
      ..writeln(
        'declination_deg=${widget.controller.declinationDegrees.toStringAsFixed(6)}',
      )
      ..writeln('observer_lat=${location?.latitude.toStringAsFixed(7) ?? ""}')
      ..writeln('observer_lon=${location?.longitude.toStringAsFixed(7) ?? ""}')
      ..writeln('marks=${_debugMarks.length}')
      ..writeln();

    for (var index = 0; index < _debugMarks.length; index++) {
      final mark = _debugMarks[index];
      buffer
        ..writeln('FLAG ${index + 1}')
        ..writeln('time=${mark.timestamp.toIso8601String()}')
        ..writeln(
          'raw_magnetic_deg=${mark.rawMagneticHeadingDegrees?.toStringAsFixed(6) ?? ""}',
        )
        ..writeln(
          'engine_magnetic_deg=${mark.engineMagneticHeadingDegrees.toStringAsFixed(6)}',
        )
        ..writeln(
          'engine_true_deg=${mark.engineTrueHeadingDegrees.toStringAsFixed(6)}',
        )
        ..writeln(
          'target_true_deg=${mark.targetAzimuthDegrees.toStringAsFixed(6)}',
        )
        ..writeln('delta_deg=${mark.deltaDegrees.toStringAsFixed(6)}')
        ..writeln(
          'screen_plane_tilt_deg=${mark.screenPlaneTiltDegrees?.toStringAsFixed(6) ?? ""}',
        )
        ..writeln(
          'vertical_long_edge_pose_ok=${mark.correctVerticalLongEdgePose}',
        )
        ..writeln('engine_state=${mark.engineState}')
        ..writeln();
    }
    return buffer.toString();
  }

  Future<void> _persistDebugLog() async {
    if (_debugMarks.isEmpty) return;
    await DiagnosticLogStore.writeText(
      category: 'Azimut',
      subject: widget.beacon.name,
      content: _debugLogText(),
      timestamp: _debugSessionStartedAt,
    );
  }

  Future<void> _shareDebugLog() async {
    if (_debugMarks.isEmpty) return;
    final file = await DiagnosticLogStore.writeText(
      category: 'Azimut',
      subject: widget.beacon.name,
      content: _debugLogText(),
      timestamp: _debugSessionStartedAt,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'GPS Pointer Azimut debug ${widget.beacon.name}',
      ),
    );
  }

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  void _updateAudio() {
    final reading = _reading;
    final screenPlaneTilt = _screenPlaneTiltDegrees;
    final correctPose =
        screenPlaneTilt != null && (screenPlaneTilt - 90).abs() <= 18;
    final stable =
        !_showGuide &&
        !_showCalibrationGuide &&
        correctPose &&
        reading?.state == PointingEngineState.ready;
    _audio.update(
      stable: stable,
      centered: stable && (reading?.centered ?? false),
      absoluteErrorDegrees:
          reading?.horizontalDeltaDegrees.abs() ?? double.infinity,
    );
  }

  static String _guidance({
    required bool warming,
    required bool unstable,
    required bool isCorrectPose,
    required double? delta,
  }) {
    if (unstable) return 'Letture instabili: ristabilizza la bussola';
    if (warming || delta == null) return 'Tieni fermo: stabilizzo la bussola';
    if (!isCorrectPose) return 'Metti il telefono VERTICALE sul LATO LUNGO';
    if (delta.abs() <= 2) return 'DIREZIONE CENTRATA';
    return delta > 0
        ? 'Ruota a destra ${delta.abs().round()}°'
        : 'Ruota a sinistra ${delta.abs().round()}°';
  }
}

final class _AzimuthDebugMark {
  const _AzimuthDebugMark({
    required this.timestamp,
    required this.rawMagneticHeadingDegrees,
    required this.engineMagneticHeadingDegrees,
    required this.engineTrueHeadingDegrees,
    required this.targetAzimuthDegrees,
    required this.deltaDegrees,
    required this.screenPlaneTiltDegrees,
    required this.correctVerticalLongEdgePose,
    required this.engineState,
  });

  final DateTime timestamp;
  final double? rawMagneticHeadingDegrees;
  final double engineMagneticHeadingDegrees;
  final double engineTrueHeadingDegrees;
  final double targetAzimuthDegrees;
  final double deltaDegrees;
  final double? screenPlaneTiltDegrees;
  final bool correctVerticalLongEdgePose;
  final String engineState;
}

final class _CompassPainter extends CustomPainter {
  const _CompassPainter({
    required this.headingDegrees,
    required this.targetDeltaDegrees,
    required this.ready,
    required this.centered,
    required this.colorScheme,
  });

  final double headingDegrees;
  final double? targetDeltaDegrees;
  final bool ready;
  final bool centered;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final delta = targetDeltaDegrees;
    if (ready && delta != null && delta.abs() <= 15) {
      _paintPrecisionArc(canvas, size, delta);
    } else {
      _paintFullCompass(canvas, size);
    }
  }

  void _paintFullCompass(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.43;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colorScheme.outline;
    canvas.drawCircle(center, radius, ring);

    const toleranceDegrees = 3.0;
    final tolerancePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF63D98A).withValues(alpha: 0.55);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2 - toleranceDegrees * math.pi / 180,
      toleranceDegrees * 2 * math.pi / 180,
      false,
      tolerancePaint,
    );

    for (var degrees = 0; degrees < 360; degrees += 10) {
      final relative = (degrees - headingDegrees) * math.pi / 180;
      final major = degrees % 30 == 0;
      final outer = _polar(center, radius, relative);
      final inner = _polar(center, radius - (major ? 18 : 9), relative);
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = major ? 2 : 1
          ..color = colorScheme.onSurfaceVariant,
      );
    }

    const cardinals = <int, String>{0: 'N', 90: 'E', 180: 'S', 270: 'O'};
    for (final entry in cardinals.entries) {
      final relative = (entry.key - headingDegrees) * math.pi / 180;
      final position = _polar(center, radius - 38, relative);
      final painter = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: TextStyle(
            color: entry.key == 0 ? colorScheme.error : colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }

    _paintReferenceArrow(canvas, center, radius);
    if (ready && targetDeltaDegrees != null) {
      final radians = targetDeltaDegrees! * math.pi / 180;
      _paintTarget(canvas, center, radius - 6, radians);
    }
    canvas.drawCircle(center, 7, Paint()..color = colorScheme.primary);
  }

  void _paintPrecisionArc(Canvas canvas, Size size, double delta) {
    final veryClose = delta.abs() <= 5;
    final visibleRange = veryClose ? 6.0 : 20.0;
    final tickStep = veryClose ? 1.0 : 5.0;
    final halfSweep = 62.0 * math.pi / 180;
    final center = Offset(size.width / 2, size.height * 0.76);
    final radius = math.min(size.width * 0.47, size.height * 0.70);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = colorScheme.outline;
    canvas.drawArc(rect, -math.pi / 2 - halfSweep, halfSweep * 2, false, ring);

    final green = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF63D98A).withValues(alpha: 0.55);
    final greenHalf = (2.0 / visibleRange) * halfSweep;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2 - greenHalf,
      greenHalf * 2,
      false,
      green,
    );

    for (double d = -visibleRange; d <= visibleRange + 0.001; d += tickStep) {
      final angle = -math.pi / 2 + (d / visibleRange) * halfSweep;
      final major = d.abs() < 0.001 || ((d / tickStep).round().abs() % 2 == 0);
      final outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final innerRadius = radius - (major ? 22 : 12);
      final inner = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = major ? 2.5 : 1.5
          ..color = colorScheme.onSurfaceVariant,
      );
      if (major) {
        final label = d == 0 ? '0°' : '${d > 0 ? '+' : ''}${d.toInt()}°';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: d == 0 ? FontWeight.bold : FontWeight.w500,
              fontSize: veryClose ? 15 : 13,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lr = radius - 42;
        final pos = Offset(
          center.dx + math.cos(angle) * lr,
          center.dy + math.sin(angle) * lr,
        );
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }

    _paintReferenceArrow(canvas, center, radius);
    final clamped = delta.clamp(-visibleRange, visibleRange).toDouble();
    final targetAngle = -math.pi / 2 + (clamped / visibleRange) * halfSweep;
    _paintTarget(canvas, center, radius - 4, targetAngle + math.pi / 2);

    final modeText = veryClose ? 'PRECISIONE ±6°' : 'AVVICINAMENTO ±20°';
    final tp = TextPainter(
      text: TextSpan(
        text: modeText,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + 18));
  }

  void _paintReferenceArrow(Canvas canvas, Offset center, double radius) {
    final arrow = Path()
      ..moveTo(center.dx, center.dy - radius + 6)
      ..lineTo(center.dx - 11, center.dy - radius + 30)
      ..lineTo(center.dx + 11, center.dy - radius + 30)
      ..close();
    final correctionColor = centered
        ? const Color(0xFF63D98A)
        : const Color(0xFFFFB454);
    canvas.drawPath(arrow, Paint()..color = correctionColor);
  }

  void _paintTarget(
    Canvas canvas,
    Offset center,
    double radius,
    double radiansFromNorth,
  ) {
    final target = _polar(center, radius, radiansFromNorth);
    final targetColor = centered
        ? const Color(0xFF63D98A)
        : colorScheme.primary;
    canvas.drawCircle(
      target,
      22,
      Paint()..color = targetColor.withValues(alpha: 0.20),
    );
    canvas.drawCircle(target, 15, Paint()..color = targetColor);
    canvas.drawCircle(target, 7, Paint()..color = colorScheme.surface);
  }

  static Offset _polar(Offset center, double radius, double degreesFromNorth) =>
      Offset(
        center.dx + math.sin(degreesFromNorth) * radius,
        center.dy - math.cos(degreesFromNorth) * radius,
      );

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) =>
      oldDelegate.headingDegrees != headingDegrees ||
      oldDelegate.targetDeltaDegrees != targetDeltaDegrees ||
      oldDelegate.ready != ready ||
      oldDelegate.centered != centered ||
      oldDelegate.colorScheme != colorScheme;
}
