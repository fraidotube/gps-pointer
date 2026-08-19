import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/simulation/radio_link_simulation.dart';

final class SimulationPdfService {
  const SimulationPdfService();

  Future<void> createAndShare(
    RadioLinkSimulation simulation, {
    Uint8List? profilePng,
    Uint8List? overviewMapPng,
    Uint8List? detailAMapPng,
    Uint8List? detailBMapPng,
  }) async {
    final document = pw.Document(
      title: simulation.name,
      author: 'GPS Pointer',
      creator: 'GPS Pointer Android',
    );

    final profile = simulation.profile;
    final isPtp = simulation.kind == RadioLinkSimulationKind.ptp;
    final generated = DateTime.now().toLocal();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.blueGrey700),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'GPS POINTER',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(isPtp ? 'PUNTO-PUNTO' : 'COPERTURA'),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 14),
          pw.Text(
            simulation.name,
            style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generato il ${_date(generated)}',
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          _section('Risultato', [
            _row('Tipo', isPtp ? 'Punto-Punto (PTP)' : 'Copertura'),
            _row('Distanza', '${profile.distanceKm.toStringAsFixed(2)} km'),
            _row(
              'Azimut vero',
              '${simulation.azimuthDegrees.toStringAsFixed(2)}°',
            ),
            _row(
              'Tilt teorico',
              '${profile.tiltDegrees >= 0 ? '+' : ''}'
                  '${profile.tiltDegrees.toStringAsFixed(2)}°',
            ),
            _row(
              'Linea ottica',
              profile.lineOfSightClear ? 'Libera' : 'Ostruita',
            ),
            if (profile.firstFresnelClear != null)
              _row(
                'Prima Fresnel',
                profile.firstFresnelClear! ? 'Libera' : 'Ostruita',
              ),
            _row(
              'Margine LOS minimo',
              '${profile.minimumLosClearanceMeters.toStringAsFixed(1)} m',
            ),
            if (profile.minimumFresnelClearanceMeters != null)
              _row(
                'Margine Fresnel minimo',
                '${profile.minimumFresnelClearanceMeters!.toStringAsFixed(1)} m',
              ),
          ]),
          pw.SizedBox(height: 14),
          _section('Punto A / Partenza', [
            _row(
              'Coordinate',
              '${simulation.startPosition.latitude.toStringAsFixed(7)}, '
                  '${simulation.startPosition.longitude.toStringAsFixed(7)}',
            ),
            _row(
              'Quota terreno',
              '${simulation.startGroundElevationMeters.toStringAsFixed(1)} m',
            ),
            _row(
              'Altezza antenna',
              '${simulation.buildingHeightMeters.toStringAsFixed(1)} m',
            ),
            _row(
              'Quota antenna',
              '${profile.installerAntennaElevationMeters.toStringAsFixed(1)} m',
            ),
          ]),
          pw.SizedBox(height: 14),
          _section(isPtp ? 'Punto B / Arrivo' : 'Postazione Radio', [
            if (!isPtp) _row('Nome', simulation.beaconName),
            _row(
              'Coordinate',
              '${simulation.targetPosition.latitude.toStringAsFixed(7)}, '
                  '${simulation.targetPosition.longitude.toStringAsFixed(7)}',
            ),
            _row(
              'Quota terreno',
              '${simulation.targetGroundElevationMeters.toStringAsFixed(1)} m',
            ),
            _row(
              'Altezza antenna',
              '${simulation.targetPoleHeightMeters.toStringAsFixed(1)} m',
            ),
            _row(
              'Quota antenna',
              '${profile.targetAntennaElevationMeters.toStringAsFixed(1)} m',
            ),
          ]),
          pw.SizedBox(height: 14),
          _section('Radio', [
            _row(
              'Frequenza',
              simulation.frequencyGhz == null
                  ? 'Non indicata'
                  : '${simulation.frequencyGhz!.toStringAsFixed(3)} GHz',
            ),
            _row('Fattore K', profile.kFactor.toStringAsFixed(3)),
            _row('Campioni profilo', '${profile.sampleCount}'),
          ]),
          if (profilePng != null) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Profilo altimetrico',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Image(
              pw.MemoryImage(profilePng),
              fit: pw.BoxFit.contain,
              height: 190,
            ),
          ],
          if (overviewMapPng != null) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Mappa collegamento',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Image(
              pw.MemoryImage(overviewMapPng),
              fit: pw.BoxFit.contain,
              height: 230,
            ),
          ],
          if (detailAMapPng != null) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Dettaglio Punto A',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Image(
              pw.MemoryImage(detailAMapPng),
              fit: pw.BoxFit.contain,
              height: 230,
            ),
          ],
          if (detailBMapPng != null) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Dettaglio Punto B',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Image(
              pw.MemoryImage(detailBMapPng),
              fit: pw.BoxFit.contain,
              height: 230,
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            'Campioni profilo altimetrico',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['km', 'Terreno m', 'LOS m', 'Fresnel inf. m'],
            data: _sampleRows(simulation),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey100,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerRight,
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Nota: il PDF è un rapporto leggibile. Per trasferire e '
            'reimportare la simulazione usare il file .gpspsim.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    final directory = await getTemporaryDirectory();
    final safe = simulation.name
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final file = File(
      '${directory.path}/GPS_Pointer_${safe.isEmpty ? simulation.id : safe}.pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);

    await SharePlus.instance.share(
      ShareParams(
        title: 'PDF GPS Pointer',
        subject: simulation.name,
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }

  static pw.Widget _section(String title, List<pw.Widget> rows) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.blueGrey300),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 7),
        ...rows,
      ],
    ),
  );

  static pw.Widget _row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: pw.Text(label)),
        pw.SizedBox(width: 12),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );

  static List<List<String>> _sampleRows(RadioLinkSimulation simulation) {
    final points = simulation.profile.points;
    if (points.isEmpty) return const [];
    const maximumRows = 36;
    final step = points.length <= maximumRows
        ? 1
        : (points.length / maximumRows).ceil();

    final rows = <List<String>>[];
    for (var index = 0; index < points.length; index += step) {
      final point = points[index];
      rows.add([
        point.distanceKm.toStringAsFixed(2),
        point.adjustedTerrainMeters.toStringAsFixed(1),
        point.lineOfSightMeters.toStringAsFixed(1),
        point.fresnelLowerMeters?.toStringAsFixed(1) ?? '—',
      ]);
    }
    final last = points.last;
    if (rows.isEmpty || rows.last.first != last.distanceKm.toStringAsFixed(2)) {
      rows.add([
        last.distanceKm.toStringAsFixed(2),
        last.adjustedTerrainMeters.toStringAsFixed(1),
        last.lineOfSightMeters.toStringAsFixed(1),
        last.fresnelLowerMeters?.toStringAsFixed(1) ?? '—',
      ]);
    }
    return rows;
  }

  static String _date(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
