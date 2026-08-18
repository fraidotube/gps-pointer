import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../application/catalogue_controller.dart';
import '../application/diagnostic_log_store.dart';
import 'azimuth_v3_lab_screen.dart';
import 'compass_sensor_diagnostics_screen.dart';

final class DebugToolsScreen extends StatefulWidget {
  const DebugToolsScreen({required this.controller, super.key});

  final CatalogueController controller;

  @override
  State<DebugToolsScreen> createState() => _DebugToolsScreenState();
}

final class _DebugToolsScreenState extends State<DebugToolsScreen> {
  late Future<List<DiagnosticLogEntry>> _logs;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _logs = DiagnosticLogStore.list();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _logs;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Debug'),
      actions: [
        IconButton(
          tooltip: 'Aggiorna',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centro diagnostico',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'I log diagnostici vengono salvati come file TXT '
                      'nell’area privata dell’app. Restano recuperabili qui '
                      'anche dopo aver chiuso la schermata di misura.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _ToolCard(
              icon: Icons.explore_outlined,
              title: 'Azimut',
              subtitle:
                  'Motore 2.2 invariato • bandierine e log TXT. Accuratezza in validazione cross-device.',
              state: 'BETA',
            ),
            const SizedBox(height: 10),
            const _ToolCard(
              icon: Icons.camera_alt_outlined,
              title: 'AR',
              subtitle:
                  'Bandierine AR persistenti. Accuratezza orizzontale in validazione cross-device.',
              state: 'BETA',
            ),
            const SizedBox(height: 10),
            _ToolCard(
              icon: Icons.sensors,
              title: 'Diagnostica bussola',
              subtitle:
                  'Test 4×90 verticale/orizzontale/piatto, Rotation Vector Android e traccia sensori 30 s. Non modifica il motore.',
              state: 'SAFE',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CompassSensorDiagnosticsScreen(),
                  ),
                );
                if (mounted) await _refresh();
              },
            ),
            const SizedBox(height: 10),
            _ToolCard(
              icon: Icons.science_outlined,
              title: 'Azimuth V3 Lab',
              subtitle:
                  'V2 invariato + V3 gyro ancorato, fusione lenta, ancora manuale diagnostica e test deriva 60 s.',
              state: 'EXPERIMENTAL',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AzimuthV3LabScreen(controller: widget.controller),
                  ),
                );
                if (mounted) await _refresh();
              },
            ),
            const SizedBox(height: 10),
            const _ToolCard(
              icon: Icons.tune,
              title: 'Calibrazioni',
              subtitle:
                  'Nessuna correzione automatica nelle schermate operative: le prove V3 restano isolate nel laboratorio.',
              state: 'SAFE',
            ),
            const SizedBox(height: 14),
            Text(
              'File diagnostici',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<DiagnosticLogEntry>>(
              future: _logs,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final logs = snapshot.data ?? const <DiagnosticLogEntry>[];
                if (logs.isEmpty) {
                  return const Card(
                    child: ListTile(
                      leading: Icon(Icons.description_outlined),
                      title: Text('Nessun file salvato'),
                      subtitle: Text(
                        'Le prossime bandierine Azimut verranno archiviate automaticamente.',
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final log in logs) ...[
                      _LogCard(
                        log: log,
                        onShare: () => _share(log),
                        onOpen: () => _open(log),
                        onDelete: () => _delete(log),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Build applicazione'),
                    subtitle: Text(
                      info == null
                          ? 'Lettura versione...'
                          : '${info.version}+${info.buildNumber}',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _share(DiagnosticLogEntry log) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(log.path)],
        subject: 'GPS Pointer debug ${log.name}',
      ),
    );
  }

  Future<void> _open(DiagnosticLogEntry log) async {
    final content = await DiagnosticLogStore.read(log.path);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(log.name),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(child: SelectableText(content)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Chiudi'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _share(log);
            },
            icon: const Icon(Icons.ios_share),
            label: const Text('Condividi TXT'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(DiagnosticLogEntry log) async {
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Elimina log'),
            content: Text('Eliminare definitivamente ${log.name}?'),
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
    if (!approved) return;
    await DiagnosticLogStore.delete(log.path);
    if (!mounted) return;
    setState(_reload);
  }
}

final class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        state,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.log,
    required this.onShare,
    required this.onOpen,
    required this.onDelete,
  });

  final DiagnosticLogEntry log;
  final VoidCallback onShare;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(log.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${_date(log.modifiedAt)} • ${_size(log.sizeBytes)}'),
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'share') onShare();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'share', child: Text('Condividi TXT')),
          PopupMenuItem(value: 'delete', child: Text('Elimina')),
        ],
      ),
    ),
  );

  static String _date(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String _size(int bytes) =>
      bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';
}
