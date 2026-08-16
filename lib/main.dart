import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'application/app_auth.dart';
import 'application/catalogue_controller.dart';
import 'application/catalogue_export_service.dart';
import 'application/pointing_controller.dart';
import 'application/simulation_export_service.dart';
import 'core/core.dart';
import 'infrastructure/android_device_orientation_service.dart';
import 'infrastructure/geolocator_device_location_service.dart';
import 'infrastructure/file_device_installation_id_service.dart';
import 'infrastructure/json_radio_beacon_repository.dart';
import 'infrastructure/json_radio_link_simulation_repository.dart';
import 'infrastructure/open_meteo_elevation_provider.dart';
import 'infrastructure/open_meteo_profile_elevation_provider.dart';
import 'infrastructure/system_radio_beacon_file_picker.dart';
import 'presentation/gps_pointer_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDirectory = await getApplicationSupportDirectory();
  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
  final repository = JsonRadioBeaconRepository(
    File('${supportDirectory.path}/gps_pointer_catalogue.json'),
  );
  final simulationRepository = JsonRadioLinkSimulationRepository(
    File('${supportDirectory.path}/gps_pointer_simulations.json'),
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
  runApp(
    GpsPointerApp(
      authController: authController,
      controller: controller,
      locationService: locationService,
      profileElevationProvider: profileElevationProvider,
      simulationRepository: simulationRepository,
      simulationExportService: ShareSimulationExportService(),
      pointingController: PointingController(
        locationService: locationService,
        elevationProvider: elevationProvider,
        orientationService: AndroidDeviceOrientationService(),
      ),
    ),
  );
}
