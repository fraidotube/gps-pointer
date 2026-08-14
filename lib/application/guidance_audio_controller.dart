import 'dart:async';

import 'package:flutter/services.dart';

import '../core/geo/guidance_audio_cadence.dart';

final class GuidanceAudioController {
  GuidanceAudioController({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('io.github.fraidotube.gpspointer/guidance_audio');

  final MethodChannel _channel;
  Timer? _timer;
  Duration? _interval;
  bool _enabled = false;
  bool _continuous = false;
  bool _disposed = false;

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    if (_disposed || _enabled == value) return;
    _enabled = value;
    if (!value) stopOutput();
  }

  void update({
    required bool stable,
    required bool centered,
    required double absoluteErrorDegrees,
  }) {
    if (_disposed || !_enabled || !stable) {
      stopOutput();
      return;
    }
    if (centered) {
      _timer?.cancel();
      _timer = null;
      _interval = null;
      if (!_continuous) {
        _continuous = true;
        unawaited(_invoke('startContinuous'));
      }
      return;
    }

    if (_continuous) {
      _continuous = false;
      unawaited(_invoke('stop'));
    }
    final nextInterval = GuidanceAudioCadence.intervalFor(absoluteErrorDegrees);
    if (_timer != null && _interval == nextInterval) return;
    _timer?.cancel();
    _interval = nextInterval;
    unawaited(_invoke('playBeep'));
    _timer = Timer.periodic(nextInterval, (_) {
      if (_enabled && !_disposed) unawaited(_invoke('playBeep'));
    });
  }

  void stopOutput() {
    _timer?.cancel();
    _timer = null;
    _interval = null;
    if (_continuous || _enabled) unawaited(_invoke('stop'));
    _continuous = false;
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException {
      // Audio guidance is optional: a platform failure must never affect
      // pointing, sensors or navigation.
    } on MissingPluginException {
      // Keeps widget and unit tests independent from the Android host.
    }
  }

  void dispose() {
    if (_disposed) return;
    stopOutput();
    _disposed = true;
  }
}
