import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'application/app_auth.dart';
import 'application/app_visual_theme.dart';
import 'application/catalogue_controller.dart';
import 'application/catalogue_export_service.dart';
import 'application/pointing_controller.dart';
import 'application/simulation_export_service.dart';
import 'application/incoming_simulation_bridge.dart';
import 'application/intervention_report_pdf_service.dart';
import 'application/server_upload_services.dart';
import 'application/weather_service.dart';
import 'application/simulation_exchange_codec.dart';
import 'core/core.dart';
import 'infrastructure/android_device_orientation_service.dart';
import 'infrastructure/geolocator_device_location_service.dart';
import 'infrastructure/file_device_installation_id_service.dart';
import 'infrastructure/json_radio_beacon_repository.dart';
import 'infrastructure/json_radio_link_simulation_repository.dart';
import 'infrastructure/json_intervention_report_repository.dart';
import 'infrastructure/open_meteo_elevation_provider.dart';
import 'infrastructure/open_meteo_profile_elevation_provider.dart';
import 'infrastructure/system_radio_beacon_file_picker.dart';
import 'presentation/gps_pointer_app.dart';
import 'presentation/launch_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDirectory = await getApplicationSupportDirectory();
  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
  final visualThemeController = AppVisualThemeController(
    storageFile: File('${supportDirectory.path}/gps_pointer_visual_theme.txt'),
  );
  await visualThemeController.initialize();
  final repository = JsonRadioBeaconRepository(
    File('${supportDirectory.path}/gps_pointer_catalogue.json'),
  );
  final simulationRepository = JsonRadioLinkSimulationRepository(
    File('${supportDirectory.path}/gps_pointer_simulations.json'),
  );
  final interventionReportRepository = JsonInterventionReportRepository(
    File('${supportDirectory.path}/gps_pointer_intervention_reports.json'),
  );
  final identityService = FileDeviceInstallationIdService(
    File('${supportDirectory.path}/gps_pointer_installation_id.txt'),
    File('${supportDirectory.path}/gps_pointer_device_name.txt'),
  );
  final importService = RadioBeaconImportService(
    parser: RadioBeaconFileParser(),
    repository: repository,
  );
  final httpClient = http.Client();
  final locationService = GeolocatorDeviceLocationService();
  final weatherService = OpenMeteoWeatherService(httpClient);
  final elevationProvider = OpenMeteoElevationProvider(httpClient);
  final profileElevationProvider = OpenMeteoProfileElevationProvider(
    httpClient,
  );
  final controller = CatalogueController(
    importService: importService,
    filePicker: SystemRadioBeaconFilePicker(),
    elevationService: RadioBeaconElevationService(elevationProvider),
    locationService: locationService,
    exportService: ShareCatalogueExportService(),
    identityService: identityService,
  );
  await controller.initialize();
  final authController = AppAuthController(
    api: HttpAppAuthApi(
      client: httpClient,
      baseUri: Uri.parse('https://gpspointer.ernet.it:9443'),
    ),
    store: SecureAppAuthStore(),
    deviceUnlock: LocalDeviceUnlockService(),
    deviceId: controller.installationId,
    deviceNameProvider: () =>
        controller.deviceDisplayName ?? 'GPS Pointer Android',
    appVersion: appVersion,
  );
  final serverUploadService = GpsPointerServerUploadService(
    client: httpClient,
    authController: authController,
    baseUri: Uri.parse('https://gpspointer.ernet.it:9443'),
    deviceId: controller.installationId,
    deviceName: controller.deviceDisplayName ?? 'GPS Pointer Android',
  );
  runApp(
    LaunchSplashGate(
      theme: visualThemeController.theme,
      child: GpsPointerApp(
        authController: authController,
        visualThemeController: visualThemeController,
        controller: controller,
        locationService: locationService,
        weatherService: weatherService,
        profileElevationProvider: profileElevationProvider,
        simulationRepository: simulationRepository,
        simulationExportService: ShareSimulationExportService(),
        interventionReportRepository: interventionReportRepository,
        interventionReportPdfService: const InterventionReportPdfService(),
        serverUploadService: serverUploadService,
        pointingController: PointingController(
          locationService: locationService,
          elevationProvider: elevationProvider,
          orientationService: AndroidDeviceOrientationService(),
        ),
      ),
    ),
  );

  Future<bool> promptIncomingImport({
    required IncomingSimulationPayload payload,
    required SimulationExchangeDocument document,
  }) async {
    final navigator = gpsPointerNavigatorKey.currentState;
    if (navigator == null) return false;

    final simulation = document.simulation;
    final typeLabel = simulation.kind == RadioLinkSimulationKind.coverage
        ? 'Copertura'
        : 'PTP';

    return await navigator.push<bool>(
          DialogRoute<bool>(
            context: navigator.context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Apri con GPS Pointer'),
              content: Text(
                '${payload.name}\n\n'
                '${simulation.name}\n'
                'Tipo: $typeLabel\n\n'
                'Importare questa simulazione nell’archivio locale?',
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
          ),
        ) ??
        false;
  }

  void showIncomingMessage(String message) {
    final context = gpsPointerNavigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> importIncoming(IncomingSimulationPayload payload) async {
    SimulationExchangeDocument document;
    try {
      document = SimulationExchangeCodec.decode(payload.content);
    } on FormatException catch (error) {
      showIncomingMessage('File .gpspsim non valido: ${error.message}');
      return;
    }

    // Wait only for the Navigator itself. No BuildContext is retained across
    // any await boundary.
    for (var attempt = 0; attempt < 30; attempt++) {
      if (gpsPointerNavigatorKey.currentState != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (gpsPointerNavigatorKey.currentState == null) return;

    final approved = await promptIncomingImport(
      payload: payload,
      document: document,
    );
    if (!approved) return;

    final simulation = document.simulation;
    final typeLabel = simulation.kind == RadioLinkSimulationKind.coverage
        ? 'Copertura'
        : 'PTP';

    await simulationRepository.save(simulation);

    // Resolve the messenger context only AFTER persistence completes.
    showIncomingMessage(
      '$typeLabel importata. Apri il relativo archivio dalla Home.',
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    IncomingSimulationBridge.initialize(importIncoming);
  });
}
