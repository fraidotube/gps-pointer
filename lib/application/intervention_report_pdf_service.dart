import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/intervention_report.dart';

final class InterventionReportLayoutException implements Exception {
  const InterventionReportLayoutException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Generates the final report over the official Connesi paper form.
///
/// SAFE +47: the background is a full-page render of the exact official blank
/// PDF supplied for GPS Pointer. All placements below use the original PDF's
/// top-left coordinate system (A4 595.56 x 842.04 pt), eliminating the mixed
/// bottom/top coordinate mapping that caused the +46 overlay drift.
final class InterventionReportPdfService {
  const InterventionReportPdfService();

  static const String templateAsset = 'asset/rapporto_intervento_template.png';
  static const double _pageW = 595.28;
  static const double _pageH = 841.89;
  static const double _fontSize = 9.6;

  Future<File> generate(InterventionReport report) async {
    final document = pw.Document();
    // The pdf package exposes buildFont as protected, but this bridge is needed
    // only for precise string metrics used by the no-truncation validator.
    // ignore: invalid_use_of_protected_member
    final metricFont = pw.Font.helvetica().buildFont(document.document);
    final background = pw.MemoryImage(
      (await rootBundle.load(templateAsset)).buffer.asUint8List(),
    );

    final widgets = <pw.Widget>[
      pw.Positioned(
        left: 0,
        top: 0,
        child: pw.SizedBox(
          width: _pageW,
          height: _pageH,
          child: pw.Image(background, fit: pw.BoxFit.fill),
        ),
      ),
    ];

    void oneLine(
      String label,
      String value,
      double x,
      double top,
      double maxWidth, {
      double size = _fontSize,
    }) {
      final text = value.trim();
      if (text.isEmpty) return;
      if (_measure(metricFont, text, size) > maxWidth) {
        throw InterventionReportLayoutException(
          '$label non entra nello spazio disponibile del modulo.',
        );
      }
      widgets.add(_textAt(text, x: x, top: top, size: size));
    }

    // CLIENTE - aligned to the three original form baselines.
    oneLine('Nominativo', report.clientName, 111, 98.5, 430, size: 10.2);
    oneLine('Utente', report.customerUser, 86, 118.1, 455, size: 10.2);
    oneLine('Indirizzo', report.address, 95, 137.6, 218, size: 10.2);
    oneLine('Telefono', report.phone, 362, 137.6, 178, size: 10.2);

    // DIAGNOSI / ESITO.
    oneLine('Altro diagnosi', report.diagnosisOther, 80, 269.6, 460);
    oneLine('Note', report.notes, 84, 540.4, 456);
    oneLine('Tecnico', report.technicianName, 145, 566.7, 395);

    // First writable row of the TEMPI DI ESECUZIONE table.
    oneLine('Data', report.interventionDate, 63, 628.2, 150, size: 8.8);
    oneLine('Ora inizio', report.startTime, 226, 628.2, 150, size: 8.8);
    oneLine('Ora fine', report.endTime, 389, 628.2, 145, size: 8.8);

    _multiline(
      widgets,
      metricFont,
      label: 'Descrizione intervento',
      value: report.description,
      xs: const [164, 62, 62, 62],
      tops: const [301.1, 315.3, 331.6, 345.4],
      widths: const [376, 478, 478, 478],
    );
    _multiline(
      widgets,
      metricFont,
      label: 'Materiale consegnato / DDT',
      value: report.deliveredMaterial,
      xs: const [62],
      tops: const [384.0],
      widths: const [466],
    );
    _multiline(
      widgets,
      metricFont,
      label: 'Materiale ritirato',
      value: report.collectedMaterial,
      xs: const [62, 62],
      tops: const [423.0, 438.8],
      widths: const [478, 478],
    );
    _multiline(
      widgets,
      metricFont,
      label: 'Riservato a Connesi',
      value: report.reservedNotes,
      xs: const [57, 57],
      tops: const [749.0, 765.5],
      widths: const [478, 478],
    );

    const diagnosisBoxes = <String, (double, double)>{
      'Manomissione': (112, 203),
      'Sovratensioni da scariche elettriche': (350, 203),
      'Incuria': (111, 216),
      'Evento atmosferico': (114, 230),
      'Danneggiamenti accidentali': (351, 230),
      'Degrado/usura': (348, 244),
    };
    for (final diagnosis in report.diagnoses) {
      final box = diagnosisBoxes[diagnosis];
      if (box != null) _addCheck(widgets, x: box.$1, top: box.$2);
    }

    if (report.outcome == 'Risolutivo/Conclusivo') {
      _addCheck(widgets, x: 200, top: 487);
    } else if (report.outcome == 'Non risolutivo') {
      _addCheck(widgets, x: 436, top: 487);
    }
    if (report.testResult == 'OK') {
      _addCheck(widgets, x: 198, top: 520);
    } else if (report.testResult == 'KO') {
      _addCheck(widgets, x: 351, top: 520);
    }

    // Signatures live between their labels and the original signature rules.
    _addSignature(
      widgets,
      report.customerSignaturePngBase64,
      left: 57,
      top: 683,
      width: 164,
      height: 24,
    );
    _addSignature(
      widgets,
      report.technicianSignaturePngBase64,
      left: 383,
      top: 683,
      width: 157,
      height: 24,
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(children: widgets),
      ),
    );

    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/intervention_report_pdfs',
    );
    await directory.create(recursive: true);
    final safeClient = report.clientName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final file = File(
      '${directory.path}/${report.id}_${safeClient.isEmpty ? 'rapporto' : safeClient}.pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  static double _measure(PdfFont font, String text, double size) {
    // ignore: deprecated_member_use
    return font.stringSize(text).x * size;
  }

  static pw.Widget _textAt(
    String text, {
    required double x,
    required double top,
    required double size,
  }) => pw.Positioned(
    left: x,
    top: top,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: pw.Font.helvetica(),
        fontSize: size,
        color: PdfColor.fromInt(0xff1c2733),
      ),
    ),
  );

  static void _multiline(
    List<pw.Widget> widgets,
    PdfFont font, {
    required String label,
    required String value,
    required List<double> xs,
    required List<double> tops,
    required List<double> widths,
  }) {
    final text = value.trim();
    if (text.isEmpty) return;
    final words = text.replaceAll('\r', '').split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    var lineIndex = 0;

    for (final word in words.where((item) => item.isNotEmpty)) {
      if (lineIndex >= widths.length) {
        throw InterventionReportLayoutException(
          '$label supera lo spazio disponibile del modulo.',
        );
      }
      final candidate = current.isEmpty ? word : '$current $word';
      if (_measure(font, candidate, _fontSize) <= widths[lineIndex]) {
        current = candidate;
        continue;
      }
      if (current.isEmpty) {
        throw InterventionReportLayoutException(
          '$label contiene una parola troppo lunga per il modulo.',
        );
      }
      lines.add(current);
      lineIndex++;
      current = word;
      if (lineIndex >= widths.length) {
        throw InterventionReportLayoutException(
          '$label supera lo spazio disponibile del modulo.',
        );
      }
      if (_measure(font, current, _fontSize) > widths[lineIndex]) {
        throw InterventionReportLayoutException(
          '$label contiene una parola troppo lunga per il modulo.',
        );
      }
    }
    if (current.isNotEmpty) lines.add(current);
    if (lines.length > tops.length) {
      throw InterventionReportLayoutException(
        '$label supera lo spazio disponibile del modulo.',
      );
    }

    for (var index = 0; index < lines.length; index++) {
      widgets.add(
        _textAt(lines[index], x: xs[index], top: tops[index], size: _fontSize),
      );
    }
  }

  static void _addCheck(
    List<pw.Widget> widgets, {
    required double x,
    required double top,
  }) {
    widgets.add(
      pw.Positioned(
        left: x - 0.2,
        top: top - 1.4,
        child: pw.Text(
          'X',
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 7.2,
            color: PdfColor.fromInt(0xff2e6cb8),
          ),
        ),
      ),
    );
  }

  static void _addSignature(
    List<pw.Widget> widgets,
    String? base64Png, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final bytes = InterventionReport.decodeSignature(base64Png);
    if (bytes == null || bytes.isEmpty) return;
    final image = pw.MemoryImage(Uint8List.fromList(bytes));
    widgets.add(
      pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: width,
          height: height,
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }
}
