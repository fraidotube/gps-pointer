import 'dart:convert';
import 'dart:io';

import '../core/simulation/radio_link_simulation.dart';
import '../core/simulation/radio_link_simulation_repository.dart';

final class JsonRadioLinkSimulationRepository
    implements RadioLinkSimulationRepository {
  JsonRadioLinkSimulationRepository(this._file);

  final File _file;

  @override
  Future<List<RadioLinkSimulation>> loadAll() async {
    if (!await _file.exists()) return const [];
    final text = await _file.readAsString();
    if (text.trim().isEmpty) return const [];
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic> || decoded['simulations'] is! List) {
      throw const FormatException('Archivio simulazioni locale non valido.');
    }
    return (decoded['simulations'] as List<dynamic>)
        .map(
          (item) => RadioLinkSimulation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(RadioLinkSimulation simulation) async {
    final current = [...await loadAll()];
    final index = current.indexWhere((item) => item.id == simulation.id);
    if (index >= 0) {
      current[index] = simulation;
    } else {
      current.add(simulation);
    }
    current.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    await _write(current);
  }

  @override
  Future<void> delete(String id) async {
    final current = [...await loadAll()]..removeWhere((item) => item.id == id);
    await _write(current);
  }

  Future<void> _write(List<RadioLinkSimulation> simulations) async {
    await _file.parent.create(recursive: true);
    final payload = {
      'schema': 'gps_pointer_local_simulations',
      'version': 1,
      'simulations': simulations.map((item) => item.toJson()).toList(),
    };
    final temporary = File('${_file.path}.tmp');
    await temporary.writeAsString(jsonEncode(payload), flush: true);
    await temporary.rename(_file.path);
  }
}
