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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
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
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Row(
                children: [
                  Icon(
                    Icons.monitor_heart_outlined,
                    size: 25,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Centro diagnostico',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Strumenti tecnici e log di campo. Le funzioni di puntamento '
                'operative non vengono modificate da questa schermata.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),

              const _DebugSectionTitle('Strumenti diagnostici'),
              const SizedBox(height: 8),
              _DiagnosticGroup(
                children: [
                  const _DiagnosticToolRow(
                    icon: Icons.explore_outlined,
                    title: 'Azimut',
                    subtitle:
                        'Motore 2.2 invariato • bandierine e log TXT. Accuratezza in validazione cross-device.',
                    state: 'BETA',
                  ),
                  const _DiagnosticToolRow(
                    icon: Icons.camera_alt_outlined,
                    title: 'AR',
                    subtitle:
                        'Bandierine AR persistenti. Accuratezza orizzontale in validazione cross-device.',
                    state: 'BETA',
                  ),
                  _DiagnosticToolRow(
                    icon: Icons.sensors,
                    title: 'Diagnostica bussola',
                    subtitle:
                        'Test 4×90 verticale/orizzontale/piatto, Rotation Vector Android e traccia sensori 30 s. Non modifica il motore.',
                    state: 'SAFE',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const CompassSensorDiagnosticsScreen(),
                        ),
                      );
                      if (mounted) await _refresh();
                    },
                  ),
                  _DiagnosticToolRow(
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
                  const _DiagnosticToolRow(
                    icon: Icons.tune,
                    title: 'Calibrazioni',
                    subtitle:
                        'Nessuna correzione automatica nelle schermate operative: le prove V3 restano isolate nel laboratorio.',
                    state: 'SAFE',
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const _DebugSectionTitle('File diagnostici'),
              const SizedBox(height: 8),
              FutureBuilder<List<DiagnosticLogEntry>>(
                future: _logs,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final logs = snapshot.data ?? const <DiagnosticLogEntry>[];
                  if (logs.isEmpty) {
                    return const _DiagnosticGroup(
                      children: [
                        _DiagnosticToolRow(
                          icon: Icons.description_outlined,
                          title: 'Nessun file salvato',
                          subtitle:
                              'Le prossime bandierine Azimut verranno archiviate automaticamente.',
                          state: 'VUOTO',
                        ),
                      ],
                    );
                  }

                  return _DiagnosticGroup(
                    children: [
                      for (final log in logs)
                        _LogRow(
                          log: log,
                          onShare: () => _share(log),
                          onOpen: () => _open(log),
                          onDelete: () => _delete(log),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
              const _DebugSectionTitle('Applicazione'),
              const SizedBox(height: 8),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  return _DiagnosticGroup(
                    children: [
                      _DiagnosticToolRow(
                        icon: Icons.info_outline,
                        title: 'Build applicazione',
                        subtitle: info == null
                            ? 'Lettura versione...'
                            : '${info.version}+${info.buildNumber}',
                        state: 'INFO',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

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

final class _DebugSectionTitle extends StatelessWidget {
  const _DebugSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w800,
      letterSpacing: .8,
    ),
  );
}

final class _DiagnosticGroup extends StatelessWidget {
  const _DiagnosticGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor.withValues(alpha: .35);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .22),
        border: Border(
          top: BorderSide(color: divider),
          bottom: BorderSide(color: divider),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, indent: 54, color: divider),
          ],
        ],
      ),
    );
  }
}

final class _DiagnosticToolRow extends StatelessWidget {
  const _DiagnosticToolRow({
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      leading: Icon(icon, size: 24, color: scheme.primary),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          _StateLabel(state),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, size: 21),
      onTap: onTap,
    );
  }
}

final class _StateLabel extends StatelessWidget {
  const _StateLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

final class _LogRow extends StatelessWidget {
  const _LogRow({
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
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
    leading: Icon(
      Icons.description_outlined,
      size: 23,
      color: Theme.of(context).colorScheme.primary,
    ),
    title: Text(
      log.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text('${_date(log.modifiedAt)} • ${_size(log.sizeBytes)}'),
    onTap: onOpen,
    trailing: PopupMenuButton<String>(
      tooltip: 'Azioni file',
      onSelected: (value) {
        if (value == 'share') onShare();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'share', child: Text('Condividi TXT')),
        PopupMenuItem(value: 'delete', child: Text('Elimina')),
      ],
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
