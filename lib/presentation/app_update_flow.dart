import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../application/app_update_service.dart';
import '../infrastructure/android_apk_installer.dart';

void scheduleAutomaticAppUpdateCheck(
  AppUpdateService service,
  GlobalKey<NavigatorState> navigatorKey,
) {
  unawaited(_runAutomaticAppUpdateCheck(service, navigatorKey));
}

Future<void> _runAutomaticAppUpdateCheck(
  AppUpdateService service,
  GlobalKey<NavigatorState> navigatorKey,
) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null && currentContext.mounted) {
        await showAppUpdateCheck(currentContext, service, manual: false);
      }
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

Future<void> showAppUpdateCheck(
  BuildContext context,
  AppUpdateService service, {
  required bool manual,
}) async {
  AppUpdateCheckResult result;
  try {
    result = await service.check();
  } on Object catch (error) {
    if (!manual || !context.mounted) return;
    _showMessage(context, _friendlyError(error));
    return;
  }

  if (!context.mounted) return;
  final update = result.update;
  if (update == null) {
    if (manual) {
      _showMessage(
        context,
        'GPS Pointer è aggiornato '
        '(${result.localVersion}+${result.localBuild}).',
      );
    }
    return;
  }

  final approved =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aggiornamento disponibile'),
          content: Text(
            'È disponibile GPS Pointer ${update.release} '
            '(build ${update.build}).\n\n'
            'Versione installata: ${result.localVersion}+${result.localBuild}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Più tardi'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.download),
              label: const Text('SCARICA'),
            ),
          ],
        ),
      ) ??
      false;
  if (!approved || !context.mounted) return;

  _showMessage(context, 'Download e verifica aggiornamento in corso…');

  File apkFile;
  try {
    apkFile = await service.downloadAndVerify(update);
  } on Object catch (error) {
    if (context.mounted) _showMessage(context, _friendlyError(error));
    return;
  }
  if (!context.mounted) return;

  const installer = AndroidApkInstaller();
  while (context.mounted) {
    try {
      final launchResult = await installer.install(apkFile);
      if (!context.mounted) return;
      if (launchResult == ApkInstallLaunchResult.started) return;

      final retry =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Autorizza installazione'),
              content: const Text(
                'Android ha aperto l’autorizzazione “Installa app sconosciute” '
                'per GPS Pointer. Abilita “Consenti da questa origine”, torna '
                'nell’app e premi RIPROVA.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('RIPROVA'),
                ),
              ],
            ),
          ) ??
          false;
      if (!retry) return;
    } on Object catch (error) {
      if (context.mounted) _showMessage(context, _friendlyError(error));
      return;
    }
  }
}

String _friendlyError(Object error) {
  if (error is AppUpdateException) return error.message;
  return 'Aggiornamento non riuscito: $error';
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
