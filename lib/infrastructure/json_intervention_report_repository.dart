import 'dart:convert';
import 'dart:io';

import '../core/intervention_report.dart';

final class JsonInterventionReportRepository
    implements InterventionReportRepository {
  JsonInterventionReportRepository(this._file);

  final File _file;

  @override
  Future<List<InterventionReport>> loadAll() async {
    if (!await _file.exists()) return const [];
    final text = await _file.readAsString();
    if (text.trim().isEmpty) return const [];
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic> || decoded['reports'] is! List) {
      throw const FormatException('Archivio rapporti locale non valido.');
    }
    final reports = (decoded['reports'] as List<dynamic>)
        .map(
          (item) => InterventionReport.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    reports.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    return reports;
  }

  @override
  Future<void> save(InterventionReport report) async {
    final current = [...await loadAll()];
    final index = current.indexWhere((item) => item.id == report.id);
    if (index >= 0) {
      current[index] = report;
    } else {
      current.add(report);
    }
    current.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    await _write(current);
  }

  @override
  Future<void> delete(String id) async {
    final current = [...await loadAll()]..removeWhere((item) => item.id == id);
    await _write(current);
  }

  Future<void> _write(List<InterventionReport> reports) async {
    await _file.parent.create(recursive: true);
    final temporary = File('${_file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'schema': 'gps_pointer_intervention_reports',
        'version': 1,
        'reports': reports.map((item) => item.toJson()).toList(growable: false),
      }),
      flush: true,
    );
    await temporary.rename(_file.path);
  }
}
