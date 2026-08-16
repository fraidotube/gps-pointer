import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../core/simulation/radio_link_simulation.dart';

abstract interface class SimulationExportService {
  Future<void> export({
    required RadioLinkSimulation simulation,
    required String deviceId,
    required String deviceName,
  });
}

final class ShareSimulationExportService implements SimulationExportService {
  @override
  Future<void> export({
    required RadioLinkSimulation simulation,
    required String deviceId,
    required String deviceName,
  }) async {
    final payload = {
      'schema': 'gps_pointer_simulation_exchange',
      'version': 1,
      'exported_at_utc': DateTime.now().toUtc().toIso8601String(),
      'source': {
        'application': 'GPS Pointer Android',
        'device_id': deviceId,
        'device_name': deviceName,
      },
      // Il server dovrà validare questi input e ricalcolare il profilo con il
      // proprio motore. Il risultato è incluso per confronto/audit, non come
      // fonte autorevole.
      'simulation': simulation.toJson(),
    };
    final safeName = simulation.name
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    await SharePlus.instance.share(
      ShareParams(
        title: 'Esporta simulazione GPS Pointer',
        subject: simulation.name,
        files: [
          XFile.fromData(
            utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: [
          'gps_pointer_simulation_${safeName.isEmpty ? simulation.id : safeName}.gpspsim',
        ],
      ),
    );
  }
}
