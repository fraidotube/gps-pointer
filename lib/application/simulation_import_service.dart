import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import 'simulation_exchange_codec.dart';

final class PickedSimulationDocument {
  const PickedSimulationDocument({required this.name, required this.document});

  final String name;
  final SimulationExchangeDocument document;
}

final class SimulationImportService {
  const SimulationImportService();

  Future<PickedSimulationDocument?> pickAndDecode() async {
    const group = XTypeGroup(
      label: 'GPS Pointer simulation',
      extensions: <String>['gpspsim'],
      mimeTypes: <String>[SimulationExchangeCodec.mimeType, 'application/json'],
    );
    final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[group]);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw const FormatException(
        'File .gpspsim troppo grande (massimo 8 MB).',
      );
    }

    final text = utf8.decode(bytes, allowMalformed: false);
    return PickedSimulationDocument(
      name: file.name,
      document: SimulationExchangeCodec.decode(text),
    );
  }
}
