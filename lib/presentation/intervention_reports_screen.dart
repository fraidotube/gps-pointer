import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../application/intervention_report_pdf_service.dart';
import '../application/server_upload_services.dart';
import '../core/intervention_report.dart';

const _reportNavy = Color(0xFF122A47);
const _reportBlue = Color(0xFF2E6CB8);
const _reportBlueSoft = Color(0xFFE8F0FA);
const _reportPaper = Color(0xFFF5F7FA);
const _reportLine = Color(0xFFD7DEE7);
const _reportInk = Color(0xFF1C2733);
const _reportMuted = Color(0xFF5C6B7A);
const _reportOk = Color(0xFF2E8B57);
const _reportKo = Color(0xFFC1443A);

final class InterventionReportsScreen extends StatefulWidget {
  const InterventionReportsScreen({
    required this.repository,
    required this.pdfService,
    required this.uploadService,
    required this.defaultTechnicianName,
    super.key,
  });

  final InterventionReportRepository repository;
  final InterventionReportPdfService pdfService;
  final GpsPointerServerUploadService uploadService;
  final String defaultTechnicianName;

  @override
  State<InterventionReportsScreen> createState() =>
      _InterventionReportsScreenState();
}

final class _InterventionReportsScreenState
    extends State<InterventionReportsScreen> {
  bool _busy = true;
  List<InterventionReport> _reports = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final reports = await widget.repository.loadAll();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _busy = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Archivio rapporti non leggibile: $error';
      });
    }
  }

  Future<void> _openForm([InterventionReport? report]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => InterventionReportFormScreen(
          repository: widget.repository,
          pdfService: widget.pdfService,
          initialReport: report,
          defaultTechnicianName: widget.defaultTechnicianName,
        ),
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _sharePdf(InterventionReport report) async {
    try {
      final file = await widget.pdfService.generate(report);
      await SharePlus.instance.share(
        ShareParams(
          title: 'Rapporto di intervento',
          subject: report.clientName,
          files: [XFile(file.path, mimeType: 'application/pdf')],
          fileNameOverrides: ['${report.id}.pdf'],
        ),
      );
    } on InterventionReportLayoutException catch (error) {
      _message(error.message);
    } catch (error) {
      _message('Condivisione PDF non riuscita: $error');
    }
  }

  Future<void> _upload(InterventionReport report) async {
    setState(() => _busy = true);
    try {
      final pdf = await widget.pdfService.generate(report);
      await widget.uploadService.uploadInterventionReport(
        report: report,
        pdfFile: pdf,
      );
      final updated = report.copyWith(
        status: InterventionReportStatus.uploaded,
        updatedAtUtc: DateTime.now().toUtc(),
        uploadedAtUtc: DateTime.now().toUtc(),
      );
      await widget.repository.save(updated);
      _message('Rapporto inviato al server GPS Pointer.');
      await _reload();
    } on ServerUploadException catch (error) {
      final pending = report.copyWith(
        status: InterventionReportStatus.pendingUpload,
        updatedAtUtc: DateTime.now().toUtc(),
      );
      await widget.repository.save(pending);
      _message('${error.message}\nRapporto mantenuto da inviare.');
      await _reload();
    } on InterventionReportLayoutException catch (error) {
      _message(error.message);
      if (mounted) setState(() => _busy = false);
    } catch (error) {
      _message('Invio rapporto non riuscito: $error');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(InterventionReport report) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina rapporto'),
        content: Text('Eliminare il rapporto di ${report.clientName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await widget.repository.delete(report.id);
    await _reload();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _reportPaper,
    appBar: AppBar(
      backgroundColor: _reportNavy,
      foregroundColor: Colors.white,
      title: const Text('Rapporti d’intervento'),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _openForm(),
      icon: const Icon(Icons.add),
      label: const Text('Nuovo rapporto'),
    ),
    body: _busy && _reports.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const _ReportIntroHeader(),
                const SizedBox(height: 14),
                if (_error != null)
                  _ReportBanner(message: _error!, error: true),
                if (_reports.isEmpty)
                  const _EmptyReports()
                else
                  for (final report in _reports) ...[
                    _ReportArchiveCard(
                      report: report,
                      onOpen: () => _openForm(report),
                      onPdf: report.status == InterventionReportStatus.draft
                          ? null
                          : () => _sharePdf(report),
                      onUpload: report.status == InterventionReportStatus.draft
                          ? null
                          : () => _upload(report),
                      onDelete: () => _delete(report),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
  );
}

final class _ReportIntroHeader extends StatelessWidget {
  const _ReportIntroHeader();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _reportNavy,
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(18),
    child: const Stack(
      children: [
        Positioned(
          right: -25,
          top: -35,
          child: SizedBox(
            width: 120,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0x22FFFFFF), width: 1.5),
                ),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'connesi°',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Rapporto di intervento — modulo digitale',
              style: TextStyle(color: Color(0xFFB9C8DA), fontSize: 13),
            ),
            SizedBox(height: 10),
            Text(
              'Flusso e stile APPWEB Report Intervento, integrati nativamente in GPS Pointer. Firme touch, PDF e invio server.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ),
      ],
    ),
  );
}

final class _EmptyReports extends StatelessWidget {
  const _EmptyReports();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _reportLine),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Column(
      children: [
        Icon(Icons.description_outlined, size: 42, color: _reportBlue),
        SizedBox(height: 10),
        Text('Nessun rapporto salvato.'),
      ],
    ),
  );
}

final class _ReportBanner extends StatelessWidget {
  const _ReportBanner({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFBEAE8) : _reportBlueSoft,
      border: Border.all(color: error ? const Color(0xFFEFC6C1) : _reportLine),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      message,
      style: TextStyle(color: error ? _reportKo : _reportInk),
    ),
  );
}

final class _ReportArchiveCard extends StatelessWidget {
  const _ReportArchiveCard({
    required this.report,
    required this.onOpen,
    required this.onPdf,
    required this.onUpload,
    required this.onDelete,
  });
  final InterventionReport report;
  final VoidCallback onOpen;
  final VoidCallback? onPdf;
  final VoidCallback? onUpload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (report.status) {
      InterventionReportStatus.draft => ('BOZZA', _reportMuted),
      InterventionReportStatus.completed => ('COMPLETATO', _reportBlue),
      InterventionReportStatus.pendingUpload => (
        'DA INVIARE',
        const Color(0xFFB8792A),
      ),
      InterventionReportStatus.uploaded => ('INVIATO', _reportOk),
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _reportLine),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onOpen,
            title: Text(
              report.clientName.isEmpty
                  ? 'Rapporto senza nominativo'
                  : report.clientName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _reportNavy,
              ),
            ),
            subtitle: Text(
              '${report.interventionDate.isEmpty ? 'data non impostata' : report.interventionDate} · ${report.technicianName}',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Apri'),
                ),
                TextButton.icon(
                  onPressed: onPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
                TextButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    report.status == InterventionReportStatus.uploaded
                        ? 'Reinvia'
                        : 'Invia',
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Elimina',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class InterventionReportFormScreen extends StatefulWidget {
  const InterventionReportFormScreen({
    required this.repository,
    required this.pdfService,
    required this.defaultTechnicianName,
    this.initialReport,
    super.key,
  });

  final InterventionReportRepository repository;
  final InterventionReportPdfService pdfService;
  final InterventionReport? initialReport;
  final String defaultTechnicianName;

  @override
  State<InterventionReportFormScreen> createState() =>
      _InterventionReportFormScreenState();
}

final class _InterventionReportFormScreenState
    extends State<InterventionReportFormScreen> {
  static const diagnoses = <String>[
    'Manomissione',
    'Sovratensioni da scariche elettriche',
    'Incuria',
    'Danneggiamenti accidentali',
    'Evento atmosferico',
    'Degrado/usura',
  ];

  late final TextEditingController _clientName;
  late final TextEditingController _customerUser;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _diagnosisOther;
  late final TextEditingController _description;
  late final TextEditingController _delivered;
  late final TextEditingController _collected;
  late final TextEditingController _notes;
  late final TextEditingController _technician;
  late final TextEditingController _date;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _reserved;

  final Set<String> _diagnoses = {};
  String _outcome = '';
  String _testResult = '';
  Uint8List? _customerSignature;
  Uint8List? _technicianSignature;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final report = widget.initialReport;
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    _clientName = TextEditingController(text: report?.clientName ?? '');
    _customerUser = TextEditingController(text: report?.customerUser ?? '');
    _address = TextEditingController(text: report?.address ?? '');
    _phone = TextEditingController(text: report?.phone ?? '');
    _diagnosisOther = TextEditingController(text: report?.diagnosisOther ?? '');
    _description = TextEditingController(text: report?.description ?? '');
    _delivered = TextEditingController(text: report?.deliveredMaterial ?? '');
    _collected = TextEditingController(text: report?.collectedMaterial ?? '');
    _notes = TextEditingController(text: report?.notes ?? '');
    _technician = TextEditingController(
      text: report?.technicianName ?? widget.defaultTechnicianName,
    );
    _date = TextEditingController(
      text:
          report?.interventionDate ??
          '${now.year}-${two(now.month)}-${two(now.day)}',
    );
    _start = TextEditingController(
      text: report?.startTime ?? '${two(now.hour)}:${two(now.minute)}',
    );
    _end = TextEditingController(text: report?.endTime ?? '');
    _reserved = TextEditingController(text: report?.reservedNotes ?? '');
    if (report != null) {
      _diagnoses.addAll(report.diagnoses);
      _outcome = report.outcome;
      _testResult = report.testResult;
      final customer = InterventionReport.decodeSignature(
        report.customerSignaturePngBase64,
      );
      final technician = InterventionReport.decodeSignature(
        report.technicianSignaturePngBase64,
      );
      if (customer != null) {
        _customerSignature = Uint8List.fromList(customer);
      }
      if (technician != null) {
        _technicianSignature = Uint8List.fromList(technician);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _clientName,
      _customerUser,
      _address,
      _phone,
      _diagnosisOther,
      _description,
      _delivered,
      _collected,
      _notes,
      _technician,
      _date,
      _start,
      _end,
      _reserved,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _sign({required bool customer}) async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => SignatureCaptureScreen(
          title: customer ? 'Firma del cliente' : 'Firma dell’incaricato',
          initialPng: customer ? _customerSignature : _technicianSignature,
        ),
      ),
    );
    if (bytes == null || !mounted) return;
    setState(() {
      if (customer) {
        _customerSignature = bytes;
      } else {
        _technicianSignature = bytes;
      }
    });
  }

  Future<void> _save({required bool complete}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (complete) {
        _validateComplete();
      }
      final now = DateTime.now().toUtc();
      final old = widget.initialReport;
      final report = InterventionReport(
        id: old?.id ?? 'RPT-${now.microsecondsSinceEpoch}',
        clientName: _clientName.text.trim(),
        customerUser: _customerUser.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        diagnoses: _diagnoses.toList(growable: false),
        diagnosisOther: _diagnosisOther.text.trim(),
        description: _description.text.trim(),
        deliveredMaterial: _delivered.text.trim(),
        collectedMaterial: _collected.text.trim(),
        outcome: _outcome,
        testResult: _testResult,
        notes: _notes.text.trim(),
        technicianName: _technician.text.trim(),
        interventionDate: _date.text.trim(),
        startTime: _start.text.trim(),
        endTime: _end.text.trim(),
        reservedNotes: _reserved.text.trim(),
        customerSignaturePngBase64: _customerSignature == null
            ? null
            : base64Encode(_customerSignature!),
        technicianSignaturePngBase64: _technicianSignature == null
            ? null
            : base64Encode(_technicianSignature!),
        status: complete
            ? InterventionReportStatus.completed
            : InterventionReportStatus.draft,
        createdAtUtc: old?.createdAtUtc ?? now,
        updatedAtUtc: now,
        uploadedAtUtc: old?.uploadedAtUtc,
      );
      if (complete) {
        await widget.pdfService.generate(report);
      }
      await widget.repository.save(report);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on InterventionReportLayoutException catch (error) {
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } on FormatException catch (error) {
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (error) {
      setState(() {
        _busy = false;
        _error = 'Salvataggio non riuscito: $error';
      });
    }
  }

  void _validateComplete() {
    if (_clientName.text.trim().isEmpty) {
      throw const FormatException('Il nominativo cliente è obbligatorio.');
    }
    if (_description.text.trim().isEmpty) {
      throw const FormatException('La descrizione intervento è obbligatoria.');
    }
    if (_outcome.isEmpty) {
      throw const FormatException('Seleziona l’esito dell’intervento.');
    }
    if (_testResult.isEmpty) {
      throw const FormatException('Seleziona il collaudo OK/KO.');
    }
    if (_technician.text.trim().isEmpty) {
      throw const FormatException('Il tecnico incaricato è obbligatorio.');
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(_date.text.trim())) {
      throw const FormatException('Data non valida: usa AAAA-MM-GG.');
    }
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(_start.text.trim()) ||
        !RegExp(r'^\d{2}:\d{2}$').hasMatch(_end.text.trim())) {
      throw const FormatException(
        'Ora inizio/fine obbligatorie nel formato HH:MM.',
      );
    }
    if (_customerSignature == null) {
      throw const FormatException('Manca la firma del cliente.');
    }
    if (_technicianSignature == null) {
      throw const FormatException('Manca la firma dell’incaricato.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _reportPaper,
    appBar: AppBar(
      backgroundColor: _reportNavy,
      foregroundColor: Colors.white,
      title: Text(
        widget.initialReport == null ? 'Nuovo rapporto' : 'Rapporto intervento',
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Container(
        color: const Color(0xF5F5F7FA),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _save(complete: false),
                child: const Text('Salva bozza'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _reportNavy),
                onPressed: _busy ? null : () => _save(complete: true),
                child: const Text('Completa rapporto'),
              ),
            ),
          ],
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ReportIntroHeader(),
        const SizedBox(height: 14),
        if (_error != null) _ReportBanner(message: _error!, error: true),
        _FormSection(
          number: 1,
          title: 'Cliente',
          children: [
            _LimitedField(
              label: 'Nominativo',
              controller: _clientName,
              maxLength: 60,
            ),
            _LimitedField(
              label: 'Utente',
              controller: _customerUser,
              maxLength: 70,
            ),
            _LimitedField(
              label: 'Indirizzo',
              controller: _address,
              maxLength: 48,
            ),
            _LimitedField(
              label: 'Telefono',
              controller: _phone,
              maxLength: 28,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        _FormSection(
          number: 2,
          title: 'Diagnosi (art. 6)',
          children: [
            for (final item in diagnoses)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _diagnoses.contains(item),
                activeColor: _reportBlue,
                checkColor: Colors.white,
                side: const BorderSide(color: _reportMuted, width: 1.4),
                title: Text(
                  item,
                  style: const TextStyle(
                    color: _reportInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onChanged: _busy
                    ? null
                    : (selected) => setState(() {
                        if (selected == true) {
                          _diagnoses.add(item);
                        } else {
                          _diagnoses.remove(item);
                        }
                      }),
              ),
            _LimitedField(
              label: 'Altro',
              controller: _diagnosisOther,
              maxLength: 72,
            ),
          ],
        ),
        _FormSection(
          number: 3,
          title: 'Intervento',
          children: [
            _LimitedField(
              label: 'Descrizione intervento',
              controller: _description,
              maxLength: 280,
              maxLines: 4,
            ),
            _LimitedField(
              label: 'Materiale consegnato / DDT',
              controller: _delivered,
              maxLength: 82,
              maxLines: 2,
            ),
            _LimitedField(
              label: 'Materiale ritirato',
              controller: _collected,
              maxLength: 150,
              maxLines: 3,
            ),
          ],
        ),
        _FormSection(
          number: 4,
          title: 'Esito dell’intervento',
          children: [
            _ChoicePair(
              value: _outcome,
              positive: 'Risolutivo/Conclusivo',
              negative: 'Non risolutivo',
              onChanged: (value) => setState(() => _outcome = value),
            ),
            const SizedBox(height: 10),
            const Text(
              'Collaudo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            _ChoicePair(
              value: _testResult,
              positive: 'OK',
              negative: 'KO',
              onChanged: (value) => setState(() => _testResult = value),
            ),
            const SizedBox(height: 10),
            _LimitedField(
              label: 'Note',
              controller: _notes,
              maxLength: 72,
              maxLines: 2,
            ),
          ],
        ),
        _FormSection(
          number: 5,
          title: 'Tecnico e tempi',
          children: [
            _LimitedField(
              label: 'Tecnico incaricato',
              controller: _technician,
              maxLength: 64,
            ),
            _LimitedField(
              label: 'Data (AAAA-MM-GG)',
              controller: _date,
              maxLength: 10,
            ),
            Row(
              children: [
                Expanded(
                  child: _LimitedField(
                    label: 'Ora inizio',
                    controller: _start,
                    maxLength: 5,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LimitedField(
                    label: 'Ora fine',
                    controller: _end,
                    maxLength: 5,
                  ),
                ),
              ],
            ),
          ],
        ),
        _FormSection(
          number: 6,
          title: 'Firme',
          children: [
            _SignatureTile(
              label: 'Firma del cliente',
              bytes: _customerSignature,
              onTap: () => _sign(customer: true),
              onClear: () => setState(() => _customerSignature = null),
            ),
            const SizedBox(height: 14),
            _SignatureTile(
              label: 'Firma dell’incaricato',
              bytes: _technicianSignature,
              onTap: () => _sign(customer: false),
              onClear: () => setState(() => _technicianSignature = null),
            ),
          ],
        ),
        _FormSection(
          number: 7,
          title: 'Riservato a Connesi',
          children: [
            _LimitedField(
              label: 'Note interne',
              controller: _reserved,
              maxLength: 150,
              maxLines: 3,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

final class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.number,
    required this.title,
    required this.children,
  });
  final int number;
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _reportLine),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Container(
          color: _reportBlueSoft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _reportBlue),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: _reportBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: _reportNavy,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}

final class _LimitedField extends StatelessWidget {
  const _LimitedField({
    required this.label,
    required this.controller,
    required this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
  });
  final String label;
  final TextEditingController controller;
  final int maxLength;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: maxLines == 1 ? 1 : 2,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: _reportInk),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFBFCFE),
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _reportLine),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _reportBlue, width: 1.5),
        ),
        counterStyle: const TextStyle(color: _reportMuted, fontSize: 11),
      ),
    ),
  );
}

final class _ChoicePair extends StatelessWidget {
  const _ChoicePair({
    required this.value,
    required this.positive,
    required this.negative,
    required this.onChanged,
  });
  final String value;
  final String positive;
  final String negative;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ChoiceButton(
          label: positive,
          selected: value == positive,
          positive: true,
          onTap: () => onChanged(positive),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ChoiceButton(
          label: negative,
          selected: value == negative,
          positive: false,
          onTap: () => onChanged(negative),
        ),
      ),
    ],
  );
}

final class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.positive,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool positive;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = positive ? _reportOk : _reportKo;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .10) : Colors.white,
          border: Border.all(color: selected ? color : _reportLine, width: 1.5),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? color : _reportMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

final class _SignatureTile extends StatelessWidget {
  const _SignatureTile({
    required this.label,
    required this.bytes,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: _reportNavy, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      InkWell(
        onTap: onTap,
        child: Container(
          height: 130,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFE),
            border: Border.all(color: _reportLine, width: 1.5),
            borderRadius: BorderRadius.circular(7),
          ),
          child: bytes == null
              ? const Center(
                  child: Text(
                    'Tocca per firmare col dito o con la penna',
                    style: TextStyle(color: _reportMuted),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.memory(bytes!, fit: BoxFit.contain),
                ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: bytes == null ? null : onClear,
          child: const Text('Cancella'),
        ),
      ),
    ],
  );
}

final class SignatureCaptureScreen extends StatefulWidget {
  const SignatureCaptureScreen({
    required this.title,
    this.initialPng,
    super.key,
  });
  final String title;
  final Uint8List? initialPng;
  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

final class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  bool _saving = false;

  void _start(Offset point) => setState(() => _strokes.add([point]));
  void _move(Offset point) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(point));
  }

  Future<void> _confirm() async {
    if (_strokes.every((stroke) => stroke.length < 2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci la firma prima di confermare.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Firma non acquisibile.');
      if (!mounted) return;
      Navigator.pop(context, data.buffer.asUint8List());
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Firma non salvata: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Firma direttamente sul riquadro. Ruota il telefono se preferisci avere più spazio.',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  color: Colors.white,
                  child: LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _start(details.localPosition),
                      onPanUpdate: (details) => _move(details.localPosition),
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _SignaturePainter(_strokes),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => setState(_strokes.clear),
                    child: const Text('Cancella'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _confirm,
                    child: const Text('Conferma'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

final class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF142030)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
