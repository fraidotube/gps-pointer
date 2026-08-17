import 'package:flutter/services.dart';

final class IncomingSimulationPayload {
  const IncomingSimulationPayload({required this.name, required this.content});

  final String name;
  final String content;

  factory IncomingSimulationPayload.fromMap(Map<Object?, Object?> map) {
    final name = map['name']?.toString() ?? 'simulation.gpspsim';
    final content = map['content']?.toString();
    if (content == null || content.isEmpty) {
      throw const FormatException('File .gpspsim ricevuto vuoto.');
    }
    return IncomingSimulationPayload(name: name, content: content);
  }
}

final class IncomingSimulationBridge {
  IncomingSimulationBridge._();

  static const MethodChannel _channel = MethodChannel(
    'io.github.fraidotube.gpspointer/simulation_file',
  );

  static Future<void> initialize(
    Future<void> Function(IncomingSimulationPayload payload) onOpen,
  ) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'simulationFileOpened') return;
      final arguments = call.arguments;
      if (arguments is! Map) return;
      await onOpen(
        IncomingSimulationPayload.fromMap(
          Map<Object?, Object?>.from(arguments),
        ),
      );
    });

    final initial = await _channel.invokeMethod<Object?>(
      'takePendingSimulation',
    );
    if (initial is Map) {
      await onOpen(
        IncomingSimulationPayload.fromMap(Map<Object?, Object?>.from(initial)),
      );
    }
  }
}
