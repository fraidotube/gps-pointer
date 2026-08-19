import 'package:flutter/material.dart';

import '../application/app_visual_theme.dart';
import '../application/simulation_exchange_codec.dart';
import '../application/simulation_export_service.dart';
import '../application/simulation_import_service.dart';
import '../application/simulation_pdf_service.dart';
import '../application/server_upload_services.dart';
import '../core/simulation/radio_link_simulation.dart';
import '../core/simulation/radio_link_simulation_repository.dart';
import 'simulation_review_screen.dart';

final class SimulationLibraryScreen extends StatefulWidget {
  const SimulationLibraryScreen({
    required this.kind,
    required this.repository,
    required this.exportService,
    required this.pdfService,
    required this.importService,
    required this.deviceId,
    required this.deviceName,
    required this.serverUploadService,
    required this.onCreate,
    super.key,
  });

  final RadioLinkSimulationKind kind;
  final RadioLinkSimulationRepository repository;
  final SimulationExportService exportService;
  final SimulationPdfService pdfService;
  final SimulationImportService importService;
  final String deviceId;
  final String deviceName;
  final GpsPointerServerUploadService serverUploadService;
  final Future<void> Function() onCreate;

  @override
  State<SimulationLibraryScreen> createState() =>
      _SimulationLibraryScreenState();
}

final class _SimulationLibraryScreenState
    extends State<SimulationLibraryScreen> {
  late Future<List<RadioLinkSimulation>> _future;
  bool _busy = false;

  bool get _coverage => widget.kind == RadioLinkSimulationKind.coverage;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.repository.loadAll().then(
      (items) => items
          .where((item) => item.kind == widget.kind)
          .toList(growable: false),
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_coverage ? 'Coperture' : 'Punto Punto • PTP'),
      actions: [
        IconButton(
          tooltip: 'Importa .gpspsim',
          onPressed: _busy ? null : _import,
          icon: const Icon(Icons.file_open_outlined),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : _create,
      icon: const Icon(Icons.add),
      label: Text(_coverage ? 'NUOVA COPERTURA' : 'NUOVO PTP'),
    ),
    body: GpsThemeBackground(
      child: SafeArea(
        child: FutureBuilder<List<RadioLinkSimulation>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Errore archivio simulazioni: ${snapshot.error}'),
                ),
              );
            }
            final items = snapshot.data ?? const <RadioLinkSimulation>[];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _HeaderCard(
                    coverage: _coverage,
                    count: items.length,
                    onCreate: _busy ? null : _create,
                    onImport: _busy ? null : _import,
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              _coverage
                                  ? Icons.radar
                                  : Icons.swap_horiz_rounded,
                              size: 42,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _coverage
                                  ? 'Nessuna copertura salvata'
                                  : 'Nessun collegamento PTP salvato',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Crea una nuova simulazione oppure importa '
                              'un file .gpspsim ricevuto da un altro tecnico.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final simulation in items) ...[
                      _SimulationCard(
                        simulation: simulation,
                        onOpen: () => _open(simulation),
                        onDuplicate: () => _duplicate(simulation),
                        onExport: () => _export(simulation),
                        onPdf: () => _pdf(simulation),
                        onUpload: () => _upload(simulation),
                        onDelete: () => _delete(simulation),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  Future<void> _create() async {
    await widget.onCreate();
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _open(RadioLinkSimulation simulation) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SimulationReviewScreen(
          simulation: simulation,
          onExport: () => _export(simulation),
          onDuplicate: () => _duplicate(simulation),
          onDelete: () => _deleteFromDetail(simulation),
        ),
      ),
    );
    if (deleted == true && mounted) setState(_reload);
  }

  Future<void> _export(RadioLinkSimulation simulation) =>
      widget.exportService.export(
        simulation: simulation,
        deviceId: widget.deviceId,
        deviceName: widget.deviceName,
      );

  Future<void> _pdf(RadioLinkSimulation simulation) =>
      widget.pdfService.createAndShare(simulation);

  Future<void> _upload(RadioLinkSimulation simulation) async {
    setState(() => _busy = true);
    try {
      await widget.serverUploadService.uploadSimulation(simulation);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulazione inviata al server.')),
      );
    } on ServerUploadException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _duplicate(RadioLinkSimulation source) async {
    final now = DateTime.now().toUtc();
    final copy = RadioLinkSimulation(
      id: '${now.microsecondsSinceEpoch}',
      name: '${source.name} • copia',
      kind: source.kind,
      beaconId: source.beaconId,
      beaconName: source.beaconName,
      startPosition: source.startPosition,
      startGroundElevationMeters: source.startGroundElevationMeters,
      buildingHeightMeters: source.buildingHeightMeters,
      targetPosition: source.targetPosition,
      targetGroundElevationMeters: source.targetGroundElevationMeters,
      targetPoleHeightMeters: source.targetPoleHeightMeters,
      frequencyGhz: source.frequencyGhz,
      azimuthDegrees: source.azimuthDegrees,
      profile: source.profile,
      createdAtUtc: now,
    );
    await widget.repository.save(copy);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Simulazione duplicata.')));
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final picked = await widget.importService.pickAndDecode();
      if (picked == null || !mounted) return;
      await _confirmAndSaveImport(picked.document, sourceLabel: picked.name);
    } on FormatException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (error) {
      if (!mounted) return;
      _showError('Importazione non riuscita: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndSaveImport(
    SimulationExchangeDocument document, {
    required String sourceLabel,
  }) async {
    final simulation = document.simulation;
    final typeLabel = simulation.kind == RadioLinkSimulationKind.coverage
        ? 'Copertura'
        : 'PTP';

    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Importa simulazione'),
            content: Text(
              '$sourceLabel\n\n'
              '${simulation.name}\n'
              'Tipo: $typeLabel\n'
              'Origine: ${document.sourceDeviceName.isEmpty ? "non indicata" : document.sourceDeviceName}\n\n'
              'Se esiste già una simulazione con lo stesso ID verrà sostituita.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Importa'),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved) return;

    await widget.repository.save(simulation);
    if (!mounted) return;
    setState(_reload);

    final sameArchive = simulation.kind == widget.kind;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sameArchive
              ? 'Simulazione importata.'
              : 'Simulazione importata nell’archivio $typeLabel.',
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(RadioLinkSimulation simulation) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Elimina simulazione'),
          content: Text('Eliminare “${simulation.name}”?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Elimina'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _delete(RadioLinkSimulation simulation) async {
    if (!await _confirmDelete(simulation)) return;
    await widget.repository.delete(simulation.id);
    if (!mounted) return;
    setState(_reload);
  }

  Future<bool> _deleteFromDetail(RadioLinkSimulation simulation) async {
    if (!await _confirmDelete(simulation)) return false;
    await widget.repository.delete(simulation.id);
    return true;
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

final class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.coverage,
    required this.count,
    required this.onCreate,
    required this.onImport,
  });

  final bool coverage;
  final int count;
  final VoidCallback? onCreate;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(coverage ? Icons.radar : Icons.swap_horiz_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  coverage ? 'Archivio Coperture' : 'Archivio PTP',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('$count'),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'I file .gpspsim conservano tutti i dati della simulazione '
            'e possono essere condivisi e reimportati in GPS Pointer.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('NUOVA'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('IMPORTA'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _SimulationCard extends StatelessWidget {
  const _SimulationCard({
    required this.simulation,
    required this.onOpen,
    required this.onDuplicate,
    required this.onExport,
    required this.onPdf,
    required this.onUpload,
    required this.onDelete,
  });

  final RadioLinkSimulation simulation;
  final VoidCallback onOpen;
  final VoidCallback onDuplicate;
  final VoidCallback onExport;
  final VoidCallback onPdf;
  final VoidCallback onUpload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                simulation.kind == RadioLinkSimulationKind.coverage
                    ? Icons.cell_tower
                    : Icons.swap_horiz_rounded,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      simulation.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${simulation.beaconName} • '
                      '${_localDate(simulation.createdAtUtc)}',
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'duplicate') onDuplicate();
                  if (value == 'export') onExport();
                  if (value == 'pdf') onPdf();
                  if (value == 'upload') onUpload();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'duplicate', child: Text('Duplica')),
                  PopupMenuItem(
                    value: 'export',
                    child: Text('Esporta .gpspsim'),
                  ),
                  PopupMenuItem(value: 'pdf', child: Text('PDF')),
                  PopupMenuItem(
                    value: 'upload',
                    child: Text('Invia al server'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Elimina')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _Badge('${simulation.profile.distanceKm.toStringAsFixed(2)} km'),
              _Badge('Az ${simulation.azimuthDegrees.toStringAsFixed(1)}°'),
              _Badge(
                simulation.profile.lineOfSightClear
                    ? 'LOS libera'
                    : 'LOS ostruita',
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: const Text('APRI'),
          ),
        ],
      ),
    ),
  );
}

final class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: .4),
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(text),
    ),
  );
}

final class SimulationDetailScreen extends StatelessWidget {
  const SimulationDetailScreen({
    required this.simulation,
    required this.onExport,
    required this.onPdf,
    required this.onDuplicate,
    required this.onDelete,
    super.key,
  });

  final RadioLinkSimulation simulation;
  final Future<void> Function() onExport;
  final Future<void> Function() onPdf;
  final Future<void> Function() onDuplicate;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final p = simulation.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio simulazione')),
      body: GpsThemeBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                simulation.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${simulation.beaconName} • '
                '${_localDate(simulation.createdAtUtc)}',
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailLine(
                        'Tipo',
                        simulation.kind == RadioLinkSimulationKind.coverage
                            ? 'Copertura'
                            : 'Punto-Punto',
                      ),
                      _DetailLine(
                        'Distanza',
                        '${p.distanceKm.toStringAsFixed(2)} km',
                      ),
                      _DetailLine(
                        'Azimut vero',
                        '${simulation.azimuthDegrees.toStringAsFixed(2)}°',
                      ),
                      _DetailLine(
                        'Tilt teorico',
                        '${p.tiltDegrees >= 0 ? '+' : ''}'
                            '${p.tiltDegrees.toStringAsFixed(2)}°',
                      ),
                      _DetailLine(
                        'LOS',
                        p.lineOfSightClear ? 'Libera' : 'Ostruita',
                      ),
                      if (p.firstFresnelClear != null)
                        _DetailLine(
                          'Prima Fresnel',
                          p.firstFresnelClear! ? 'Libera' : 'Ostruita',
                        ),
                      _DetailLine(
                        'Partenza',
                        '${simulation.startPosition.latitude.toStringAsFixed(7)}, '
                            '${simulation.startPosition.longitude.toStringAsFixed(7)}',
                      ),
                      _DetailLine(
                        simulation.kind == RadioLinkSimulationKind.coverage
                            ? 'Postazione Radio'
                            : 'Punto B',
                        '${simulation.targetPosition.latitude.toStringAsFixed(7)}, '
                        '${simulation.targetPosition.longitude.toStringAsFixed(7)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('CONDIVIDI .GPSPSIM'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('GENERA / CONDIVIDI PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onDuplicate,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('DUPLICA'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final deleted = await onDelete();
                  if (deleted && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('ELIMINA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

String _localDate(DateTime value) {
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Backward-compatible aggregate archive used by the legacy catalogue action.
final class SimulationsScreen extends StatefulWidget {
  const SimulationsScreen({
    required this.repository,
    required this.exportService,
    required this.deviceId,
    required this.deviceName,
    super.key,
  });

  final RadioLinkSimulationRepository repository;
  final SimulationExportService exportService;
  final String deviceId;
  final String deviceName;

  @override
  State<SimulationsScreen> createState() => _SimulationsScreenState();
}

final class _SimulationsScreenState extends State<SimulationsScreen> {
  late Future<List<RadioLinkSimulation>> _future;
  final SimulationPdfService _pdfService = const SimulationPdfService();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.repository.loadAll();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Simulazioni')),
    body: GpsThemeBackground(
      child: SafeArea(
        child: FutureBuilder<List<RadioLinkSimulation>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Errore archivio simulazioni: ${snapshot.error}'),
                ),
              );
            }
            final items = snapshot.data ?? const <RadioLinkSimulation>[];
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nessuna simulazione salvata.'),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final simulation = items[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      simulation.kind == RadioLinkSimulationKind.coverage
                          ? Icons.radar
                          : Icons.swap_horiz_rounded,
                    ),
                    title: Text(simulation.name),
                    subtitle: Text(
                      '${simulation.kind == RadioLinkSimulationKind.coverage ? "Copertura" : "PTP"} • '
                      '${simulation.profile.distanceKm.toStringAsFixed(2)} km',
                    ),
                    onTap: () => _open(simulation),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'export') _export(simulation);
                        if (value == 'pdf') _pdf(simulation);
                        if (value == 'delete') _delete(simulation);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'export',
                          child: Text('Esporta .gpspsim'),
                        ),
                        PopupMenuItem(value: 'pdf', child: Text('PDF')),
                        PopupMenuItem(value: 'delete', child: Text('Elimina')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );

  Future<void> _open(RadioLinkSimulation simulation) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SimulationReviewScreen(
          simulation: simulation,
          onExport: () => _export(simulation),
          onDuplicate: () => _duplicate(simulation),
          onDelete: () => _deleteFromDetail(simulation),
        ),
      ),
    );
    if (deleted == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _export(RadioLinkSimulation simulation) =>
      widget.exportService.export(
        simulation: simulation,
        deviceId: widget.deviceId,
        deviceName: widget.deviceName,
      );

  Future<void> _pdf(RadioLinkSimulation simulation) =>
      _pdfService.createAndShare(simulation);

  Future<void> _duplicate(RadioLinkSimulation source) async {
    final now = DateTime.now().toUtc();
    await widget.repository.save(
      RadioLinkSimulation(
        id: '${now.microsecondsSinceEpoch}',
        name: '${source.name} • copia',
        kind: source.kind,
        beaconId: source.beaconId,
        beaconName: source.beaconName,
        startPosition: source.startPosition,
        startGroundElevationMeters: source.startGroundElevationMeters,
        buildingHeightMeters: source.buildingHeightMeters,
        targetPosition: source.targetPosition,
        targetGroundElevationMeters: source.targetGroundElevationMeters,
        targetPoleHeightMeters: source.targetPoleHeightMeters,
        frequencyGhz: source.frequencyGhz,
        azimuthDegrees: source.azimuthDegrees,
        profile: source.profile,
        createdAtUtc: now,
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<bool> _confirmDelete(RadioLinkSimulation simulation) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Elimina simulazione'),
          content: Text('Eliminare “${simulation.name}”?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Elimina'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _delete(RadioLinkSimulation simulation) async {
    if (!await _confirmDelete(simulation)) return;
    await widget.repository.delete(simulation.id);
    if (mounted) setState(_reload);
  }

  Future<bool> _deleteFromDetail(RadioLinkSimulation simulation) async {
    if (!await _confirmDelete(simulation)) return false;
    await widget.repository.delete(simulation.id);
    return true;
  }
}
