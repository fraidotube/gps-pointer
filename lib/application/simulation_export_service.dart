import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../core/simulation/radio_link_simulation.dart';
import 'simulation_exchange_codec.dart';

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
    final content = SimulationExchangeCodec.encode(
      simulation: simulation,
      deviceId: deviceId,
      deviceName: deviceName,
    );
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
            utf8.encode(content),
            mimeType: SimulationExchangeCodec.mimeType,
          ),
        ],
        fileNameOverrides: [
          'gps_pointer_${simulation.kind.name}_'
              '${safeName.isEmpty ? simulation.id : safeName}.gpspsim',
        ],
      ),
    );
  }
}
