import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/application/app_auth.dart';
import 'package:gps_pointer/application/app_visual_theme.dart';
import 'package:gps_pointer/application/catalogue_controller.dart';
import 'package:gps_pointer/application/catalogue_export_service.dart';
import 'package:gps_pointer/application/device_installation_id_service.dart';
import 'package:gps_pointer/application/device_location_service.dart';
import 'package:gps_pointer/application/device_orientation_service.dart';
import 'package:gps_pointer/application/pointing_controller.dart';
import 'package:gps_pointer/application/simulation_export_service.dart';
import 'package:gps_pointer/application/radio_beacon_file_picker.dart';
import 'package:gps_pointer/core/core.dart';
import 'package:gps_pointer/presentation/gps_pointer_app.dart';

void main() {
  testWidgets('first launch requires a device name before the catalogue', (
    tester,
  ) async {
    final controller = CatalogueController(
      importService: RadioBeaconImportService(
        parser: RadioBeaconFileParser(),
        repository: InMemoryRadioBeaconRepository(),
      ),
      filePicker: const _CancelledPicker(),
      elevationService: RadioBeaconElevationService(_UnusedElevation()),
      locationService: _UnusedLocation(),
      exportService: _UnusedExport(),
      identityService: _FakeIdentity(),
    );
    await controller.initialize();
    final authController = await _signedInAuthController();
    await tester.pumpWidget(
      GpsPointerApp(
        authController: authController,
        visualThemeController: _visualThemeController(),
        controller: controller,
        locationService: _UnusedLocation(),
        profileElevationProvider: _UnusedProfileElevation(),
        simulationRepository: _MemorySimulationRepository(),
        simulationExportService: _UnusedSimulationExport(),
        pointingController: PointingController(
          locationService: _UnusedLocation(),
          elevationProvider: _UnusedElevation(),
          orientationService: _UnusedOrientation(),
        ),
      ),
    );

    expect(find.text('Configura questo dispositivo'), findsOneWidget);
    expect(find.text('Imposta nome dispositivo'), findsOneWidget);
  });

  testWidgets(
    'first setup stays mounted while the Android file picker is open',
    (tester) async {
      final picker = _BlockingPicker();
      final controller = CatalogueController(
        importService: RadioBeaconImportService(
          parser: RadioBeaconFileParser(),
          repository: InMemoryRadioBeaconRepository(),
        ),
        filePicker: picker,
        elevationService: RadioBeaconElevationService(_UnusedElevation()),
        locationService: _UnusedLocation(),
        exportService: _UnusedExport(),
        identityService: _FakeIdentity(displayName: 'Samsung Test'),
      );
      await controller.initialize();
      final authController = await _signedInAuthController();

      await tester.pumpWidget(
        MaterialApp(
          home: CatalogueScreen(
            authController: authController,
            visualThemeController: _visualThemeController(),
            controller: controller,
            locationService: _UnusedLocation(),
            profileElevationProvider: _UnusedProfileElevation(),
            simulationRepository: _MemorySimulationRepository(),
            simulationExportService: _UnusedSimulationExport(),
            pointingController: PointingController(
              locationService: _UnusedLocation(),
              elevationProvider: _UnusedElevation(),
              orientationService: _UnusedOrientation(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Importa l’archivio radiofari v3'), findsOneWidget);
      expect(find.text('Scegli file TXT v3'), findsOneWidget);

      await tester.tap(find.text('Scegli file TXT v3'));
      await tester.pump();

      expect(controller.busy, isTrue);
      expect(find.text('Importa l’archivio radiofari v3'), findsOneWidget);
      expect(find.text('Scegli file TXT v3'), findsOneWidget);

      picker.cancel();
      await tester.pumpAndSettle();

      expect(controller.busy, isFalse);
      expect(find.text('Importa l’archivio radiofari v3'), findsOneWidget);
    },
  );

  testWidgets('an existing catalogue acquires GPS automatically', (
    tester,
  ) async {
    final repository = InMemoryRadioBeaconRepository();
    await repository.replace(
      RadioBeaconCatalogue(
        beacons: const [
          RadioBeacon(
            id: 'TEST-001',
            name: 'CasaPacico',
            position: GeoPoint(latitude: 42.982646, longitude: 12.775651),
          ),
        ],
        sourceFileName: 'radiofari_gps_pointer.txt',
        importedAt: DateTime.utc(2026, 8, 14),
      ),
    );
    final location = _FixedLocation();
    final controller = CatalogueController(
      importService: RadioBeaconImportService(
        parser: RadioBeaconFileParser(),
        repository: repository,
      ),
      filePicker: const _CancelledPicker(),
      elevationService: RadioBeaconElevationService(_UnusedElevation()),
      locationService: location,
      exportService: _UnusedExport(),
      identityService: _FakeIdentity(displayName: 'Samsung Test'),
    );
    await controller.initialize();
    final authController = await _signedInAuthController();

    await tester.pumpWidget(
      MaterialApp(
        home: CatalogueScreen(
          authController: authController,
          visualThemeController: _visualThemeController(),
          controller: controller,
          locationService: location,
          profileElevationProvider: _UnusedProfileElevation(),
          simulationRepository: _MemorySimulationRepository(),
          simulationExportService: _UnusedSimulationExport(),
          pointingController: PointingController(
            locationService: location,
            elevationProvider: _UnusedElevation(),
            orientationService: _UnusedOrientation(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(location.calls, 1);
    expect(controller.catalogueFilterPosition, isNotNull);
    expect(find.textContaining('Distanza dalla posizione:'), findsOneWidget);
  });
}

AppVisualThemeController _visualThemeController() => AppVisualThemeController(
  storageFile: File(
    '${Directory.systemTemp.path}/gps_pointer_widget_visual_theme.txt',
  ),
  launcherIconBridge: _WidgetLauncherIconBridge(),
);

Future<AppAuthController> _signedInAuthController() async {
  final controller = AppAuthController(
    api: _WidgetAuthApi(),
    store: _WidgetAuthStore(),
    deviceUnlock: _WidgetUnlock(),
    deviceId: 'GPSP-TEST-DEVICE',
    deviceNameProvider: () => 'Samsung Test',
    appVersion: '1.0.0+22',
  );
  await controller.initialize();
  final ok = await controller.login(
    username: 'test',
    password: 'test-password',
    enableQuickUnlock: false,
  );
  if (!ok) {
    throw StateError('Impossibile preparare authController per widget test.');
  }
  return controller;
}

final class _WidgetLauncherIconBridge implements LauncherIconBridge {
  @override
  Future<void> apply(AppVisualTheme theme) async {}
}

final class _WidgetAuthApi implements AppAuthApi {
  @override
  Future<(AppAuthTokens, AppAuthUser)> login({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    required String appVersion,
  }) async => (
    const AppAuthTokens(
      accessToken: 'widget-access',
      refreshToken: 'widget-refresh',
    ),
    const AppAuthUser(
      username: 'test',
      displayName: 'Widget Test',
      role: 'admin',
      roleLabel: 'Amministratore',
    ),
  );

  @override
  Future<AppAuthTokens> refresh({
    required String refreshToken,
    required String deviceId,
    required String appVersion,
  }) async => const AppAuthTokens(
    accessToken: 'widget-access-2',
    refreshToken: 'widget-refresh-2',
  );

  @override
  Future<void> logout(String accessToken) async {}
}

final class _WidgetAuthStore implements AppAuthStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readDisplayName() async => null;

  @override
  Future<bool> readQuickUnlockEnabled() async => false;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<String?> readUsername() async => null;

  @override
  Future<void> save({
    required String refreshToken,
    required AppAuthUser user,
    required bool quickUnlockEnabled,
  }) async {}
}

final class _WidgetUnlock implements DeviceUnlockService {
  @override
  Future<bool> authenticate() async => true;

  @override
  Future<bool> isAvailable() async => false;
}

final class _FakeIdentity implements DeviceInstallationIdService {
  _FakeIdentity({String? displayName})
    : identity = DeviceIdentity(
        installationId: 'GPSP-11111111-1111-1111-1111-111111111111',
        displayName: displayName,
      );

  DeviceIdentity identity;

  @override
  Future<DeviceIdentity> loadOrCreate() async => identity;

  @override
  Future<DeviceIdentity> updateDisplayName(String displayName) async =>
      identity = DeviceIdentity(
        installationId: identity.installationId,
        displayName: displayName,
      );
}

final class _BlockingPicker implements RadioBeaconFilePicker {
  final Completer<SelectedRadioBeaconFile?> _completer =
      Completer<SelectedRadioBeaconFile?>();

  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete(null);
    }
  }

  @override
  Future<SelectedRadioBeaconFile?> selectFile() => _completer.future;
}

final class _CancelledPicker implements RadioBeaconFilePicker {
  const _CancelledPicker();
  @override
  Future<SelectedRadioBeaconFile?> selectFile() async => null;
}

final class _UnusedElevation implements TerrainElevationProvider {
  @override
  Future<double> getTerrainElevationMeters(GeoPoint position) async => 0;
}

final class _UnusedLocation implements DeviceLocationService {
  @override
  Future<DeviceLocationReading> readCurrentPosition() =>
      throw UnimplementedError();
}

final class _FixedLocation implements DeviceLocationService {
  int calls = 0;

  @override
  Future<DeviceLocationReading> readCurrentPosition() async {
    calls++;
    return const DeviceLocationReading(
      latitude: 43,
      longitude: 13,
      altitudeMeters: 400,
      horizontalAccuracyMeters: 3,
      verticalAccuracyMeters: 5,
    );
  }
}

final class _UnusedOrientation implements DeviceOrientationService {
  @override
  Future<DeviceOrientationInfo> readInfo(DeviceLocationReading location) =>
      throw UnimplementedError();
}

final class _UnusedExport implements CatalogueExportService {
  @override
  Future<void> export(String content) async {}
}

final class _UnusedProfileElevation implements TerrainProfileElevationProvider {
  @override
  Future<List<double>> getElevations(List<GeoPoint> coordinates) async =>
      List<double>.filled(coordinates.length, 0);
}

final class _MemorySimulationRepository
    implements RadioLinkSimulationRepository {
  final List<RadioLinkSimulation> items = [];

  @override
  Future<void> delete(String id) async =>
      items.removeWhere((item) => item.id == id);

  @override
  Future<List<RadioLinkSimulation>> loadAll() async => List.unmodifiable(items);

  @override
  Future<void> save(RadioLinkSimulation simulation) async =>
      items.add(simulation);
}

final class _UnusedSimulationExport implements SimulationExportService {
  @override
  Future<void> export({
    required RadioLinkSimulation simulation,
    required String deviceId,
    required String deviceName,
  }) async {}
}
