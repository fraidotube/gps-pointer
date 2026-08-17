import 'dart:io';

import 'package:path_provider/path_provider.dart';

final class DiagnosticLogEntry {
  const DiagnosticLogEntry({
    required this.path,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime modifiedAt;
  final int sizeBytes;
}

final class DiagnosticLogStore {
  const DiagnosticLogStore._();

  static Future<Directory> _directory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/gps_pointer_debug');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static String _safe(String value) => value
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static String _stamp(DateTime value) {
    final utc = value.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}_'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  }

  static Future<File> writeText({
    required String category,
    required String subject,
    required String content,
    DateTime? timestamp,
  }) async {
    final directory = await _directory();
    final time = timestamp ?? DateTime.now();
    final safeCategory = _safe(category).isEmpty ? 'Debug' : _safe(category);
    final safeSubject = _safe(subject).isEmpty ? 'Session' : _safe(subject);
    final file = File(
      '${directory.path}/${safeCategory}_${safeSubject}_${_stamp(time)}.txt',
    );
    await file.writeAsString(content, flush: true);
    return file;
  }

  static Future<List<DiagnosticLogEntry>> list() async {
    final directory = await _directory();
    final entries = <DiagnosticLogEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.txt')) {
        continue;
      }
      final stat = await entity.stat();
      entries.add(
        DiagnosticLogEntry(
          path: entity.path,
          name: entity.uri.pathSegments.last,
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }
    entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return entries;
  }

  static Future<String> read(String path) => File(path).readAsString();

  static Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
