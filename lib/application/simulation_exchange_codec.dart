import 'dart:convert';

import '../core/simulation/radio_link_simulation.dart';

final class SimulationExchangeDocument {
  const SimulationExchangeDocument({
    required this.simulation,
    required this.exportedAtUtc,
    required this.sourceApplication,
    required this.sourceDeviceId,
    required this.sourceDeviceName,
  });

  final RadioLinkSimulation simulation;
  final DateTime exportedAtUtc;
  final String sourceApplication;
  final String sourceDeviceId;
  final String sourceDeviceName;
}

final class SimulationExchangeCodec {
  const SimulationExchangeCodec._();

  static const schema = 'gps_pointer_simulation_exchange';
  static const version = 1;
  static const mimeType = 'application/vnd.gpspointer.simulation+json';

  static String encode({
    required RadioLinkSimulation simulation,
    required String deviceId,
    required String deviceName,
  }) {
    final payload = <String, Object?>{
      'schema': schema,
      'version': version,
      'exported_at_utc': DateTime.now().toUtc().toIso8601String(),
      'source': <String, Object?>{
        'application': 'GPS Pointer Android',
        'device_id': deviceId,
        'device_name': deviceName,
      },
      'simulation': simulation.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static SimulationExchangeDocument decode(String text) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Il file .gpspsim non contiene JSON valido.');
    }

    if (decoded is! Map) {
      throw const FormatException('Documento .gpspsim non valido.');
    }
    final root = Map<String, dynamic>.from(decoded);
    if (root['schema'] != schema) {
      throw const FormatException('Schema .gpspsim non riconosciuto.');
    }
    if (root['version'] != version) {
      throw FormatException(
        'Versione .gpspsim non supportata: ${root['version']}.',
      );
    }
    if (root['simulation'] is! Map) {
      throw const FormatException('Simulazione mancante nel file .gpspsim.');
    }

    final source = root['source'] is Map
        ? Map<String, dynamic>.from(root['source'] as Map)
        : const <String, dynamic>{};

    return SimulationExchangeDocument(
      simulation: RadioLinkSimulation.fromJson(
        Map<String, dynamic>.from(root['simulation'] as Map),
      ),
      exportedAtUtc: DateTime.parse(root['exported_at_utc'] as String).toUtc(),
      sourceApplication: source['application']?.toString() ?? 'GPS Pointer',
      sourceDeviceId: source['device_id']?.toString() ?? '',
      sourceDeviceName: source['device_name']?.toString() ?? '',
    );
  }
}
