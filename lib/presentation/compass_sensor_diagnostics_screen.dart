import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../application/diagnostic_log_store.dart';

enum _DiagnosticPose { verticalLongEdge, horizontal, flatScreenUp }

final class CompassSensorDiagnosticsScreen extends StatefulWidget {
  const CompassSensorDiagnosticsScreen({super.key});

  @override
  State<CompassSensorDiagnosticsScreen> createState() =>
      _CompassSensorDiagnosticsScreenState();
}

final class _CompassSensorDiagnosticsScreenState
    extends State<CompassSensorDiagnosticsScreen> {
  static const MethodChannel _deviceChannel = MethodChannel(
    'io.github.fraidotube.gpspointer/device_orientation',
  );
  static const EventChannel _rotationVectorChannel = EventChannel(
    'io.github.fraidotube.gpspointer/rotation_vector',
  );

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<dynamic>? _rotationVectorSubscription;

  Map<String, Object?> _deviceInfo = const <String, Object?>{};
  _DiagnosticPose _pose = _DiagnosticPose.verticalLongEdge;
  double? _heading;
  double? _headingForCamera;
  double? _compassAccuracy;
  AccelerometerEvent? _accelerometer;
  MagnetometerEvent? _magnetometer;
  GyroscopeEvent? _gyroscope;
  _RotationVectorReading? _rotationVector;
  String? _rotationVectorError;

  final List<_DirectionCapture> _captures = <_DirectionCapture>[];
  final List<double> _captureHeadingSamples = <double>[];
  final List<double> _captureCameraHeadingSamples = <double>[];
  final List<double> _captureAccuracySamples = <double>[];
  final List<double> _captureRvCompassSamples = <double>[];
  final List<double> _captureRvCameraSamples = <double>[];
  bool _capturing = false;
  String? _lastLogPath;
  DateTime _sessionStarted = DateTime.now();

  bool _traceActive = false;
  DateTime? _traceStarted;
  final List<String> _traceLines = <String>[];
  Timer? _traceTimer;

  DateTime? _lastGyroTime;
  double _gyroCumulativeDegrees = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _loadDeviceInfo();
    _startSensors();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final value = await _deviceChannel.invokeMapMethod<String, Object?>(
        'readDeviceInfo',
      );
      if (!mounted) return;
      setState(() => _deviceInfo = value ?? const <String, Object?>{});
    } on PlatformException {
      if (!mounted) return;
      setState(() => _deviceInfo = const <String, Object?>{});
    }
  }

  void _startSensors() {
    _compassSubscription = FlutterCompass.events?.listen(_onCompass);
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((event) => _accelerometer = event);
    _magnetometerSubscription = magnetometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((event) => _magnetometer = event);
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onGyroscope);
    _rotationVectorSubscription = _rotationVectorChannel
        .receiveBroadcastStream()
        .listen(
          _onRotationVector,
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _rotationVectorError = '$error');
          },
        );
  }

  void _onGyroscope(GyroscopeEvent event) {
    _gyroscope = event;
    final now = DateTime.now();
    final previous = _lastGyroTime;
    _lastGyroTime = now;
    if (previous == null) return;
    final dt = now.difference(previous).inMicroseconds / 1000000.0;
    if (dt <= 0 || dt > 0.25) return;
    final rate = switch (_pose) {
      _DiagnosticPose.verticalLongEdge => event.y,
      _DiagnosticPose.horizontal => event.x,
      _DiagnosticPose.flatScreenUp => event.z,
    };
    _gyroCumulativeDegrees += rate * dt * 180 / math.pi;
  }

  void _onRotationVector(dynamic value) {
    if (!mounted || value is! Map) return;
    double? number(String key) {
      final raw = value[key];
      return raw is num ? raw.toDouble() : null;
    }

    final reading = _RotationVectorReading(
      timestampNs: value['timestampNs'] is num
          ? (value['timestampNs'] as num).toInt()
          : null,
      accuracy: value['accuracy'] is num
          ? (value['accuracy'] as num).toInt()
          : null,
      azimuthDegrees: number('azimuthDeg'),
      cameraAzimuthDegrees: number('cameraAzimuthDeg'),
      pitchDegrees: number('pitchDeg'),
      rollDegrees: number('rollDeg'),
      quaternionW: number('quaternionW'),
      quaternionX: number('quaternionX'),
      quaternionY: number('quaternionY'),
      quaternionZ: number('quaternionZ'),
    );
    if (_capturing) {
      if (reading.azimuthDegrees != null) {
        _captureRvCompassSamples.add(_normalize(reading.azimuthDegrees!));
      }
      if (reading.cameraAzimuthDegrees != null) {
        _captureRvCameraSamples.add(_normalize(reading.cameraAzimuthDegrees!));
      }
    }
    setState(() {
      _rotationVector = reading;
      _rotationVectorError = null;
    });
  }

  void _onCompass(CompassEvent event) {
    final heading = event.heading;
    if (!mounted || heading == null) return;

    final cameraHeading = event.headingForCameraMode;
    final accuracy = event.accuracy;

    if (_capturing) {
      _captureHeadingSamples.add(_normalize(heading));
      if (cameraHeading != null) {
        _captureCameraHeadingSamples.add(_normalize(cameraHeading));
      }
      if (accuracy != null && accuracy.isFinite) {
        _captureAccuracySamples.add(accuracy);
      }
    }

    if (_traceActive) {
      _traceLines.add(_traceLine(event));
    }

    setState(() {
      _heading = _normalize(heading);
      _headingForCamera = cameraHeading == null
          ? null
          : _normalize(cameraHeading);
      _compassAccuracy = accuracy;
    });
  }

  Future<void> _resetTest(_DiagnosticPose pose) async {
    if (_capturing || _traceActive) return;
    setState(() {
      _pose = pose;
      _captures.clear();
      _sessionStarted = DateTime.now();
      _lastLogPath = null;
      _gyroCumulativeDegrees = 0;
      _lastGyroTime = null;
    });
  }

  bool _poseIsValid() {
    final a = _accelerometer;
    if (a == null) return false;
    final ax = a.x.abs();
    final ay = a.y.abs();
    final az = a.z.abs();
    return switch (_pose) {
      _DiagnosticPose.verticalLongEdge => ay >= 7.0 && ax <= 5.0 && az <= 5.0,
      _DiagnosticPose.horizontal => ax >= 7.0 && ay <= 5.0 && az <= 5.0,
      _DiagnosticPose.flatScreenUp => az >= 7.0 && ax <= 5.0 && ay <= 5.0,
    };
  }

  String _poseInstruction() => switch (_pose) {
    _DiagnosticPose.verticalLongEdge =>
      'Telefono verticale portrait, lato lungo in piedi, camera davanti a te.',
    _DiagnosticPose.horizontal =>
      'Telefono landscape, lato lungo orizzontale, camera davanti a te.',
    _DiagnosticPose.flatScreenUp =>
      'Telefono di piatto, schermo verso il cielo; il bordo superiore indica la direzione.',
  };

  Future<void> _captureDirection() async {
    if (_capturing || _traceActive || _captures.length >= 4) return;
    if (_heading == null) {
      _message('La bussola non sta ancora fornendo un heading.');
      return;
    }
    if (!_poseIsValid()) {
      _message(
        'Posa non coerente con il test selezionato. ${_poseInstruction()}',
      );
      return;
    }

    setState(() {
      _capturing = true;
      _captureHeadingSamples.clear();
      _captureCameraHeadingSamples.clear();
      _captureAccuracySamples.clear();
      _captureRvCompassSamples.clear();
      _captureRvCameraSamples.clear();
    });

    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    if (!_poseIsValid()) {
      setState(() => _capturing = false);
      _message(
        'Posa cambiata durante il campionamento: posizione non salvata.',
      );
      return;
    }

    final heading = _circularMean(_captureHeadingSamples) ?? _heading!;
    final cameraHeading = _circularMean(_captureCameraHeadingSamples);
    final accuracy = _mean(_captureAccuracySamples) ?? _compassAccuracy;
    final capture = _DirectionCapture(
      index: _captures.length + 1,
      timestamp: DateTime.now(),
      headingDegrees: heading,
      headingForCameraDegrees: cameraHeading,
      compassAccuracy: accuracy,
      rotationVectorCompassDegrees: _circularMean(_captureRvCompassSamples),
      rotationVectorCameraDegrees: _circularMean(_captureRvCameraSamples),
      gyroCumulativeDegrees: _gyroCumulativeDegrees,
      uiOrientation: MediaQuery.orientationOf(context).name,
      accelerometer: _accelerometer,
      magnetometer: _magnetometer,
      gyroscope: _gyroscope,
      sampleCount: _captureHeadingSamples.length,
      rotationVectorSampleCount: math.max(
        _captureRvCompassSamples.length,
        _captureRvCameraSamples.length,
      ),
    );

    setState(() {
      _captures.add(capture);
      _capturing = false;
    });
    await _persistGuidedTest();
  }

  Future<void> _startTrace() async {
    if (_traceActive || _capturing) return;
    if (_heading == null) {
      _message('La bussola non sta ancora fornendo un heading.');
      return;
    }
    if (!_poseIsValid()) {
      _message(
        'Posa non coerente con il test selezionato. ${_poseInstruction()}',
      );
      return;
    }

    setState(() {
      _traceActive = true;
      _traceStarted = DateTime.now();
      _traceLines.clear();
      _gyroCumulativeDegrees = 0;
      _lastGyroTime = null;
    });
    _traceTimer?.cancel();
    _traceTimer = Timer(const Duration(seconds: 30), () {
      unawaited(_finishTrace());
    });
  }

  Future<void> _finishTrace() async {
    if (!_traceActive) return;
    _traceTimer?.cancel();
    _traceTimer = null;
    final started = _traceStarted ?? DateTime.now();
    setState(() => _traceActive = false);

    final content = <String>[
      'GPS POINTER • SENSOR TRACE 30S • BUILD 42',
      'engine=NOT_USED',
      'session_started=${started.toIso8601String()}',
      'pose=${_pose.name}',
      ..._deviceInfoLines(),
      'rotation_vector_error=${_rotationVectorError ?? ""}',
      'samples=${_traceLines.length}',
      'gyro_integrated_deg=${_gyroCumulativeDegrees.toStringAsFixed(6)}',
      '',
      ..._traceLines,
    ].join('\n');
    final file = await DiagnosticLogStore.writeText(
      category: 'SensorTrace',
      subject: '${_deviceSubject()}_${_pose.name}',
      content: content,
      timestamp: started,
    );
    if (!mounted) return;
    setState(() => _lastLogPath = file.path);
    _message('Traccia sensori 30 s salvata (${_traceLines.length} campioni).');
  }

  Future<void> _persistGuidedTest() async {
    if (_captures.isEmpty) return;
    final content = _guidedLogText();
    final file = await DiagnosticLogStore.writeText(
      category: 'Compass4x90',
      subject: '${_deviceSubject()}_${_pose.name}',
      content: content,
      timestamp: _sessionStarted,
    );
    if (!mounted) return;
    setState(() => _lastLogPath = file.path);
  }

  Future<void> _shareLastLog() async {
    final path = _lastLogPath;
    if (path == null) {
      _message('Non c’è ancora un log da condividere.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'GPS Pointer diagnostica bussola',
      ),
    );
  }

  double? _rvReference(_DirectionCapture capture) =>
      _pose == _DiagnosticPose.flatScreenUp
      ? capture.rotationVectorCompassDegrees
      : capture.rotationVectorCameraDegrees;

  String _guidedLogText() {
    final compassSteps = _stepDeltas(
      _captures.map((capture) => capture.headingDegrees).toList(),
    );
    final rvValues = _captures.map(_rvReference).toList();
    final rvSteps = rvValues.every((value) => value != null)
        ? _stepDeltas(rvValues.cast<double>())
        : const <double>[];
    final compassErrors = compassSteps
        .map((value) => (value.abs() - 90).abs())
        .toList();
    final rvErrors = rvSteps.map((value) => (value.abs() - 90).abs()).toList();

    final buffer = StringBuffer()
      ..writeln('GPS POINTER • COMPASS 4x90 DIAGNOSTIC • BUILD 42')
      ..writeln('engine=NOT_USED')
      ..writeln('session_started=${_sessionStarted.toIso8601String()}')
      ..writeln('pose=${_pose.name}')
      ..writeln(
        'rv_reference=${_pose == _DiagnosticPose.flatScreenUp ? "device_top_edge" : "camera_axis"}',
      );
    for (final line in _deviceInfoLines()) {
      buffer.writeln(line);
    }
    buffer
      ..writeln('captures=${_captures.length}')
      ..writeln('criterion=diagnostic_only_expected_step_90deg')
      ..writeln();

    for (final capture in _captures) {
      buffer
        ..writeln('POSITION ${capture.index}')
        ..writeln('time=${capture.timestamp.toIso8601String()}')
        ..writeln('ui_orientation=${capture.uiOrientation}')
        ..writeln('pose_valid=${_capturePoseValid(capture)}')
        ..writeln('heading_deg=${capture.headingDegrees.toStringAsFixed(6)}')
        ..writeln(
          'heading_for_camera_deg=${capture.headingForCameraDegrees?.toStringAsFixed(6) ?? ""}',
        )
        ..writeln(
          'compass_accuracy=${capture.compassAccuracy?.toStringAsFixed(6) ?? ""}',
        )
        ..writeln(
          'rotation_vector_compass_deg=${capture.rotationVectorCompassDegrees?.toStringAsFixed(6) ?? ""}',
        )
        ..writeln(
          'rotation_vector_camera_deg=${capture.rotationVectorCameraDegrees?.toStringAsFixed(6) ?? ""}',
        )
        ..writeln(
          'gyro_cumulative_deg=${capture.gyroCumulativeDegrees.toStringAsFixed(6)}',
        )
        ..writeln('heading_samples=${capture.sampleCount}')
        ..writeln(
          'rotation_vector_samples=${capture.rotationVectorSampleCount}',
        )
        ..writeln('accelerometer=${_xyz(capture.accelerometer)}')
        ..writeln('magnetometer=${_xyz(capture.magnetometer)}')
        ..writeln('gyroscope=${_xyz(capture.gyroscope)}')
        ..writeln();
    }

    for (var index = 0; index < compassSteps.length; index++) {
      final to = index == 3 ? 1 : index + 2;
      final gyro = index < 3
          ? _captures[index + 1].gyroCumulativeDegrees -
                _captures[index].gyroCumulativeDegrees
          : null;
      final rv = rvSteps.isEmpty ? null : rvSteps[index];
      buffer.writeln(
        'STEP ${index + 1}->$to '
        'flutter_signed_deg=${compassSteps[index].toStringAsFixed(6)} '
        'flutter_abs_deg=${compassSteps[index].abs().toStringAsFixed(6)} '
        'flutter_error90_deg=${compassErrors[index].toStringAsFixed(6)} '
        'rv_signed_deg=${rv?.toStringAsFixed(6) ?? ""} '
        'rv_abs_deg=${rv?.abs().toStringAsFixed(6) ?? ""} '
        'rv_error90_deg=${rv == null ? "" : rvErrors[index].toStringAsFixed(6)} '
        'gyro_measured_deg=${gyro?.toStringAsFixed(6) ?? "NOT_MEASURED"}',
      );
    }
    if (compassErrors.isNotEmpty) {
      buffer
        ..writeln(
          'flutter_mean_error90_deg=${_mean(compassErrors)!.toStringAsFixed(6)}',
        )
        ..writeln(
          'flutter_max_error90_deg=${compassErrors.reduce(math.max).toStringAsFixed(6)}',
        );
    }
    if (rvErrors.isNotEmpty) {
      buffer
        ..writeln('rv_mean_error90_deg=${_mean(rvErrors)!.toStringAsFixed(6)}')
        ..writeln(
          'rv_max_error90_deg=${rvErrors.reduce(math.max).toStringAsFixed(6)}',
        );
    }
    return buffer.toString();
  }

  bool _capturePoseValid(_DirectionCapture capture) {
    final a = capture.accelerometer;
    if (a == null) return false;
    final ax = a.x.abs();
    final ay = a.y.abs();
    final az = a.z.abs();
    return switch (_pose) {
      _DiagnosticPose.verticalLongEdge => ay >= 7.0 && ax <= 5.0 && az <= 5.0,
      _DiagnosticPose.horizontal => ax >= 7.0 && ay <= 5.0 && az <= 5.0,
      _DiagnosticPose.flatScreenUp => az >= 7.0 && ax <= 5.0 && ay <= 5.0,
    };
  }

  List<double> _stepDeltas(List<double> values) {
    if (values.length < 4) return const <double>[];
    return <double>[
      _signedDelta(values[0], values[1]),
      _signedDelta(values[1], values[2]),
      _signedDelta(values[2], values[3]),
      _signedDelta(values[3], values[0]),
    ];
  }

  List<String> _deviceInfoLines() {
    const keys = <String>[
      'manufacturer',
      'model',
      'device',
      'androidRelease',
      'sdkInt',
      'magnetometerName',
      'magnetometerVendor',
      'accelerometerName',
      'accelerometerVendor',
      'gyroscopeName',
      'gyroscopeVendor',
      'rotationVectorName',
      'geomagneticRotationVectorName',
    ];
    return [for (final key in keys) '$key=${_deviceInfo[key] ?? ""}'];
  }

  String _deviceSubject() {
    final manufacturer = '${_deviceInfo['manufacturer'] ?? 'Android'}';
    final model = '${_deviceInfo['model'] ?? 'device'}';
    return '${manufacturer}_$model';
  }

  String _traceLine(CompassEvent event) {
    final now = DateTime.now();
    final orientation = mounted ? MediaQuery.orientationOf(context).name : '';
    final rv = _rotationVector;
    return [
      'time=${now.toIso8601String()}',
      'ui_orientation=$orientation',
      'pose_valid=${_poseIsValidForTrace()}',
      'heading_deg=${event.heading?.toStringAsFixed(6) ?? ""}',
      'heading_for_camera_deg=${event.headingForCameraMode?.toStringAsFixed(6) ?? ""}',
      'compass_accuracy=${event.accuracy?.toStringAsFixed(6) ?? ""}',
      'rv_compass_deg=${rv?.azimuthDegrees?.toStringAsFixed(6) ?? ""}',
      'rv_camera_deg=${rv?.cameraAzimuthDegrees?.toStringAsFixed(6) ?? ""}',
      'rv_pitch_deg=${rv?.pitchDegrees?.toStringAsFixed(6) ?? ""}',
      'rv_roll_deg=${rv?.rollDegrees?.toStringAsFixed(6) ?? ""}',
      'rv_accuracy=${rv?.accuracy ?? ""}',
      'gyro_integrated_deg=${_gyroCumulativeDegrees.toStringAsFixed(6)}',
      'accelerometer=${_xyz(_accelerometer)}',
      'magnetometer=${_xyz(_magnetometer)}',
      'gyroscope=${_xyz(_gyroscope)}',
    ].join(' | ');
  }

  bool _poseIsValidForTrace() => _poseIsValid();

  @override
  void dispose() {
    _traceTimer?.cancel();
    unawaited(_compassSubscription?.cancel());
    unawaited(_accelerometerSubscription?.cancel());
    unawaited(_magnetometerSubscription?.cancel());
    unawaited(_gyroscopeSubscription?.cancel());
    unawaited(_rotationVectorSubscription?.cancel());
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
  Widget build(BuildContext context) {
    final compassSteps = _stepDeltas(
      _captures.map((capture) => capture.headingDegrees).toList(),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostica bussola BETA'),
        actions: [
          IconButton(
            onPressed: _lastLogPath == null ? null : _shareLastLog,
            tooltip: 'Condividi ultimo TXT',
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
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
                      'Test sensori indipendente dal motore',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Questa schermata NON usa PointingEngineV2 e non applica '
                      'offset o calibrazioni. Build 42 confronta FlutterCompass, '
                      'Rotation Vector Android e giroscopio.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _deviceCard(context),
            const SizedBox(height: 10),
            _liveCard(context),
            const SizedBox(height: 10),
            SegmentedButton<_DiagnosticPose>(
              segments: const [
                ButtonSegment(
                  value: _DiagnosticPose.verticalLongEdge,
                  label: Text('Verticale'),
                  icon: Icon(Icons.stay_current_portrait),
                ),
                ButtonSegment(
                  value: _DiagnosticPose.horizontal,
                  label: Text('Orizz.'),
                  icon: Icon(Icons.stay_current_landscape),
                ),
                ButtonSegment(
                  value: _DiagnosticPose.flatScreenUp,
                  label: Text('Piatto'),
                  icon: Icon(Icons.screen_rotation_alt),
                ),
              ],
              selected: {_pose},
              onSelectionChanged: _capturing || _traceActive
                  ? null
                  : (selection) => _resetTest(selection.first),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  _poseIsValid()
                      ? Icons.check_circle_outline
                      : Icons.warning_amber,
                ),
                title: Text(
                  _poseIsValid() ? 'Posa corretta' : 'Posa da correggere',
                ),
                subtitle: Text(_poseInstruction()),
              ),
            ),
            const SizedBox(height: 10),
            _guidedTestCard(context, compassSteps),
            const SizedBox(height: 10),
            _traceCard(context),
          ],
        ),
      ),
    );
  }

  Widget _deviceCard(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.phone_android),
      title: Text(
        '${_deviceInfo['manufacturer'] ?? 'Android'} '
        '${_deviceInfo['model'] ?? 'dispositivo'}',
      ),
      subtitle: Text(
        'Android ${_deviceInfo['androidRelease'] ?? '?'} '
        '• API ${_deviceInfo['sdkInt'] ?? '?'}\n'
        'Mag: ${_deviceInfo['magnetometerName'] ?? 'non rilevato'}\n'
        'Rotation Vector: ${_deviceInfo['rotationVectorName'] ?? 'non rilevato'}',
      ),
      isThreeLine: true,
    ),
  );

  Widget _liveCard(BuildContext context) {
    final rv = _rotationVector;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Valori live', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Flutter heading: ${_deg(_heading)}'),
            Text('Flutter camera: ${_deg(_headingForCamera)}'),
            Text('Accuracy plugin: ${_num(_compassAccuracy)}'),
            const Divider(),
            Text('RV bussola/top edge: ${_deg(rv?.azimuthDegrees)}'),
            Text('RV camera axis: ${_deg(rv?.cameraAzimuthDegrees)}'),
            Text(
              'RV pitch/roll: ${_deg(rv?.pitchDegrees)} / ${_deg(rv?.rollDegrees)}',
            ),
            Text('RV accuracy Android: ${rv?.accuracy ?? '—'}'),
            if (_rotationVectorError != null)
              Text('RV errore: $_rotationVectorError'),
            const Divider(),
            Text(
              'Gyro integrato (${_gyroAxisLabel()}): ${_gyroCumulativeDegrees.toStringAsFixed(2)}°',
            ),
            Text('Mag XYZ: ${_xyz(_magnetometer)}'),
            Text('Acc XYZ: ${_xyz(_accelerometer)}'),
            Text('Gyro XYZ: ${_xyz(_gyroscope)}'),
          ],
        ),
      ),
    );
  }

  String _gyroAxisLabel() => switch (_pose) {
    _DiagnosticPose.verticalLongEdge => 'Y',
    _DiagnosticPose.horizontal => 'X',
    _DiagnosticPose.flatScreenUp => 'Z',
  };

  Widget _guidedTestCard(BuildContext context, List<double> compassSteps) {
    final next = _captures.length + 1;
    final complete = _captures.length == 4;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Test guidato 4 direzioni',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              complete
                  ? 'Test completato. Condividi il TXT oppure passa a un’altra posa.'
                  : next == 1
                  ? 'Imposta la posa indicata sopra, scegli una direzione e tieni il telefono fermo.'
                  : 'Ruota fisicamente di circa 90° verso destra mantenendo la stessa posa, poi fermati.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  complete || _capturing || _traceActive || !_poseIsValid()
                  ? null
                  : _captureDirection,
              icon: _capturing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.flag_outlined),
              label: Text(
                _capturing ? 'Campiono 1,8 s…' : 'REGISTRA POSIZIONE $next',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _capturing || _traceActive
                  ? null
                  : () => _resetTest(_pose),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Azzera test'),
            ),
            if (_captures.isNotEmpty) ...[
              const Divider(height: 24),
              for (final capture in _captures)
                Text(
                  'P${capture.index}: Flutter ${capture.headingDegrees.toStringAsFixed(1)}° '
                  '• RV ${_rvReference(capture)?.toStringAsFixed(1) ?? '—'}° '
                  '• Gyro ${capture.gyroCumulativeDegrees.toStringAsFixed(1)}°',
                ),
            ],
            if (compassSteps.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Scarti FlutterCompass tra le 4 direzioni:'),
              for (var i = 0; i < compassSteps.length; i++)
                Text(
                  'Step ${i + 1}: ${compassSteps[i].abs().toStringAsFixed(1)}° '
                  '• errore da 90° ${(compassSteps[i].abs() - 90).abs().toStringAsFixed(1)}°',
                ),
              const SizedBox(height: 8),
              const Text(
                'Il TXT contiene anche gli stessi step del Rotation Vector e '
                'la rotazione relativa del giroscopio per gli step realmente percorsi.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _traceCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Traccia continua',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Registra 30 secondi di FlutterCompass, Rotation Vector, giroscopio '
            'integrato e sensori grezzi. Mantieni la posa selezionata.',
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _capturing || (!_traceActive && !_poseIsValid())
                ? null
                : _traceActive
                ? _finishTrace
                : _startTrace,
            icon: Icon(
              _traceActive ? Icons.stop_circle_outlined : Icons.sensors,
            ),
            label: Text(
              _traceActive
                  ? 'FERMA E SALVA (${_traceLines.length} campioni)'
                  : 'REGISTRA TRACCIA 30 s',
            ),
          ),
        ],
      ),
    ),
  );

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static double _normalize(double value) {
    final result = value % 360;
    return result < 0 ? result + 360 : result;
  }

  static double _signedDelta(double from, double to) =>
      ((_normalize(to) - _normalize(from) + 540) % 360) - 180;

  static double? _circularMean(List<double> values) {
    if (values.isEmpty) return null;
    var sinSum = 0.0;
    var cosSum = 0.0;
    for (final value in values) {
      final radians = value * math.pi / 180;
      sinSum += math.sin(radians);
      cosSum += math.cos(radians);
    }
    return _normalize(math.atan2(sinSum, cosSum) * 180 / math.pi);
  }

  static double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static String _deg(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(2)}°';

  static String _num(double? value) =>
      value == null ? '—' : value.toStringAsFixed(2);

  static String _xyz(Object? event) {
    if (event is AccelerometerEvent) {
      return '${event.x.toStringAsFixed(4)},${event.y.toStringAsFixed(4)},${event.z.toStringAsFixed(4)}';
    }
    if (event is MagnetometerEvent) {
      return '${event.x.toStringAsFixed(4)},${event.y.toStringAsFixed(4)},${event.z.toStringAsFixed(4)}';
    }
    if (event is GyroscopeEvent) {
      return '${event.x.toStringAsFixed(4)},${event.y.toStringAsFixed(4)},${event.z.toStringAsFixed(4)}';
    }
    return '';
  }
}

final class _RotationVectorReading {
  const _RotationVectorReading({
    required this.timestampNs,
    required this.accuracy,
    required this.azimuthDegrees,
    required this.cameraAzimuthDegrees,
    required this.pitchDegrees,
    required this.rollDegrees,
    required this.quaternionW,
    required this.quaternionX,
    required this.quaternionY,
    required this.quaternionZ,
  });

  final int? timestampNs;
  final int? accuracy;
  final double? azimuthDegrees;
  final double? cameraAzimuthDegrees;
  final double? pitchDegrees;
  final double? rollDegrees;
  final double? quaternionW;
  final double? quaternionX;
  final double? quaternionY;
  final double? quaternionZ;
}

final class _DirectionCapture {
  const _DirectionCapture({
    required this.index,
    required this.timestamp,
    required this.headingDegrees,
    required this.headingForCameraDegrees,
    required this.compassAccuracy,
    required this.rotationVectorCompassDegrees,
    required this.rotationVectorCameraDegrees,
    required this.gyroCumulativeDegrees,
    required this.uiOrientation,
    required this.accelerometer,
    required this.magnetometer,
    required this.gyroscope,
    required this.sampleCount,
    required this.rotationVectorSampleCount,
  });

  final int index;
  final DateTime timestamp;
  final double headingDegrees;
  final double? headingForCameraDegrees;
  final double? compassAccuracy;
  final double? rotationVectorCompassDegrees;
  final double? rotationVectorCameraDegrees;
  final double gyroCumulativeDegrees;
  final String uiOrientation;
  final AccelerometerEvent? accelerometer;
  final MagnetometerEvent? magnetometer;
  final GyroscopeEvent? gyroscope;
  final int sampleCount;
  final int rotationVectorSampleCount;
}
