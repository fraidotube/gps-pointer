import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../application/app_auth.dart';
import '../application/app_visual_theme.dart';
import '../application/catalogue_controller.dart';

final class ServerCatalogueScreen extends StatefulWidget {
  const ServerCatalogueScreen({
    required this.authController,
    required this.controller,
    super.key,
  });

  final AppAuthController authController;
  final CatalogueController controller;

  @override
  State<ServerCatalogueScreen> createState() => _ServerCatalogueScreenState();
}

final class _ServerCatalogueScreenState extends State<ServerCatalogueScreen> {
  static final Uri _serverCatalogueUri = Uri.parse(
    'https://gpspointer.ernet.it:9443/api/v1/catalog/export',
  );

  AppAuthController get authController => widget.authController;
  CatalogueController get controller => widget.controller;

  Future<String> _fetchServerCatalogue(String token) async {
    final response = await http
        .get(_serverCatalogueUri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      throw const _ServerCatalogueFailure('unauthorized', 'Sessione scaduta.');
    }
    if (response.statusCode != 200) {
      throw _ServerCatalogueFailure(
        'server_error',
        'Download catalogo non riuscito (HTTP ${response.statusCode}).',
      );
    }
    return response.body;
  }

  Future<void> _downloadFromServer() async {
    try {
      var token = authController.accessToken;
      if (token == null) {
        throw const _ServerCatalogueFailure(
          'unauthorized',
          'Sessione non disponibile. Accedi nuovamente.',
        );
      }

      String content;
      try {
        content = await _fetchServerCatalogue(token);
      } on _ServerCatalogueFailure catch (error) {
        if (error.code != 'unauthorized') rethrow;
        if (!await authController.refreshAccessToken()) rethrow;
        token = authController.accessToken;
        if (token == null) {
          throw const _ServerCatalogueFailure(
            'unauthorized',
            'Sessione non disponibile. Accedi nuovamente.',
          );
        }
        content = await _fetchServerCatalogue(token);
      }

      await controller.importCatalogueFromServer(
        content: content,
        approve: (preview) async {
          if (!mounted) return false;
          return await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Aggiorna catalogo dal server'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${preview.beaconCount ?? 0} radiofari validati.'),
                      const SizedBox(height: 10),
                      const Text(
                        'Il catalogo locale verrà sostituito solo dopo la '
                        'validazione completa del file ricevuto.',
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Annulla'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Aggiorna'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is _ServerCatalogueFailure
          ? error.message
          : 'Catalogo server non scaricato: $error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _importTxt() async {
    await controller.importCatalogue(
      approve: (preview) async {
        if (!mounted) return false;
        return await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Importa catalogo TXT'),
                content: const Text(
                  'Il file verrà validato completamente prima di sostituire '
                  'il catalogo locale.',
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
      },
    );
  }

  Future<void> _clearLocal() async {
    final count = controller.catalogue?.beacons.length ?? 0;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il catalogo locale è già vuoto.')),
      );
      return;
    }
    final approved =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Azzera catalogo locale'),
            content: Text(
              'Verranno rimossi dal telefono $count radiofari.\n\n'
              'Account, simulazioni e impostazioni non verranno modificati.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Azzera'),
              ),
            ],
          ),
        ) ??
        false;
    if (approved) await controller.clearCatalogue();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final catalogue = controller.catalogue;
      final count = catalogue?.beacons.length ?? 0;
      return Scaffold(
        appBar: AppBar(title: const Text('Scarica dal server')),
        body: GpsThemeBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (controller.busy) const LinearProgressIndicator(),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cloud_sync_outlined, size: 28),
                            SizedBox(width: 10),
                            Text(
                              'Catalogo postazioni',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('$count radiofari presenti sul telefono'),
                        if (catalogue != null)
                          Text('Archivio: ${catalogue.sourceFileName}'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: controller.busy || authController.busy
                                ? null
                                : _downloadFromServer,
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Text('AGGIORNA DAL SERVER'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'L’aggiornamento dal server è transazionale: il '
                          'catalogo locale cambia solo dopo la validazione '
                          'completa del file ricevuto.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Gestione locale',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: controller.busy ? null : _importTxt,
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('IMPORTA TXT'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: controller.busy
                              ? null
                              : controller.exportCatalogue,
                          icon: const Icon(Icons.ios_share_outlined),
                          label: const Text('ESPORTA TXT'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: controller.busy ? null : _clearLocal,
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('AZZERA CATALOGO LOCALE'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

final class _ServerCatalogueFailure implements Exception {
  const _ServerCatalogueFailure(this.code, this.message);

  final String code;
  final String message;
}
