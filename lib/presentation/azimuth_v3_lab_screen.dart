import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../application/catalogue_controller.dart';
import '../application/diagnostic_log_store.dart';
import '../core/domain/geo_point.dart';
import '../core/domain/radio_beacon.dart';
import '../core/geo/geo_calculator.dart';
import '../core/geo/pointing_engine_v2.dart';
import '../core/geo/pointing_engine_v3_experimental.dart';

final class AzimuthV3LabScreen extends StatefulWidget {
  const AzimuthV3LabScreen({required this.controller, super.key});

  final CatalogueController controller;

  @override
  State<AzimuthV3LabScreen> createState() => _AzimuthV3LabScreenState();
}

final class _AzimuthV3LabScreenState extends State<AzimuthV3LabScreen> {
  static const MethodChannel _deviceChannel = MethodChannel(
    'io.github.fraidotube.gpspointer/device_orientation',
  );

  final PointingEngineV3Experimental _v3 = PointingEngineV3Experimental();
  RadioBeacon? _selectedBeacon;

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Timer? _logTimer;
  Timer? _driftTimer;

  final List<_TimedHeading> _absoluteSamples = <_TimedHeading>[];
  final List<String> _logLines = <String>[];

  double? _magneticHeading;
  double? _trueHeading;
  double? _compassAccuracy;
  double _declinationDegrees = 0;
  double? _gravityX;
  double? _gravityY;
  double? _gravityZ;
  double? _projectedYawRateRadiansPerSecond;
  DateTime? _lastGyroTime;

  Position? _observerPosition;
  double? _targetBearingDegrees;
  double? _targetDistanceMeters;
  String? _status;
  bool _busy = false;

  PointingEngineV2? _v2;
  PointingEngineReading? _v2Reading;

  DateTime? _driftStartedAt;
  double? _driftStartGyroHeading;
  double? _driftResultDegrees;
  int _driftRemainingSeconds = 0;
  String? _lastLogPath;

  @override
  void initState() {
    super.initState();
    _startSensors();
    _logTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _appendPeriodicLog(),
    );
  }

  void _startSensors() {
    _compassSubscription = FlutterCompass.events?.listen(_onCompass);
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccelerometer);
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onGyroscope);
  }

  void _onCompass(CompassEvent event) {
    final magnetic = event.heading;
    if (magnetic == null || !magnetic.isFinite) return;
    final trueHeading = PointingEngineV3Experimental.normalize(
      magnetic + _declinationDegrees,
    );
    final now = DateTime.now();
    _absoluteSamples.add(_TimedHeading(now, trueHeading));
    final cutoff = now.subtract(const Duration(seconds: 3));
    _absoluteSamples.removeWhere((sample) => sample.time.isBefore(cutoff));

    final target = _targetBearingDegrees;
    if (target != null) {
      _v2 ??= PointingEngineV2(
        targetAzimuthDegrees: target,
        targetElevationDegrees: 0,
        declinationDegrees: _declinationDegrees,
      );
      _v2Reading = _v2!.update(
        magneticHeadingDegrees: magnetic,
        cameraElevationDegrees: 0,
        timestamp: now,
      );
    }

    if (!mounted) return;
    setState(() {
      _magneticHeading = PointingEngineV3Experimental.normalize(magnetic);
      _trueHeading = trueHeading;
      _compassAccuracy = event.accuracy;
    });
  }

  void _onAccelerometer(AccelerometerEvent event) {
    const alpha = 0.90;
    _gravityX = _gravityX == null
        ? event.x
        : alpha * _gravityX! + (1 - alpha) * event.x;
    _gravityY = _gravityY == null
        ? event.y
        : alpha * _gravityY! + (1 - alpha) * event.y;
    _gravityZ = _gravityZ == null
        ? event.z
        : alpha * _gravityZ! + (1 - alpha) * event.z;
  }

  void _onGyroscope(GyroscopeEvent event) {
    final now = DateTime.now();
    final previous = _lastGyroTime;
    _lastGyroTime = now;
    if (previous == null) return;

    final gx = _gravityX;
    final gy = _gravityY;
    final gz = _gravityZ;
    if (gx == null || gy == null || gz == null) return;
    final gravityNorm = math.sqrt(gx * gx + gy * gy + gz * gz);
    if (gravityNorm < 5) return;

    final projectedRate =
        event.x * gx / gravityNorm +
        event.y * gy / gravityNorm +
        event.z * gz / gravityNorm;
    _projectedYawRateRadiansPerSecond = projectedRate;

    final dt = now.difference(previous).inMicroseconds / 1000000.0;
    final stable = _absoluteSpreadDegrees <= 3.0;
    _v3.update(
      projectedYawRateRadiansPerSecond: projectedRate,
      deltaSeconds: dt,
      absoluteTrueHeadingDegrees: _trueHeading,
      absoluteHeadingStable: stable,
    );

    if (mounted) setState(() {});
  }

  double get _absoluteSpreadDegrees {
    final values = _absoluteSamples
        .where(
          (sample) => sample.time.isAfter(
            DateTime.now().subtract(const Duration(seconds: 2)),
          ),
        )
        .map((sample) => sample.heading)
        .toList();
    if (values.length < 8) return double.infinity;
    final mean = _circularMean(values);
    var maximum = 0.0;
    for (final value in values) {
      final delta = PointingEngineV3Experimental.signedAngle(
        value - mean,
      ).abs();
      if (delta > maximum) maximum = delta;
    }
    return maximum;
  }

  double? get _stableAbsoluteMean {
    final values = _absoluteSamples
        .where(
          (sample) => sample.time.isAfter(
            DateTime.now().subtract(const Duration(seconds: 2)),
          ),
        )
        .map((sample) => sample.heading)
        .toList();
    if (values.length < 8) return null;
    if (_absoluteSpreadDegrees > 3.0) return null;
    return _circularMean(values);
  }

  Future<void> _selectBeacon() async {
    final beacons =
        widget.controller.catalogue?.beacons ?? const <RadioBeacon>[];
    if (beacons.isEmpty) {
      _message('Catalogo radiofari vuoto.');
      return;
    }
    final selected = await showDialog<RadioBeacon>(
      context: context,
      builder: (dialogContext) => _RadioBeaconPickerDialog(
        beacons: beacons,
        selectedId: _selectedBeacon?.id,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedBeacon = selected;
      _targetBearingDegrees = null;
      _targetDistanceMeters = null;
      _observerPosition = null;
      _v2 = null;
      _v2Reading = null;
      _v3.reset();
      _status =
          'Radiofaro selezionato. Aggiorna il GPS per calcolare il bearing vero.';
    });
    _appendEvent(
      'BEACON_SELECTED id=${selected.id} name=${selected.name} '
      'lat=${selected.position.latitude} lon=${selected.position.longitude}',
    );
  }

  Future<void> _acquireTarget() async {
    final beacon = _selectedBeacon;
    if (beacon == null) {
      _message('Seleziona prima un radiofaro dal catalogo.');
      return;
    }
    final lat = beacon.position.latitude;
    final lon = beacon.position.longitude;

    setState(() {
      _busy = true;
      _status = 'Acquisisco posizione GPS e declinazione…';
    });
    try {
      final permission = await Geolocator.checkPermission();
      var effectivePermission = permission;
      if (permission == LocationPermission.denied) {
        effectivePermission = await Geolocator.requestPermission();
      }
      if (effectivePermission == LocationPermission.denied ||
          effectivePermission == LocationPermission.deniedForever) {
        throw StateError('Permesso posizione non disponibile.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 30),
          useMSLAltitude: true,
        ),
      );
      final orientation = await _deviceChannel.invokeMapMethod<String, dynamic>(
        'readOrientationInfo',
        <String, dynamic>{
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitudeMeters': position.altitude,
          'timestampMillis': DateTime.now().millisecondsSinceEpoch,
        },
      );
      final declination =
          (orientation?['declinationDegrees'] as num?)?.toDouble() ?? 0.0;
      final origin = GeoPoint.validated(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final target = GeoPoint.validated(latitude: lat, longitude: lon);
      final geo = GeoCalculator.between(origin, target);

      _declinationDegrees = declination;
      _observerPosition = position;
      _targetBearingDegrees = geo.initialBearingDegrees;
      _targetDistanceMeters = geo.distanceMeters;
      _v2 = PointingEngineV2(
        targetAzimuthDegrees: geo.initialBearingDegrees,
        targetElevationDegrees: 0,
        declinationDegrees: declination,
      );
      _v2Reading = null;
      _v3.reset();
      _absoluteSamples.clear();
      _appendEvent(
        'TARGET_SET beacon_id=${beacon.id} beacon_name=${beacon.name} lat=$lat lon=$lon observer=${position.latitude},${position.longitude} '
        'accuracy_m=${position.accuracy.toStringAsFixed(2)} '
        'bearing_true=${geo.initialBearingDegrees.toStringAsFixed(6)} '
        'distance_m=${geo.distanceMeters.toStringAsFixed(2)} '
        'declination=${declination.toStringAsFixed(6)}',
      );
      if (!mounted) return;
      setState(() {
        _status =
            'Target geografico pronto. Stabilizza il telefono e ancora V3.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Errore: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _anchorAutomatic() {
    final mean = _stableAbsoluteMean;
    if (mean == null) {
      _message(
        'Heading assoluto non abbastanza stabile: resta fermo circa 2 secondi.',
      );
      return;
    }
    _v3.anchorAbsolute(mean);
    _appendEvent(
      'AUTO_ANCHOR true_heading=${mean.toStringAsFixed(6)} '
      'spread=${_absoluteSpreadDegrees.toStringAsFixed(6)}',
    );
    setState(() => _status = 'V3 ancorato al Nord sensori.');
  }

  void _anchorManualToTarget() {
    final target = _targetBearingDegrees;
    if (target == null) {
      _message('Prima imposta il target geografico.');
      return;
    }
    _v3.anchorManual(target);
    _appendEvent(
      'MANUAL_TARGET_ANCHOR true_heading=${target.toStringAsFixed(6)}',
    );
    setState(() {
      _status = 'Ancora manuale impostata sul target: SOLO diagnostica.';
    });
  }

  void _resetV3() {
    _v3.reset();
    _driftTimer?.cancel();
    _driftTimer = null;
    setState(() {
      _driftStartedAt = null;
      _driftStartGyroHeading = null;
      _driftResultDegrees = null;
      _driftRemainingSeconds = 0;
      _status = 'V3 azzerato.';
    });
    _appendEvent('V3_RESET');
  }

  void _startDriftTest() {
    final heading = _v3.snapshot.gyroHeadingDegrees;
    if (heading == null) {
      _message('Prima ancora V3 automaticamente.');
      return;
    }
    _driftTimer?.cancel();
    _driftStartedAt = DateTime.now();
    _driftStartGyroHeading = heading;
    _driftResultDegrees = null;
    _driftRemainingSeconds = 60;
    _appendEvent('DRIFT_START gyro_heading=${heading.toStringAsFixed(6)}');
    setState(() {});

    _driftTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_driftStartedAt!).inSeconds;
      final remaining = math.max(0, 60 - elapsed).toInt();
      if (remaining <= 0) {
        timer.cancel();
        final current = _v3.snapshot.gyroHeadingDegrees;
        final start = _driftStartGyroHeading;
        final drift = current == null || start == null
            ? null
            : PointingEngineV3Experimental.signedAngle(current - start);
        _driftResultDegrees = drift;
        _driftRemainingSeconds = 0;
        _appendEvent(
          'DRIFT_END drift_deg=${drift?.toStringAsFixed(6) ?? 'NA'}',
        );
      } else {
        _driftRemainingSeconds = remaining;
      }
      setState(() {});
    });
  }

  void _appendPeriodicLog() {
    if (_magneticHeading == null) return;
    final v3 = _v3.snapshot;
    final target = _targetBearingDegrees;
    final v2 = _v2Reading?.trueHeadingDegrees;
    final line = <String>[
      'time=${DateTime.now().toIso8601String()}',
      'mag=${_fmt(_magneticHeading)}',
      'true_raw=${_fmt(_trueHeading)}',
      'decl=${_declinationDegrees.toStringAsFixed(6)}',
      'spread=${_absoluteSpreadDegrees.isFinite ? _absoluteSpreadDegrees.toStringAsFixed(6) : 'NA'}',
      'yaw_rate_dps=${(v3.lastProjectedYawRateDegreesPerSecond).toStringAsFixed(6)}',
      'v2=${_fmt(v2)}',
      'v3_gyro=${_fmt(v3.gyroHeadingDegrees)}',
      'v3_fusion=${_fmt(v3.fusionHeadingDegrees)}',
      'v3_manual=${_fmt(v3.manualHeadingDegrees)}',
      'target=${_fmt(target)}',
      'delta_v2=${_fmtDelta(target, v2)}',
      'delta_gyro=${_fmtDelta(target, v3.gyroHeadingDegrees)}',
      'delta_fusion=${_fmtDelta(target, v3.fusionHeadingDegrees)}',
      'delta_manual=${_fmtDelta(target, v3.manualHeadingDegrees)}',
    ].join(' | ');
    _logLines.add(line);
    if (_logLines.length > 2400) _logLines.removeAt(0);
  }

  void _appendEvent(String value) {
    _logLines.add('EVENT time=${DateTime.now().toIso8601String()} | $value');
  }

  Future<void> _exportLog() async {
    final position = _observerPosition;
    final content = StringBuffer()
      ..writeln('GPS POINTER • AZIMUTH V3 EXPERIMENTAL LAB • BUILD 44')
      ..writeln('pointing_engine_v2=UNCHANGED_REFERENCE')
      ..writeln(
        'v3_mode=gyro_projected_on_gravity_plus_slow_absolute_correction',
      )
      ..writeln('manual_anchor=DIAGNOSTIC_ONLY')
      ..writeln('observer_lat=${position?.latitude ?? 'NA'}')
      ..writeln('observer_lon=${position?.longitude ?? 'NA'}')
      ..writeln('observer_accuracy_m=${position?.accuracy ?? 'NA'}')
      ..writeln('target_beacon_id=${_selectedBeacon?.id ?? 'NA'}')
      ..writeln('target_beacon_name=${_selectedBeacon?.name ?? 'NA'}')
      ..writeln('target_lat=${_selectedBeacon?.position.latitude ?? 'NA'}')
      ..writeln('target_lon=${_selectedBeacon?.position.longitude ?? 'NA'}')
      ..writeln('target_bearing_true_deg=${_fmt(_targetBearingDegrees)}')
      ..writeln('target_distance_m=${_fmt(_targetDistanceMeters)}')
      ..writeln('declination_deg=${_declinationDegrees.toStringAsFixed(6)}')
      ..writeln('compass_accuracy=${_fmt(_compassAccuracy)}')
      ..writeln('drift_result_deg=${_fmt(_driftResultDegrees)}')
      ..writeln('');
    for (final line in _logLines) {
      content.writeln(line);
    }

    final file = await DiagnosticLogStore.writeText(
      category: 'AzimuthV3Lab',
      subject: 'experimental',
      content: content.toString(),
    );
    _lastLogPath = file.path;
    if (!mounted) return;
    setState(() {});
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'GPS Pointer Azimuth V3 Lab build 44',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v3 = _v3.snapshot;
    final target = _targetBearingDegrees;
    final v2Heading = _v2Reading?.trueHeadingDegrees;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Azimuth V3 Lab'),
        actions: [
          IconButton(
            tooltip: 'Esporta TXT',
            onPressed: _logLines.isEmpty ? null : _exportLog,
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
                      'LAB SPERIMENTALE',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Il motore V2 resta invariato. Qui confrontiamo V2, gyro ancorato, '
                      'fusione lenta e ancora manuale diagnostica. Nessuna correzione viene '
                      'applicata alle schermate Azimut o AR reali.',
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
                      'Target geografico',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _selectBeacon,
                      icon: const Icon(Icons.cell_tower),
                      label: Text(
                        _selectedBeacon == null
                            ? 'Scegli radiofaro dal catalogo'
                            : _selectedBeacon!.name,
                      ),
                    ),
                    if (_selectedBeacon != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_selectedBeacon!.position.latitude.toStringAsFixed(6)}, '
                        '${_selectedBeacon!.position.longitude.toStringAsFixed(6)}',
                      ),
                    ],
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _busy || _selectedBeacon == null
                          ? null
                          : _acquireTarget,
                      icon: const Icon(Icons.gps_fixed),
                      label: const Text('Aggiorna GPS + calcola bearing'),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],
                    if (_status != null) ...[
                      const SizedBox(height: 10),
                      Text(_status!),
                    ],
                    const SizedBox(height: 10),
                    _ValueRow('Bearing target vero', _fmtDeg(target)),
                    _ValueRow(
                      'Distanza',
                      _targetDistanceMeters == null
                          ? '—'
                          : '${_targetDistanceMeters!.toStringAsFixed(1)} m',
                    ),
                    _ValueRow(
                      'Declinazione',
                      '${_declinationDegrees.toStringAsFixed(3)}°',
                    ),
                    _ValueRow(
                      'GPS accuracy',
                      _observerPosition == null
                          ? '—'
                          : '±${_observerPosition!.accuracy.toStringAsFixed(1)} m',
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
                      'Sorgenti live',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _ValueRow('Magnetico', _fmtDeg(_magneticHeading)),
                    _ValueRow('Nord vero raw', _fmtDeg(_trueHeading)),
                    _ValueRow(
                      'Stabilità 2 s',
                      _absoluteSpreadDegrees.isFinite
                          ? 'spread ${_absoluteSpreadDegrees.toStringAsFixed(2)}°'
                          : 'in attesa',
                    ),
                    _ValueRow(
                      'Yaw gyro proiettato',
                      _projectedYawRateRadiansPerSecond == null
                          ? '—'
                          : '${(_projectedYawRateRadiansPerSecond! * 180 / math.pi).toStringAsFixed(2)}°/s',
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
                      'Confronto motori',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    _EngineRow(
                      name: 'V2 attuale',
                      heading: v2Heading,
                      target: target,
                    ),
                    _EngineRow(
                      name: 'V3 Gyro',
                      heading: v3.gyroHeadingDegrees,
                      target: target,
                    ),
                    _EngineRow(
                      name: 'V3 Fusion',
                      heading: v3.fusionHeadingDegrees,
                      target: target,
                    ),
                    _EngineRow(
                      name: 'V3 Manual',
                      heading: v3.manualHeadingDegrees,
                      target: target,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _anchorAutomatic,
                          icon: const Icon(Icons.anchor),
                          label: const Text('Ancora V3 dai sensori'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _anchorManualToTarget,
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Ancora manuale SU TARGET'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _resetV3,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset V3'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '“Ancora manuale SU TARGET” richiede di conoscere e puntare fisicamente '
                      'il riferimento: serve solo a separare il tracking gyro dall’errore di Nord.',
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
                      'Deriva gyro 60 s',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ancora V3, appoggia o tieni il telefono immobile e avvia. Non muoverlo per 60 secondi.',
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _driftRemainingSeconds > 0
                          ? null
                          : _startDriftTest,
                      icon: const Icon(Icons.timer_outlined),
                      label: Text(
                        _driftRemainingSeconds > 0
                            ? 'In corso: $_driftRemainingSeconds s'
                            : 'Avvia test deriva 60 s',
                      ),
                    ),
                    if (_driftResultDegrees != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Deriva misurata: ${_driftResultDegrees!.toStringAsFixed(3)}°',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _logLines.isEmpty ? null : _exportLog,
              icon: const Icon(Icons.description_outlined),
              label: Text(
                _lastLogPath == null
                    ? 'Esporta report TXT'
                    : 'Esporta nuovo report TXT',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static double _circularMean(List<double> values) {
    var x = 0.0;
    var y = 0.0;
    for (final value in values) {
      final radians = value * math.pi / 180;
      x += math.cos(radians);
      y += math.sin(radians);
    }
    return PointingEngineV3Experimental.normalize(
      math.atan2(y, x) * 180 / math.pi,
    );
  }

  static String _fmt(double? value) =>
      value == null ? 'NA' : value.toStringAsFixed(6);
  static String _fmtDeg(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(2)}°';
  static String _fmtDelta(double? target, double? heading) {
    if (target == null || heading == null) return 'NA';
    return PointingEngineV3Experimental.signedAngle(
      target - heading,
    ).toStringAsFixed(6);
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _driftTimer?.cancel();
    unawaited(_compassSubscription?.cancel());
    unawaited(_accelerometerSubscription?.cancel());
    unawaited(_gyroscopeSubscription?.cancel());
    super.dispose();
  }
}

final class _RadioBeaconPickerDialog extends StatefulWidget {
  const _RadioBeaconPickerDialog({required this.beacons, this.selectedId});

  final List<RadioBeacon> beacons;
  final String? selectedId;

  @override
  State<_RadioBeaconPickerDialog> createState() =>
      _RadioBeaconPickerDialogState();
}

final class _RadioBeaconPickerDialogState
    extends State<_RadioBeaconPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<RadioBeacon> get _filtered {
    final needle = _query.trim().toLowerCase();
    final values = needle.isEmpty
        ? widget.beacons
        : widget.beacons.where((beacon) {
            return beacon.name.toLowerCase().contains(needle) ||
                beacon.id.toLowerCase().contains(needle);
          }).toList();
    final sorted = List<RadioBeacon>.of(values)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return AlertDialog(
      title: Text('Scegli radiofaro (${widget.beacons.length})'),
      content: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cerca per nome o ID',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Nessun radiofaro trovato.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final beacon = filtered[index];
                        return ListTile(
                          leading: Icon(
                            beacon.id == widget.selectedId
                                ? Icons.radio_button_checked
                                : Icons.cell_tower,
                          ),
                          title: Text(beacon.name),
                          subtitle: Text(
                            '${beacon.position.latitude.toStringAsFixed(6)}, '
                            '${beacon.position.longitude.toStringAsFixed(6)}',
                          ),
                          onTap: () => Navigator.pop(context, beacon),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

final class _TimedHeading {
  const _TimedHeading(this.time, this.heading);
  final DateTime time;
  final double heading;
}

final class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

final class _EngineRow extends StatelessWidget {
  const _EngineRow({
    required this.name,
    required this.heading,
    required this.target,
  });
  final String name;
  final double? heading;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final delta = heading == null || target == null
        ? null
        : PointingEngineV3Experimental.signedAngle(target! - heading!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(heading == null ? '—' : '${heading!.toStringAsFixed(2)}°'),
          const SizedBox(width: 14),
          SizedBox(
            width: 94,
            child: Text(
              delta == null ? 'Δ —' : 'Δ ${delta.toStringAsFixed(2)}°',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
