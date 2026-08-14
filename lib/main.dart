import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'application/catalogue_controller.dart';
import 'application/catalogue_export_service.dart';
import 'application/pointing_controller.dart';
import 'core/core.dart';
import 'infrastructure/android_device_orientation_service.dart';
import 'infrastructure/geolocator_device_location_service.dart';
import 'infrastructure/file_device_installation_id_service.dart';
import 'infrastructure/json_radio_beacon_repository.dart';
import 'infrastructure/open_meteo_elevation_provider.dart';
import 'infrastructure/system_radio_beacon_file_picker.dart';
import 'presentation/gps_pointer_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDirectory = await getApplicationSupportDirectory();
  final repository = JsonRadioBeaconRepository(
    File('${supportDirectory.path}/gps_pointer_catalogue.json'),
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
  final controller = CatalogueController(
    importService: importService,
    filePicker: SystemRadioBeaconFilePicker(),
    elevationService: RadioBeaconElevationService(elevationProvider),
    locationService: locationService,
    exportService: ShareCatalogueExportService(),
    identityService: identityService,
  );
  await controller.initialize();
  runApp(
    GpsPointerApp(
      controller: controller,
      pointingController: PointingController(
        locationService: locationService,
        elevationProvider: elevationProvider,
        orientationService: AndroidDeviceOrientationService(),
      ),
    ),
  );
}
