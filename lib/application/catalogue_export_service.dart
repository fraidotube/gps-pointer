import 'dart:convert';

import 'package:share_plus/share_plus.dart';

abstract interface class CatalogueExportService {
  Future<void> export(String content);
}

final class ShareCatalogueExportService implements CatalogueExportService {
  @override
  Future<void> export(String content) async {
    await SharePlus.instance.share(
      ShareParams(
        title: 'Esporta archivio GPS Pointer',
        subject: 'Archivio radiofari GPS Pointer',
        files: [XFile.fromData(utf8.encode(content), mimeType: 'text/plain')],
        fileNameOverrides: const ['radiofari_gps_pointer.txt'],
      ),
    );
  }
}
