import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/app_auth.dart';
import '../application/app_visual_theme.dart';
import '../application/app_update_service.dart';
import '../application/app_file_association_settings.dart';
import '../application/catalogue_controller.dart';
import '../application/pointing_controller.dart';
import '../application/device_location_service.dart';
import '../application/diagnostic_log_store.dart';
import '../application/simulation_export_service.dart';
import '../application/simulation_import_service.dart';
import '../application/simulation_pdf_service.dart';
import '../application/intervention_report_pdf_service.dart';
import '../application/location_share_service.dart';
import '../application/server_upload_services.dart';
import '../application/weather_service.dart';
import '../core/core.dart';
import '../core/intervention_report.dart';
import '../core/geo/pointing_engine_v3_field.dart';
import 'app_auth_gate.dart';
import 'app_update_flow.dart';
import 'antenna_tilt_screen.dart';
import 'compass_screen.dart';
import 'guidance_overlay.dart';
import 'main_hub_screen.dart';
import 'debug_tools_screen.dart';
import 'coverage_screen.dart';
import 'ptp_screen.dart';
import 'altimetry_screen.dart';
import 'simulations_screen.dart';
import 'intervention_reports_screen.dart';
import 'server_catalogue_screen.dart';
import 'weather_radar_screen.dart';
import 'comida_screen.dart';
import 'tlc_updates_screen.dart';

final GlobalKey<NavigatorState> gpsPointerNavigatorKey =
    GlobalKey<NavigatorState>();

final class GpsPointerApp extends StatelessWidget {
  const GpsPointerApp({
    required this.authController,
    required this.visualThemeController,
    required this.controller,
    required this.pointingController,
    required this.locationService,
    this.weatherService,
    required this.profileElevationProvider,
    required this.simulationRepository,
    required this.simulationExportService,
    this.interventionReportRepository,
    this.interventionReportPdfService,
    this.serverUploadService,
    super.key,
  });

  final AppAuthController authController;
  final AppVisualThemeController visualThemeController;
  final CatalogueController controller;
  final PointingController pointingController;
  final DeviceLocationService locationService;
  final WeatherService? weatherService;
  final TerrainProfileElevationProvider profileElevationProvider;
  final RadioLinkSimulationRepository simulationRepository;
  final SimulationExportService simulationExportService;
  final InterventionReportRepository? interventionReportRepository;
  final InterventionReportPdfService? interventionReportPdfService;
  final GpsPointerServerUploadService? serverUploadService;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: visualThemeController,
    builder: (context, _) => MaterialApp(
      navigatorKey: gpsPointerNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'GPS Pointer',
      themeMode: ThemeMode.dark,
      darkTheme: gpsPointerTheme(visualThemeController.theme),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final catalogueScreen = CatalogueScreen(
            authController: authController,
            visualThemeController: visualThemeController,
            controller: controller,
            pointingController: pointingController,
            locationService: locationService,
            weatherService: weatherService,
            profileElevationProvider: profileElevationProvider,
            simulationRepository: simulationRepository,
            simulationExportService: simulationExportService,
          );
          if (controller.deviceDisplayName == null ||
              controller.catalogue == null) {
            return catalogueScreen;
          }
          return AppAuthGate(
            controller: authController,
            child: Builder(
              builder: (navContext) => MainHubScreen(
                visualThemeController: visualThemeController,
                locationService: locationService,
                weatherService: weatherService,
                onPostazioni: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(builder: (_) => catalogueScreen),
                ),
                onCopertura: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => SimulationLibraryScreen(
                      kind: RadioLinkSimulationKind.coverage,
                      repository: simulationRepository,
                      exportService: simulationExportService,
                      pdfService: const SimulationPdfService(),
                      importService: const SimulationImportService(),
                      deviceId: controller.installationId,
                      deviceName: controller.deviceDisplayName!,
                      serverUploadService: serverUploadService!,
                      onCreate: () => Navigator.of(navContext).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => CoverageScreen(
                            catalogueController: controller,
                            locationService: locationService,
                            profileElevationProvider: profileElevationProvider,
                            simulationRepository: simulationRepository,
                            exportService: simulationExportService,
                            deviceId: controller.installationId,
                            deviceName: controller.deviceDisplayName!,
                            serverUploadService: serverUploadService!,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                onRapporti: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => InterventionReportsScreen(
                      repository: interventionReportRepository!,
                      pdfService: interventionReportPdfService!,
                      uploadService: serverUploadService!,
                      defaultTechnicianName:
                          authController.user?.displayName ??
                          authController.savedDisplayName ??
                          authController.user?.username ??
                          authController.savedUsername ??
                          '',
                    ),
                  ),
                ),
                onWeatherRadar: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        WeatherRadarScreen(locationService: locationService),
                  ),
                ),
                onComida: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ComidaScreen(
                      locationService: locationService,
                      serverBaseUri: Uri.parse(
                        'https://gpspointer.ernet.it:9443',
                      ),
                      authController: authController,
                      submittedBy:
                          authController.user?.displayName ??
                          authController.savedDisplayName ??
                          authController.user?.username ??
                          authController.savedUsername,
                    ),
                  ),
                ),
                onPtp: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => SimulationLibraryScreen(
                      kind: RadioLinkSimulationKind.ptp,
                      repository: simulationRepository,
                      exportService: simulationExportService,
                      pdfService: const SimulationPdfService(),
                      importService: const SimulationImportService(),
                      deviceId: controller.installationId,
                      deviceName: controller.deviceDisplayName!,
                      serverUploadService: serverUploadService!,
                      onCreate: () => Navigator.of(navContext).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => PtpScreen(
                            locationService: locationService,
                            profileElevationProvider: profileElevationProvider,
                            simulationRepository: simulationRepository,
                            exportService: simulationExportService,
                            deviceId: controller.installationId,
                            deviceName: controller.deviceDisplayName!,
                            serverUploadService: serverUploadService!,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                onDownload: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ServerCatalogueScreen(
                      authController: authController,
                      controller: controller,
                    ),
                  ),
                ),
                onUpdates: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TlcUpdatesScreen(
                      serverBaseUri: Uri.parse(
                        'https://gpspointer.ernet.it:9443',
                      ),
                      authController: authController,
                    ),
                  ),
                ),
                onSettings: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => _CatalogueSettingsScreen(
                      controller: controller,
                      authController: authController,
                      visualThemeController: visualThemeController,
                    ),
                  ),
                ),
                onDebug: () => Navigator.of(navContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => DebugToolsScreen(controller: controller),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

enum CatalogueEntryAction { none, downloadServer, addBeacon }

final class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({
    required this.authController,
    required this.visualThemeController,
    required this.controller,
    required this.pointingController,
    required this.locationService,
    this.weatherService,
    required this.profileElevationProvider,
    required this.simulationRepository,
    required this.simulationExportService,
    this.initialAction = CatalogueEntryAction.none,
    super.key,
  });

  final AppAuthController authController;
  final AppVisualThemeController visualThemeController;
  final CatalogueController controller;
  final PointingController pointingController;
  final DeviceLocationService locationService;
  final WeatherService? weatherService;
  final TerrainProfileElevationProvider profileElevationProvider;
  final RadioLinkSimulationRepository simulationRepository;
  final SimulationExportService simulationExportService;
  final CatalogueEntryAction initialAction;

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

final class _CatalogueScreenState extends State<CatalogueScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _nearbyOnly = false;
  double _radiusKm = 25;
  bool _initialLocationRequested = false;

  AppAuthController get authController => widget.authController;
  AppVisualThemeController get visualThemeController =>
      widget.visualThemeController;
  CatalogueController get controller => widget.controller;
  PointingController get pointingController => widget.pointingController;
  DeviceLocationService get locationService => widget.locationService;
  WeatherService? get weatherService => widget.weatherService;
  TerrainProfileElevationProvider get profileElevationProvider =>
      widget.profileElevationProvider;
  RadioLinkSimulationRepository get simulationRepository =>
      widget.simulationRepository;
  SimulationExportService get simulationExportService =>
      widget.simulationExportService;

  @override
  void initState() {
    super.initState();
    if (widget.initialAction != CatalogueEntryAction.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.initialAction) {
          case CatalogueEntryAction.none:
            break;
          case CatalogueEntryAction.downloadServer:
            unawaited(_downloadCatalogueFromServer(context));
            break;
          case CatalogueEntryAction.addBeacon:
            unawaited(_openAddBeaconDialog(context));
            break;
        }
      });
    }
  }

  static final Uri _serverCatalogueUri = Uri.parse(
    'https://gpspointer.ernet.it:9443/api/v1/catalog/export',
  );

  Future<String> _fetchServerCatalogue(String token) async {
    final response = await http
        .get(_serverCatalogueUri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      throw const _ServerCatalogueException(
        'unauthorized',
        'Sessione scaduta.',
      );
    }
    if (response.statusCode != 200) {
      throw _ServerCatalogueException(
        'server_error',
        'Download catalogo non riuscito (HTTP ${response.statusCode}).',
      );
    }
    return response.body;
  }

  Future<bool?> _askResetBeforeServerDownload(BuildContext context) {
    final count = controller.catalogue?.beacons.length ?? 0;
    return showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Prima del download'),
        content: Text(
          'La lista locale contiene $count radiofari.\n\n'
          'Vuoi azzerarla prima di scaricare il catalogo dal server?\n\n'
          'Se scegli “Azzera prima”, la lista viene cancellata subito: '
          'se il download non riesce resterà vuota.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Non azzerare'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Azzera prima'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCatalogueFromServer(BuildContext context) async {
    final resetBefore = await _askResetBeforeServerDownload(context);
    if (resetBefore == null || !context.mounted) return;
    if (resetBefore) {
      await controller.clearCatalogue();
      if (!context.mounted) return;
    }

    try {
      var token = authController.accessToken;
      if (token == null) {
        throw const _ServerCatalogueException(
          'unauthorized',
          'Sessione non disponibile. Accedi nuovamente.',
        );
      }
      String content;
      try {
        content = await _fetchServerCatalogue(token);
      } on _ServerCatalogueException catch (error) {
        if (error.code != 'unauthorized') rethrow;
        if (!await authController.refreshAccessToken()) {
          throw const _ServerCatalogueException(
            'unauthorized',
            'Sessione scaduta. Accedi nuovamente.',
          );
        }
        token = authController.accessToken;
        if (token == null) {
          throw const _ServerCatalogueException(
            'unauthorized',
            'Sessione non disponibile. Accedi nuovamente.',
          );
        }
        content = await _fetchServerCatalogue(token);
      }

      await controller.importCatalogueFromServer(
        content: content,
        approve: (preview) async {
          if (!context.mounted) return false;
          return await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Aggiorna catalogo dal server'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${preview.beaconCount ?? 0} radiofari validati sul server.',
                      ),
                      if (preview.sourceDeviceName != null)
                        Text('Origine: ${preview.sourceDeviceName}'),
                      if (preview.exportedAtUtc != null)
                        Text(
                          'Esportato UTC: ${preview.exportedAtUtc!.toIso8601String()}',
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Il catalogo locale verrà sostituito soltanto dopo la '
                        'validazione completa del TXT v3.',
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Annulla'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Scarica e sostituisci'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
      );
    } on _ServerCatalogueException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catalogo server non scaricato: $error')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final catalogueReady =
          controller.catalogue != null && controller.deviceDisplayName != null;
      return Scaffold(
        appBar: catalogueReady ? null : _buildTopBar(context),
        body: GpsThemeBackground(
          child: catalogueReady
              ? SafeArea(bottom: false, child: _body(context))
              : SafeArea(child: _body(context)),
        ),
      );
    },
  );

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    if (!visualThemeController.isRadarPro) {
      return _buildClassicTopBar(context);
    }
    return _buildRadarProTopBar(context);
  }

  PreferredSizeWidget _buildClassicTopBar(BuildContext context) =>
      PreferredSize(
        preferredSize: const Size.fromHeight(112),
        child: Material(
          color: const Color(0xFF07131C),
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'asset/fry_app.png',
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GPS Pointer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'App puntamento GPS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF9FB6C2),
                                fontSize: 12,
                                letterSpacing: .2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.catalogue != null &&
                  controller.deviceDisplayName != null)
                _classicActionStrip(context),
            ],
          ),
        ),
      );

  Widget _classicActionStrip(BuildContext context) => Container(
    height: 48,
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: Color(0xFF16323F)),
        bottom: BorderSide(color: Color(0xFF16323F)),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: 'Aggiungi radiofaro',
          onPressed: controller.busy
              ? null
              : () => _openAddBeaconDialog(context),
          icon: const Icon(Icons.add_location_alt),
        ),
        IconButton(
          tooltip: 'Esporta TXT',
          onPressed: controller.busy ? null : controller.exportCatalogue,
          icon: const Icon(Icons.ios_share),
        ),
        IconButton(
          tooltip: 'Scarica catalogo dal server',
          onPressed: controller.busy || authController.busy
              ? null
              : () => _openServerCatalogue(context),
          icon: const Icon(Icons.cloud_download_outlined),
        ),
        IconButton(
          tooltip: 'Simulazioni',
          onPressed: () => _openSimulations(context),
          icon: const Icon(Icons.analytics_outlined),
        ),
        IconButton(
          tooltip: 'Impostazioni',
          onPressed: () => _openSettings(context),
          icon: const Icon(Icons.settings),
        ),
      ],
    ),
  );

  PreferredSizeWidget _buildRadarProTopBar(BuildContext context) =>
      PreferredSize(
        preferredSize: const Size.fromHeight(186),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF082C42), Color(0xFF061722), Color(0xFF041018)],
            ),
            border: Border(bottom: BorderSide(color: Color(0xFF2B6C88))),
          ),
          child: Column(
            children: [
              const SizedBox(
                height: 76,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      _RadarHeaderMark(),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RadarHeaderBrand(),
                            SizedBox(height: 4),
                            Text(
                              'PUNTA · MISURA · CONNETTI',
                              style: TextStyle(
                                color: Color(0xFF78DCEE),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.sensors, color: Color(0xFFFFA026), size: 26),
                    ],
                  ),
                ),
              ),
              if (controller.catalogue != null &&
                  controller.deviceDisplayName != null)
                SizedBox(
                  height: 108,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _RadarActionTile(
                            icon: Icons.add_location_alt_outlined,
                            label: 'Aggiungi',
                            onTap: controller.busy
                                ? null
                                : () => _openAddBeaconDialog(context),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _RadarActionTile(
                            icon: Icons.ios_share_outlined,
                            label: 'Esporta',
                            onTap: controller.busy
                                ? null
                                : controller.exportCatalogue,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _RadarActionTile(
                            icon: Icons.cloud_download_outlined,
                            label: 'Server',
                            onTap: controller.busy || authController.busy
                                ? null
                                : () => _openServerCatalogue(context),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _RadarActionTile(
                            icon: Icons.analytics_outlined,
                            label: 'Simulazioni',
                            onTap: () => _openSimulations(context),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _RadarActionTile(
                            icon: Icons.tune,
                            label: 'Impostazioni',
                            onTap: () => _openSettings(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  void _openSimulations(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SimulationsScreen(
          repository: simulationRepository,
          exportService: simulationExportService,
          deviceId: controller.installationId,
          deviceName: controller.deviceDisplayName!,
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final catalogue = controller.catalogue;
    if (controller.busy &&
        controller.deviceDisplayName == null &&
        catalogue == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.deviceDisplayName == null) {
      return _DeviceSetup(controller: controller);
    }
    if (catalogue == null) {
      return _FirstSetup(controller: controller);
    }
    _requestInitialLocationOnce();
    return CustomScrollView(
      key: const PageStorageKey<String>('catalogue-scroll'),
      slivers: [
        SliverToBoxAdapter(child: _Messages(controller: controller)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: visualThemeController.isRadarPro
                  ? Row(
                      children: [
                        const Icon(
                          Icons.cell_tower,
                          color: Color(0xFF79E2F3),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'POSTAZIONI RADIO',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .7,
                              ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B2A3A),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFF2D6F8B)),
                          ),
                          child: Text(
                            '${catalogue.beacons.length}',
                            style: const TextStyle(
                              color: Color(0xFFFFA026),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text('${catalogue.beacons.length} radiofari'),
            ),
          ),
        ),
        if (controller.busy)
          const SliverToBoxAdapter(child: LinearProgressIndicator()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Cerca per nome, ID o coordinate',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Cancella ricerca',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    selected: !_nearbyOnly,
                    label: const Text('Tutti'),
                    avatar: const Icon(Icons.public, size: 18),
                    onSelected: controller.busy
                        ? null
                        : (selected) {
                            if (selected) setState(() => _nearbyOnly = false);
                          },
                  ),
                  FilterChip(
                    selected: _nearbyOnly,
                    label: Text('Entro ${_formatRadius(_radiusKm)} km'),
                    avatar: const Icon(Icons.near_me, size: 18),
                    onSelected: controller.busy
                        ? null
                        : (selected) async {
                            if (selected) {
                              await _enableNearbyFilter();
                            } else if (mounted) {
                              setState(() => _nearbyOnly = false);
                            }
                          },
                  ),
                  IconButton.outlined(
                    tooltip: 'Imposta raggio',
                    onPressed: controller.busy ? null : _chooseRadius,
                    icon: const Icon(Icons.tune),
                  ),
                  if (_nearbyOnly)
                    IconButton.outlined(
                      tooltip: 'Aggiorna posizione filtro',
                      onPressed: controller.busy
                          ? null
                          : () => _enableNearbyFilter(forceRefresh: true),
                      icon: const Icon(Icons.my_location),
                    ),
                  if (controller.catalogueFilterLocation != null)
                    Chip(
                      avatar: const Icon(Icons.gps_fixed, size: 18),
                      label: Text(
                        'GPS ±${controller.catalogueFilterLocation!.horizontalAccuracyMeters.toStringAsFixed(0)} m',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        _beaconListSliver(catalogue),
      ],
    );
  }

  void _requestInitialLocationOnce() {
    if (_initialLocationRequested ||
        controller.catalogueFilterPosition != null) {
      return;
    }
    _initialLocationRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(controller.refreshCatalogueFilterPosition());
    });
  }

  Widget _beaconListSliver(RadioBeaconCatalogue catalogue) {
    final origin = controller.catalogueFilterPosition;
    final filtered = RadioBeaconCatalogueSearch.search(
      beacons: catalogue.beacons,
      query: _query,
      origin: origin,
      maximumDistanceMeters: _nearbyOnly && origin != null
          ? _radiusKm * 1000
          : null,
    );
    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _nearbyOnly
                  ? 'Nessun radiofaro entro ${_formatRadius(_radiusKm)} km.'
                  : 'Nessun radiofaro trovato.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == filtered.length - 1 ? 0 : 12,
            ),
            child: _BeaconCard(
              beacon: filtered[index].beacon,
              origin: origin,
              distanceFromFilterMeters: filtered[index].distanceMeters,
              weatherService: weatherService,
              controller: controller,
              pointingController: pointingController,
              locationService: locationService,
              profileElevationProvider: profileElevationProvider,
              simulationRepository: simulationRepository,
              simulationExportService: simulationExportService,
              deviceId: controller.installationId,
              deviceName: controller.deviceDisplayName!,
            ),
          ),
          childCount: filtered.length,
        ),
      ),
    );
  }

  Future<void> _enableNearbyFilter({bool forceRefresh = false}) async {
    if (forceRefresh || controller.catalogueFilterPosition == null) {
      final acquired = await controller.refreshCatalogueFilterPosition();
      if (!mounted || !acquired) return;
    }
    setState(() => _nearbyOnly = true);
  }

  Future<void> _chooseRadius() async {
    final selected = await showDialog<double>(
      context: context,
      builder: (_) => _RadiusDialog(initialRadiusKm: _radiusKm),
    );
    if (selected == null || !mounted) return;
    setState(() => _radiusKm = selected);
    await _enableNearbyFilter();
  }

  static String _formatRadius(double radiusKm) => radiusKm == radiusKm.round()
      ? radiusKm.round().toString()
      : radiusKm.toStringAsFixed(1);

  Future<void> _openAddBeaconDialog(BuildContext context) async {
    final draft = await showDialog<_ManualBeaconDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddBeaconDialog(controller: controller),
    );
    if (draft == null) return;
    await controller.addManualBeacon(
      name: draft.name,
      latitude: draft.latitude,
      longitude: draft.longitude,
      terrainElevationMeters: draft.terrainElevationMeters,
      poleHeightMeters: draft.poleHeightMeters,
    );
  }

  Future<void> _openServerCatalogue(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ServerCatalogueScreen(
            authController: authController,
            controller: controller,
          ),
        ),
      );

  Future<void> _openSettings(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _CatalogueSettingsScreen(
            controller: controller,
            authController: authController,
            visualThemeController: visualThemeController,
          ),
        ),
      );
}

final class _RadarHeaderMark extends StatelessWidget {
  const _RadarHeaderMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF071B28),
      border: Border.all(color: const Color(0xFF43CFE8), width: 1.5),
      boxShadow: const [
        BoxShadow(color: Color(0x4422C8E7), blurRadius: 14, spreadRadius: 1),
      ],
    ),
    child: const Icon(Icons.explore, color: Color(0xFFFFA026), size: 34),
  );
}

final class _RadarHeaderBrand extends StatelessWidget {
  const _RadarHeaderBrand();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      const Text(
        'GPS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 25,
          height: 1,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: .8,
        ),
      ),
      const SizedBox(width: 7),
      const Text(
        'Pointer',
        style: TextStyle(
          color: Color(0xFF54D8EF),
          fontSize: 20,
          height: 1,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );
}

final class _RadarActionTile extends StatelessWidget {
  const _RadarActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123A50), Color(0xFF0A2230)],
          ),
          border: Border.all(color: const Color(0xFF326B84)),
          boxShadow: const [
            BoxShadow(color: Color(0x2200D5F2), blurRadius: 10),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: onTap == null
                    ? const Color(0xFF50707D)
                    : const Color(0xFF8BEAF7),
                size: 23,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: onTap == null
                        ? const Color(0xFF607984)
                        : Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _CatalogueSettingsScreen extends StatelessWidget {
  const _CatalogueSettingsScreen({
    required this.controller,
    required this.authController,
    required this.visualThemeController,
  });

  final CatalogueController controller;
  final AppAuthController authController;
  final AppVisualThemeController visualThemeController;

  static final Uri _serverCatalogueUri = Uri.parse(
    'https://gpspointer.ernet.it:9443/api/v1/catalog/export',
  );

  Future<String> _fetchServerCatalogue(String token) async {
    final response = await http
        .get(_serverCatalogueUri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      throw const _ServerCatalogueException(
        'unauthorized',
        'Sessione scaduta.',
      );
    }
    if (response.statusCode != 200) {
      throw _ServerCatalogueException(
        'server_error',
        'Download catalogo non riuscito (HTTP ${response.statusCode}).',
      );
    }
    return response.body;
  }

  Future<bool?> _askResetBeforeServerDownload(BuildContext context) {
    final count = controller.catalogue?.beacons.length ?? 0;
    return showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Prima del download'),
        content: Text(
          'La lista locale contiene $count radiofari.\n\n'
          'Vuoi azzerarla prima di scaricare il catalogo dal server?\n\n'
          'Se scegli “Azzera prima”, la lista viene cancellata subito: '
          'se il download non riesce resterà vuota.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Non azzerare'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Azzera prima'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndClearCatalogue(BuildContext context) async {
    final count = controller.catalogue?.beacons.length ?? 0;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La lista radiofari è già vuota.')),
      );
      return;
    }
    final approved =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Azzera lista radiofari'),
            content: Text(
              'Stai per eliminare dal telefono tutti i $count radiofari locali.\n\n'
              'Account, impostazioni, simulazioni e accesso al server non '
              'verranno modificati.\n\n'
              'Potrai poi riscaricare il catalogo dal server o importare un TXT.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Azzera lista'),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved) return;
    await controller.clearCatalogue();
  }

  Future<void> _downloadCatalogueFromServer(BuildContext context) async {
    final resetBefore = await _askResetBeforeServerDownload(context);
    if (resetBefore == null || !context.mounted) return;
    if (resetBefore) {
      await controller.clearCatalogue();
      if (!context.mounted) return;
    }

    try {
      var token = authController.accessToken;
      if (token == null) {
        throw const _ServerCatalogueException(
          'unauthorized',
          'Sessione non disponibile. Accedi nuovamente.',
        );
      }

      String content;
      try {
        content = await _fetchServerCatalogue(token);
      } on _ServerCatalogueException catch (error) {
        if (error.code != 'unauthorized') rethrow;
        if (!await authController.refreshAccessToken()) {
          throw const _ServerCatalogueException(
            'unauthorized',
            'Sessione scaduta. Accedi nuovamente.',
          );
        }
        token = authController.accessToken;
        if (token == null) {
          throw const _ServerCatalogueException(
            'unauthorized',
            'Sessione non disponibile. Accedi nuovamente.',
          );
        }
        content = await _fetchServerCatalogue(token);
      }

      await controller.importCatalogueFromServer(
        content: content,
        approve: (preview) async {
          if (!context.mounted) return false;
          return await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Aggiorna catalogo dal server'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${preview.beaconCount ?? 0} radiofari validati sul server.',
                      ),
                      if (preview.sourceDeviceName != null)
                        Text('Origine: ${preview.sourceDeviceName}'),
                      if (preview.exportedAtUtc != null)
                        Text(
                          'Esportato UTC: ${preview.exportedAtUtc!.toIso8601String()}',
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Il catalogo locale verrà sostituito soltanto dopo la '
                        'validazione completa del TXT v3.',
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Annulla'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Scarica e sostituisci'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
      );
    } on _ServerCatalogueException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catalogo server non scaricato: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final catalogue = controller.catalogue;
      final displayName =
          authController.user?.displayName ??
          authController.savedDisplayName ??
          'Utente GPS Pointer';
      final username =
          authController.user?.username ?? authController.savedUsername;

      return Scaffold(
        appBar: AppBar(title: const Text('Impostazioni')),
        body: GpsThemeBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _Messages(controller: controller),
                if (controller.busy) const LinearProgressIndicator(),
                const SizedBox(height: 8),

                _SettingsSection(
                  icon: Icons.person_outline,
                  title: 'Account',
                  children: [
                    _SettingsInfoRow(
                      icon: Icons.badge_outlined,
                      title: displayName,
                      subtitle: username,
                    ),
                    _SettingsActionRow(
                      icon: Icons.logout,
                      title: 'Esci dall’account',
                      enabled: !authController.busy,
                      onTap: () async {
                        await authController.logout();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                const _SettingsSectionHeader(
                  icon: Icons.palette_outlined,
                  title: 'Aspetto',
                ),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: visualThemeController,
                  builder: (context, _) => VisualThemeSelectorCard(
                    controller: visualThemeController,
                  ),
                ),

                const SizedBox(height: 22),
                _SettingsSection(
                  icon: Icons.system_update_alt,
                  title: 'Aggiornamenti',
                  children: [
                    const _SettingsInfoRow(
                      icon: Icons.cloud_outlined,
                      title: 'Aggiornamenti applicazione',
                      subtitle:
                          'Controlla la release pubblicata e avvia l’aggiornamento in-app.',
                    ),
                    _SettingsActionRow(
                      icon: Icons.system_update_alt,
                      title: 'Controlla aggiornamenti',
                      onTap: () async {
                        final client = http.Client();
                        try {
                          await showAppUpdateCheck(
                            context,
                            AppUpdateService(client: client),
                            manual: true,
                          );
                        } finally {
                          client.close();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                _SettingsSection(
                  icon: Icons.bug_report_outlined,
                  title: 'Diagnostica',
                  children: [
                    _SettingsActionRow(
                      icon: Icons.monitor_heart_outlined,
                      title: 'Debug e diagnostica',
                      subtitle: 'Log, sensori e strumenti tecnici',
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DebugToolsScreen(controller: controller),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                _SettingsSection(
                  icon: Icons.insert_drive_file_outlined,
                  title: 'File simulazione',
                  children: [
                    const _SettingsInfoRow(
                      icon: Icons.link_outlined,
                      title: 'Associazione .gpspsim',
                      subtitle:
                          'GPS Pointer supporta i file .gpspsim. Android può chiedere quale app usare la prima volta.',
                    ),
                    _SettingsActionRow(
                      icon: Icons.open_in_new,
                      title: 'Impostazioni Android dell’app',
                      onTap: () async {
                        final opened =
                            await AppFileAssociationSettings.openAndroidAppSettings();
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Impostazioni Android non disponibili.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const _SettingsNote(
                      'Per il test: apri un .gpspsim da Download e scegli '
                      'GPS Pointer. Se Android propone “Sempre”, puoi '
                      'impostarlo come predefinito.',
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                _SettingsSection(
                  icon: Icons.cell_tower_outlined,
                  title: 'Archivio radiofari',
                  children: [
                    _SettingsInfoRow(
                      icon: Icons.inventory_2_outlined,
                      title: catalogue == null
                          ? 'Nessun archivio caricato'
                          : '${catalogue.beacons.length} radiofari caricati',
                      subtitle: catalogue == null
                          ? null
                          : 'File: ${catalogue.sourceFileName}',
                    ),
                    _SettingsInfoRow(
                      icon: Icons.smartphone_outlined,
                      title:
                          'Dispositivo: ${controller.deviceDisplayName ?? 'non configurato'}',
                      subtitle: 'ID tecnico: ${controller.installationId}',
                    ),
                    _SettingsActionRow(
                      icon: Icons.edit_outlined,
                      title: 'Modifica nome dispositivo',
                      enabled: !controller.busy,
                      onTap: () => _editDeviceName(context, controller),
                    ),
                    const _SettingsNote(
                      'Il nuovo TXT viene validato completamente prima del '
                      'salvataggio. Se contiene errori, l’archivio corrente '
                      'non viene modificato.',
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: controller.busy || authController.busy
                            ? null
                            : () => _downloadCatalogueFromServer(context),
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('Scarica catalogo dal server'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingsActionRow(
                      icon: Icons.sync,
                      title: 'Sostituisci file TXT manualmente',
                      enabled: !controller.busy,
                      onTap: () => _importCatalogue(context, controller),
                    ),
                    _SettingsActionRow(
                      icon: Icons.delete_sweep_outlined,
                      title: 'Azzera lista radiofari',
                      enabled: !controller.busy,
                      destructive: true,
                      onTap: () => _confirmAndClearCatalogue(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

final class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 19, color: scheme.primary),
        const SizedBox(width: 9),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ],
    );
  }
}

final class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor.withValues(alpha: .35);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSectionHeader(icon: icon, title: title),
        const SizedBox(height: 8),
        DecoratedBox(
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
        ),
      ],
    );
  }
}

final class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    leading: Icon(icon, size: 22),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: subtitle == null ? null : Text(subtitle!),
  );
}

final class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : null;
    return ListTile(
      dense: true,
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      leading: Icon(icon, size: 22, color: color),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right, size: 21),
      onTap: enabled ? onTap : null,
    );
  }
}

final class _SettingsNote extends StatelessWidget {
  const _SettingsNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(54, 9, 12, 9),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    ),
  );
}

Future<void> _importCatalogue(
  BuildContext context,
  CatalogueController controller,
) async {
  await controller.importCatalogue(
    approve: (preview) async {
      if (!context.mounted) return false;
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              scrollable: true,
              title: const Text('Conferma sostituzione archivio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.fileNameDiffers)
                    Text(
                      'Nome file: ${preview.fileName}\n'
                      'Standard atteso: '
                      '${CatalogueController.standardCatalogueFileName}',
                    ),
                  if (preview.fileNameDiffers && preview.deviceDiffers)
                    const SizedBox(height: 12),
                  if (preview.deviceDiffers) ...[
                    Text(
                      'Dispositivo di origine: '
                      '${preview.sourceDeviceName ?? 'nome non presente'}',
                    ),
                    Text('ID origine: ${preview.sourceDeviceId}'),
                    if (preview.exportedAtUtc != null)
                      Text(
                        'Esportato UTC: '
                        '${preview.exportedAtUtc!.toIso8601String()}',
                      ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Saranno importati soltanto i radiofari. Al prossimo '
                    'export verranno usati nome e ID di questo dispositivo.',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Approva e sostituisci'),
                ),
              ],
            ),
          ) ??
          false;
    },
  );
}

Future<void> _editDeviceName(
  BuildContext context,
  CatalogueController controller,
) async {
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DeviceNameDialog(initialValue: controller.deviceDisplayName),
  );
  if (name != null) await controller.updateDeviceDisplayName(name);
}

final class _DeviceNameDialog extends StatefulWidget {
  const _DeviceNameDialog({this.initialValue});

  final String? initialValue;

  @override
  State<_DeviceNameDialog> createState() => _DeviceNameDialogState();
}

final class _DeviceNameDialogState extends State<_DeviceNameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 80) {
      setState(() => _error = 'Inserisci da 1 a 80 caratteri.');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nome dispositivo'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 80,
      decoration: InputDecoration(
        labelText: 'Nome o identificativo leggibile',
        helperText: 'Esempio: Samsung Michele',
        errorText: _error,
      ),
      onSubmitted: (_) => _confirm(),
    ),
    actions: [
      if (widget.initialValue != null)
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
      FilledButton(onPressed: _confirm, child: const Text('Salva')),
    ],
  );
}

final class _DeviceSetup extends StatelessWidget {
  const _DeviceSetup({required this.controller});

  final CatalogueController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Image.asset('asset/fry_pointer.png', height: 170),
          const SizedBox(height: 18),
          Text(
            'Configura questo dispositivo',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Inserisci un nome riconoscibile. Verrà scritto nei TXT esportati '
            'insieme all’ID tecnico univoco.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ID tecnico: ${controller.installationId}',
            textAlign: TextAlign.center,
          ),
          _Messages(controller: controller),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: controller.busy
                ? null
                : () => _editDeviceName(context, controller),
            icon: const Icon(Icons.badge),
            label: const Text('Imposta nome dispositivo'),
          ),
        ],
      ),
    ),
  );
}

final class _RadiusDialog extends StatefulWidget {
  const _RadiusDialog({required this.initialRadiusKm});

  final double initialRadiusKm;

  @override
  State<_RadiusDialog> createState() => _RadiusDialogState();
}

final class _RadiusDialogState extends State<_RadiusDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialRadiusKm.toStringAsFixed(
        widget.initialRadiusKm == widget.initialRadiusKm.round() ? 0 : 1,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _usePreset(double value) {
    _controller.text = value.toStringAsFixed(0);
    setState(() => _error = null);
  }

  void _confirm() {
    final value = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0 || value > 10000) {
      setState(() => _error = 'Inserisci un valore tra 0,1 e 10.000 km.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Raggio radiofari'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saranno mostrati soltanto i radiofari compresi nel raggio dalla '
          'posizione attuale, ordinati dal più vicino.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final value in const [5.0, 10.0, 25.0, 50.0, 100.0])
              ActionChip(
                label: Text('${value.round()} km'),
                onPressed: () => _usePreset(value),
              ),
          ],
        ),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Raggio personalizzato (km)',
            errorText: _error,
          ),
          onSubmitted: (_) => _confirm(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(onPressed: _confirm, child: const Text('Applica')),
    ],
  );
}

final class _ManualBeaconDraft {
  const _ManualBeaconDraft({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.terrainElevationMeters,
    required this.poleHeightMeters,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double? terrainElevationMeters;
  final double poleHeightMeters;
}

final class _AddBeaconDialog extends StatefulWidget {
  const _AddBeaconDialog({required this.controller});

  final CatalogueController controller;

  @override
  State<_AddBeaconDialog> createState() => _AddBeaconDialogState();
}

final class _AddBeaconDialogState extends State<_AddBeaconDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _terrain = TextEditingController();
  final _pole = TextEditingController(text: '0');
  bool _loadingPosition = false;
  String? _positionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadCurrentPosition());
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _terrain.dispose();
    _pole.dispose();
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _requiredText(String? value, {int? maximumLength}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Campo obbligatorio.';
    if (maximumLength != null && text.length > maximumLength) {
      return 'Massimo $maximumLength caratteri.';
    }
    return null;
  }

  String? _coordinate(String? value, double minimum, double maximum) {
    final parsed = _number(value ?? '');
    if (parsed == null || !parsed.isFinite) return 'Numero non valido.';
    if (parsed < minimum || parsed > maximum) {
      return 'Valore ammesso: $minimum – $maximum.';
    }
    return null;
  }

  String? _optionalNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = _number(text);
    return parsed == null || !parsed.isFinite ? 'Numero non valido.' : null;
  }

  String? _nonNegative(String? value) {
    final parsed = _number(value ?? '');
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return 'Inserisci zero o un valore positivo.';
    }
    return null;
  }

  Future<void> _loadCurrentPosition({bool forceRefresh = false}) async {
    setState(() {
      _loadingPosition = true;
      _positionStatus = 'Acquisizione della posizione corrente…';
    });
    var reading = widget.controller.catalogueFilterLocation;
    if (forceRefresh || reading == null) {
      final acquired = await widget.controller.refreshCatalogueFilterPosition();
      if (!mounted) return;
      if (!acquired) {
        setState(() {
          _loadingPosition = false;
          _positionStatus =
              widget.controller.errorMessage ?? 'Posizione non acquisita.';
        });
        return;
      }
      reading = widget.controller.catalogueFilterLocation;
    }
    if (reading == null || !mounted) return;
    _latitude.text = reading.latitude.toStringAsFixed(7);
    _longitude.text = reading.longitude.toStringAsFixed(7);
    setState(() {
      _loadingPosition = false;
      _positionStatus =
          'Posizione corrente acquisita • accuratezza '
          '±${reading!.horizontalAccuracyMeters.toStringAsFixed(0)} m';
    });
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = _ManualBeaconDraft(
      name: _name.text.trim(),
      latitude: _number(_latitude.text)!,
      longitude: _number(_longitude.text)!,
      terrainElevationMeters: _terrain.text.trim().isEmpty
          ? null
          : _number(_terrain.text),
      poleHeightMeters: _number(_pole.text)!,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuovo radiofaro'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Il salvataggio avviene solo dopo la validazione completa '
                'del catalogo. Il TXT sorgente non viene modificato.',
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (_loadingPosition)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.my_location),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _positionStatus ?? 'Posizione corrente non acquisita.',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Aggiorna posizione',
                      onPressed: _loadingPosition
                          ? null
                          : () => _loadCurrentPosition(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  helperText: 'L’ID univoco viene generato automaticamente.',
                ),
                validator: (value) => _requiredText(value, maximumLength: 120),
              ),
              TextFormField(
                controller: _latitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Latitudine'),
                validator: (value) => _coordinate(value, -90, 90),
              ),
              TextFormField(
                controller: _longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Longitudine'),
                validator: (value) => _coordinate(value, -180, 180),
              ),
              TextFormField(
                controller: _terrain,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Quota terreno (m) – facoltativa',
                  helperText: 'Se vuota potrai acquisirla con Open-Meteo.',
                ),
                validator: _optionalNumber,
              ),
              TextFormField(
                controller: _pole,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Altezza palo (m)',
                ),
                validator: _nonNegative,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton.icon(
        onPressed: _confirm,
        icon: const Icon(Icons.save),
        label: const Text('Valida e salva'),
      ),
    ],
  );
}

final class _FirstSetup extends StatelessWidget {
  const _FirstSetup({required this.controller});

  final CatalogueController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Image.asset('asset/fry_pointer.png', height: 190),
          const SizedBox(height: 18),
          Text(
            'Importa l’archivio radiofari v3',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Le quote mancanti saranno richieste a Open-Meteo.',
            textAlign: TextAlign.center,
          ),
          _Messages(controller: controller),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: controller.busy
                ? null
                : () => _importCatalogue(context, controller),
            icon: const Icon(Icons.file_open),
            label: const Text('Scegli file TXT v3'),
          ),
        ],
      ),
    ),
  );
}

final class _BeaconCard extends StatefulWidget {
  const _BeaconCard({
    required this.beacon,
    required this.origin,
    required this.distanceFromFilterMeters,
    required this.weatherService,
    required this.controller,
    required this.pointingController,
    required this.locationService,
    required this.profileElevationProvider,
    required this.simulationRepository,
    required this.simulationExportService,
    required this.deviceId,
    required this.deviceName,
  });

  final RadioBeacon beacon;
  final GeoPoint? origin;
  final double? distanceFromFilterMeters;
  final WeatherService? weatherService;
  final CatalogueController controller;
  final PointingController pointingController;
  final DeviceLocationService locationService;
  final TerrainProfileElevationProvider profileElevationProvider;
  final RadioLinkSimulationRepository simulationRepository;
  final SimulationExportService simulationExportService;
  final String deviceId;
  final String deviceName;

  @override
  State<_BeaconCard> createState() => _BeaconCardState();
}

final class _BeaconCardState extends State<_BeaconCard> {
  bool _expanded = false;
  WeatherSnapshot? _weather;
  bool _weatherLoading = false;

  @override
  void didUpdateWidget(covariant _BeaconCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beacon.id != widget.beacon.id ||
        oldWidget.weatherService != widget.weatherService) {
      _weather = null;
      _weatherLoading = false;
    }
  }

  Future<void> _loadWeather() async {
    if (_weatherLoading || widget.weatherService == null) return;
    setState(() => _weatherLoading = true);
    try {
      final weather = await widget.weatherService!.current(
        widget.beacon.position,
      );
      if (!mounted) return;
      setState(() => _weather = weather);
    } catch (_) {
      if (!mounted) return;
      setState(() => _weather = null);
    } finally {
      if (mounted) setState(() => _weatherLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              final opening = !_expanded;
              setState(() => _expanded = opening);
              if (opening &&
                  _weather == null &&
                  !_weatherLoading &&
                  widget.weatherService != null) {
                unawaited(_loadWeather());
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.beacon.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (widget.distanceFromFilterMeters != null)
                          Text(
                            _BeaconDetailsCard._formatDistance(
                              widget.distanceFromFilterMeters!,
                            ),
                            style: const TextStyle(
                              color: Color(0xFFB7CBD4),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF79E2F3),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            _BeaconDetailsCard(
              beacon: widget.beacon,
              distanceFromFilterMeters: widget.distanceFromFilterMeters,
              controller: widget.controller,
              pointingController: widget.pointingController,
              locationService: widget.locationService,
              profileElevationProvider: widget.profileElevationProvider,
              simulationRepository: widget.simulationRepository,
              simulationExportService: widget.simulationExportService,
              deviceId: widget.deviceId,
              deviceName: widget.deviceName,
              weather: _weather,
            ),
        ],
      ),
    );
  }
}

final class _BeaconDetailsCard extends StatelessWidget {
  const _BeaconDetailsCard({
    required this.beacon,
    required this.distanceFromFilterMeters,
    required this.controller,
    required this.pointingController,
    required this.locationService,
    required this.profileElevationProvider,
    required this.simulationRepository,
    required this.simulationExportService,
    required this.deviceId,
    required this.deviceName,
    this.weather,
  });

  final RadioBeacon beacon;
  final double? distanceFromFilterMeters;
  final CatalogueController controller;
  final PointingController pointingController;
  final DeviceLocationService locationService;
  final TerrainProfileElevationProvider profileElevationProvider;
  final RadioLinkSimulationRepository simulationRepository;
  final SimulationExportService simulationExportService;
  final String deviceId;
  final String deviceName;
  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    final terrain = beacon.terrainElevationMeters;
    final antenna = beacon.antennaElevationMeters;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(beacon.name, style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${beacon.id} • ${beacon.position.latitude}, ${beacon.position.longitude}',
            ),
            if (distanceFromFilterMeters != null)
              Text(
                'Distanza dalla posizione: '
                '${_formatDistance(distanceFromFilterMeters!)}',
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _shareBeaconLocation(context),
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('Condividi posizione'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _openDrivingDirections(context),
                    icon: const Icon(Icons.directions_car_outlined),
                    label: const Text('Indicazioni stradali'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Quota terreno: ${terrain == null ? 'mancante' : '${terrain.toStringAsFixed(1)} m'}',
            ),
            Text('Palo: ${beacon.poleHeightMeters.toStringAsFixed(1)} m'),
            Text(
              'Quota antenna: ${antenna == null ? 'non calcolabile' : '${antenna.toStringAsFixed(1)} m'}',
            ),
            if (beacon.elevationSource != null)
              Text(
                'Fonte quota: ${_friendlyElevationSource(beacon.elevationSource!)}',
              ),
            if (weather != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x55162D3A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x332BC5E8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meteo ora',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${weather!.temperatureCelsius.toStringAsFixed(1)} °C · '
                      '${weather!.description}',
                    ),
                    if (weather!.apparentTemperatureCelsius != null)
                      Text(
                        'Percepita ${weather!.apparentTemperatureCelsius!.toStringAsFixed(1)} °C · '
                        'Umidità ${weather!.relativeHumidityPercent.toStringAsFixed(0)}%',
                      )
                    else
                      Text(
                        'Umidità ${weather!.relativeHumidityPercent.toStringAsFixed(0)}%',
                      ),
                    Text(
                      'Vento ${weather!.windSpeedKmh.toStringAsFixed(0)} km/h · '
                      'raffiche ${weather!.windGustKmh.toStringAsFixed(0)} km/h',
                    ),
                    Text(
                      'Nuvolosità ${weather!.cloudCoverPercent.toStringAsFixed(0)}% · '
                      'precipitazioni ${weather!.precipitationMm.toStringAsFixed(1)} mm',
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Meteo: MET Norway',
                      style: TextStyle(color: Color(0xFF9FB6C2), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openWeatherRadar(context),
                icon: const Icon(Icons.radar_outlined),
                label: const Text('Radar meteo su questa postazione'),
              ),
            ),
            if (beacon.horizontalAccuracyMeters != null)
              Text(
                'Accuratezza GPS H: '
                '±${beacon.horizontalAccuracyMeters!.toStringAsFixed(1)} m',
              ),
            if (beacon.verticalAccuracyMeters != null)
              Text(
                'Accuratezza GPS V: '
                '±${beacon.verticalAccuracyMeters!.toStringAsFixed(1)} m',
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.busy || antenna == null
                        ? null
                        : () => _openPointing(context),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('AR'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: controller.busy || antenna == null
                        ? null
                        : () => _openMap(context),
                    icon: const Icon(Icons.map),
                    label: const Text('Mappa'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: controller.busy || antenna == null
                        ? null
                        : () => _openCompass(context),
                    icon: const Icon(Icons.explore),
                    label: const Text('Azimut'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: controller.busy || antenna == null
                        ? null
                        : () => _openTilt(context),
                    icon: const Icon(Icons.straighten),
                    label: const Text('Tilt antenna'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: controller.busy
                    ? null
                    : () => _openAltimetry(context),
                icon: const Icon(Icons.terrain),
                label: const Text('Altimetria'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => controller.loadOpenMeteo(beacon.id),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Open-Meteo'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => controller.measureOnSite(beacon.id),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Rileva qui'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => _manualDialog(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Manuale'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _friendlyElevationSource(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('open_meteo')) return 'Open-Meteo';
    if (normalized.contains('gps')) return 'GPS';
    if (normalized.contains('manual')) return 'Manuale';
    return 'Catalogo';
  }

  Future<void> _shareBeaconLocation(BuildContext context) async {
    try {
      await LocationShareService.share(
        label: 'Postazione Radio • ${beacon.name}',
        point: beacon.position,
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Condivisione posizione non riuscita: $error')),
      );
    }
  }

  Future<void> _openDrivingDirections(BuildContext context) async {
    try {
      final opened = await LocationShareService.openDrivingDirections(
        point: beacon.position,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nessuna app disponibile per aprire le indicazioni stradali.',
            ),
          ),
        );
      }
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Indicazioni stradali non disponibili: $error')),
      );
    }
  }

  Future<void> _openWeatherRadar(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WeatherRadarScreen(
            locationService: locationService,
            initialPoint: beacon.position,
            initialLabel: beacon.name,
          ),
        ),
      );

  Future<void> _openAltimetry(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AltimetryScreen(
          beacon: beacon,
          locationService: locationService,
          profileElevationProvider: profileElevationProvider,
          simulationRepository: simulationRepository,
          exportService: simulationExportService,
          deviceId: deviceId,
          deviceName: deviceName,
        ),
      ),
    );
  }

  Future<void> _openPointing(BuildContext context) async {
    final height = await _requestObserverHeight(context);
    if (height == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PointingScreen(
          beacon: beacon,
          controller: pointingController,
          observerHeightMeters: height,
        ),
      ),
    );
  }

  Future<void> _openMap(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BeaconMapScreen(
          beacon: beacon,
          controller: pointingController,
          observerHeightMeters: 0,
        ),
      ),
    );
  }

  Future<void> _openCompass(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CompassScreen(
          beacon: beacon,
          controller: pointingController,
          observerHeightMeters: 0,
        ),
      ),
    );
  }

  Future<void> _openTilt(BuildContext context) async {
    final height = await _requestObserverHeight(context);
    if (height == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AntennaTiltScreen(
          beacon: beacon,
          controller: pointingController,
          observerHeightMeters: height,
        ),
      ),
    );
  }

  Future<double?> _requestObserverHeight(BuildContext context) async {
    final heightController = TextEditingController(text: '0');
    var closingDialog = false;
    final dialogRoute = DialogRoute<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Punto di osservazione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quanto si trova il telefono sopra il suolo nel punto di '
              'osservazione?',
            ),
            const SizedBox(height: 8),
            const Text(
              'Esempi: 0 m a terra, circa 3 m al primo piano, 6 m al '
              'secondo piano.',
            ),
            TextField(
              controller: heightController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Altezza del telefono sopra il suolo (m)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (closingDialog) return;
              closingDialog = true;
              await _closeHeightDialog(dialogContext, null);
            },
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              if (closingDialog) return;
              closingDialog = true;
              final height = double.tryParse(
                heightController.text.trim().replaceAll(',', '.'),
              );
              await _closeHeightDialog(dialogContext, height);
            },
            child: const Text('Continua'),
          ),
        ],
      ),
    );
    final navigator = Navigator.of(context, rootNavigator: true);
    final height = await navigator.push(dialogRoute);
    await dialogRoute.completed;
    heightController.dispose();
    return height;
  }

  static String _formatDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(2)} km';

  Future<void> _closeHeightDialog(
    BuildContext dialogContext,
    double? height,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    const maximumFrames = 30;
    for (var frame = 0; frame < maximumFrames; frame++) {
      await Future.any<void>([
        WidgetsBinding.instance.endOfFrame,
        Future<void>.delayed(const Duration(milliseconds: 20)),
      ]);
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isEmpty || views.first.viewInsets.bottom == 0) break;
    }
    if (dialogContext.mounted) Navigator.pop(dialogContext, height);
  }

  Future<void> _manualDialog(BuildContext context) async {
    final terrainController = TextEditingController(
      text: beacon.terrainElevationMeters?.toString() ?? '',
    );
    final poleController = TextEditingController(
      text: beacon.poleHeightMeters.toString(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifica ${beacon.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: terrainController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Quota terreno (m)'),
            ),
            TextField(
              controller: poleController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Altezza palo (m)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final terrain = double.tryParse(terrainController.text.trim());
    final pole = double.tryParse(poleController.text.trim());
    if (terrain == null || pole == null) return;
    await controller.updateManual(
      beaconId: beacon.id,
      terrainElevationMeters: terrain,
      poleHeightMeters: pole,
    );
  }
}

final class BeaconMapScreen extends StatefulWidget {
  const BeaconMapScreen({
    required this.beacon,
    required this.controller,
    required this.observerHeightMeters,
    super.key,
  });

  final RadioBeacon beacon;
  final PointingController controller;
  final double observerHeightMeters;

  @override
  State<BeaconMapScreen> createState() => _BeaconMapScreenState();
}

final class _BeaconMapScreenState extends State<BeaconMapScreen> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.hybrid;
  bool _trafficEnabled = false;
  bool _openingExternalMap = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare({bool refreshPosition = false}) async {
    if (refreshPosition) _mapController = null;
    await widget.controller.prepare(
      beacon: widget.beacon,
      observerHeightMeters: widget.observerHeightMeters,
      refreshPosition: refreshPosition,
    );
    if (!mounted || widget.controller.solution == null) return;
    await _fitBoth();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text('Mappa • ${widget.beacon.name}'),
        actions: [
          IconButton(
            tooltip: _trafficEnabled ? 'Nascondi traffico' : 'Mostra traffico',
            onPressed: () => setState(() => _trafficEnabled = !_trafficEnabled),
            icon: Icon(
              Icons.traffic,
              color: _trafficEnabled ? const Color(0xFF7DD3E7) : null,
            ),
          ),
          PopupMenuButton<MapType>(
            tooltip: 'Tipo di mappa',
            initialValue: _mapType,
            onSelected: (value) => setState(() => _mapType = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: MapType.normal, child: Text('Normale')),
              PopupMenuItem(value: MapType.satellite, child: Text('Satellite')),
              PopupMenuItem(value: MapType.hybrid, child: Text('Ibrida')),
              PopupMenuItem(value: MapType.terrain, child: Text('Terreno')),
            ],
            icon: const Icon(Icons.layers),
          ),
          IconButton(
            tooltip: 'Licenze',
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'GPS Pointer',
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(child: _body(context)),
    ),
  );

  Widget _body(BuildContext context) {
    if (widget.controller.busy) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(widget.controller.busyMessage, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    final error = widget.controller.errorMessage;
    if (error != null) {
      return _MapError(message: error, retry: () => unawaited(_prepare()));
    }
    final location = widget.controller.location;
    final solution = widget.controller.solution;
    if (location == null || solution == null) {
      return _MapError(
        message: 'Posizione osservatore o soluzione non disponibile.',
        retry: () => unawaited(_prepare()),
      );
    }

    final observer = LatLng(location.latitude, location.longitude);
    final beacon = LatLng(
      widget.beacon.position.latitude,
      widget.beacon.position.longitude,
    );
    final accuracy = location.horizontalAccuracyMeters;
    final accuracyCircles = accuracy.isFinite && accuracy > 0
        ? <Circle>{
            Circle(
              circleId: const CircleId('gps_accuracy'),
              center: observer,
              radius: accuracy.clamp(1, 100000).toDouble(),
              fillColor: const Color(0x3319A7C4),
              strokeColor: const Color(0xCC19A7C4),
              strokeWidth: 2,
            ),
          }
        : <Circle>{};

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _midpoint(observer, beacon),
            zoom: 13,
          ),
          mapType: _mapType,
          trafficEnabled: _trafficEnabled,
          compassEnabled: true,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('observer'),
              position: observer,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(
                title: 'Punto di osservazione',
                snippet: _coordinateText(observer),
              ),
            ),
            Marker(
              markerId: const MarkerId('beacon'),
              position: beacon,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(
                title: widget.beacon.name,
                snippet: _coordinateText(beacon),
              ),
            ),
          },
          polylines: {
            Polyline(
              polylineId: const PolylineId('direct_path'),
              points: [observer, beacon],
              color: const Color(0xFF20C8E5),
              width: 5,
              geodesic: true,
            ),
          },
          circles: accuracyCircles,
          onMapCreated: (controller) {
            _mapController = controller;
            unawaited(_fitBoth());
          },
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: _MapSummary(
            beacon: widget.beacon,
            controller: widget.controller,
            solution: solution,
            onCopyCoordinates: _copyBeaconCoordinates,
            onOpenExternal: _openingExternalMap ? null : _openExternalMap,
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _MapControls(
            onFit: _fitBoth,
            onObserver: () => _centerOn(observer),
            onBeacon: () => _centerOn(beacon),
            onRefresh: widget.controller.busy
                ? null
                : () => _prepare(refreshPosition: true),
          ),
        ),
      ],
    );
  }

  Future<void> _fitBoth() async {
    final controller = _mapController;
    final location = widget.controller.location;
    if (controller == null || location == null || !mounted) return;
    final observer = LatLng(location.latitude, location.longitude);
    final beacon = LatLng(
      widget.beacon.position.latitude,
      widget.beacon.position.longitude,
    );
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if ((observer.latitude - beacon.latitude).abs() < 0.000001 &&
        (observer.longitude - beacon.longitude).abs() < 0.000001) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(observer, 18));
      return;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(
        observer.latitude < beacon.latitude
            ? observer.latitude
            : beacon.latitude,
        observer.longitude < beacon.longitude
            ? observer.longitude
            : beacon.longitude,
      ),
      northeast: LatLng(
        observer.latitude > beacon.latitude
            ? observer.latitude
            : beacon.latitude,
        observer.longitude > beacon.longitude
            ? observer.longitude
            : beacon.longitude,
      ),
    );
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
    } on PlatformException {
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_midpoint(observer, beacon), 12),
        );
      } on PlatformException {
        // The map view can still be completing its first Android layout.
      }
    }
  }

  Future<void> _centerOn(LatLng position) async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 17),
    );
  }

  Future<void> _copyBeaconCoordinates() async {
    final text =
        '${widget.beacon.position.latitude}, '
        '${widget.beacon.position.longitude}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordinate radiofaro copiate.')),
      );
    }
  }

  Future<void> _openExternalMap() async {
    if (_openingExternalMap) return;
    setState(() => _openingExternalMap = true);
    final latitude = widget.beacon.position.latitude;
    final longitude = widget.beacon.position.longitude;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      launched = false;
    }
    if (mounted) {
      setState(() => _openingExternalMap = false);
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Maps non è stato aperto.')),
        );
      }
    }
  }

  static LatLng _midpoint(LatLng first, LatLng second) => LatLng(
    (first.latitude + second.latitude) / 2,
    (first.longitude + second.longitude) / 2,
  );

  static String _coordinateText(LatLng position) =>
      '${position.latitude.toStringAsFixed(6)}, '
      '${position.longitude.toStringAsFixed(6)}';
}

final class _MapSummary extends StatelessWidget {
  const _MapSummary({
    required this.beacon,
    required this.controller,
    required this.solution,
    required this.onCopyCoordinates,
    required this.onOpenExternal,
  });

  final RadioBeacon beacon;
  final PointingController controller;
  final PointingCalculation solution;
  final VoidCallback onCopyCoordinates;
  final VoidCallback? onOpenExternal;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xE610232E),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  beacon.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_distance(solution.distanceMeters)} • '
                  'azimut ${solution.initialBearingDegrees.toStringAsFixed(1)}° '
                  '• tilt ${solution.elevationAngleDegrees.toStringAsFixed(1)}°',
                ),
                Text(
                  'Osservatore ${_elevation(controller.observerElevationMeters)} '
                  '• antenna ${_elevation(beacon.antennaElevationMeters)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                _accuracyLabel(controller),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Copia coordinate',
                onPressed: onCopyCoordinates,
                icon: const Icon(Icons.copy),
              ),
              IconButton(
                tooltip: 'Apri in Google Maps',
                onPressed: onOpenExternal,
                icon: const Icon(Icons.open_in_new),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static Widget _accuracyLabel(PointingController controller) {
    final accuracy = controller.location?.horizontalAccuracyMeters;
    if (accuracy == null || !accuracy.isFinite || accuracy < 0) {
      return const SizedBox.shrink();
    }
    return Text(
      'Accuratezza GPS: ±${accuracy.toStringAsFixed(1)} m',
      style: const TextStyle(color: Colors.white70),
    );
  }

  static String _distance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(2)} km'
      : '${meters.toStringAsFixed(0)} m';

  static String _elevation(double? meters) =>
      meters == null ? 'n/d' : '${meters.toStringAsFixed(1)} m';
}

final class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onFit,
    required this.onObserver,
    required this.onBeacon,
    required this.onRefresh,
  });

  final VoidCallback onFit;
  final VoidCallback onObserver;
  final VoidCallback onBeacon;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xE610232E),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MapAction(
            tooltip: 'Inquadra entrambi',
            icon: Icons.zoom_out_map,
            onPressed: onFit,
          ),
          _MapAction(
            tooltip: 'Vai all’osservatore',
            icon: Icons.my_location,
            onPressed: onObserver,
          ),
          _MapAction(
            tooltip: 'Vai al radiofaro',
            icon: Icons.cell_tower,
            onPressed: onBeacon,
          ),
          _MapAction(
            tooltip: 'Aggiorna posizione GPS',
            icon: Icons.gps_fixed,
            onPressed: onRefresh,
          ),
        ],
      ),
    ),
  );
}

final class _MapAction extends StatelessWidget {
  const _MapAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}

final class _MapError extends StatelessWidget {
  const _MapError({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 56),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova'),
          ),
        ],
      ),
    ),
  );
}

final class PointingScreen extends StatefulWidget {
  const PointingScreen({
    required this.beacon,
    required this.controller,
    required this.observerHeightMeters,
    super.key,
  });

  final RadioBeacon beacon;
  final PointingController controller;
  final double observerHeightMeters;

  @override
  State<PointingScreen> createState() => _PointingScreenState();
}

final class _PointingScreenState extends State<PointingScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  CameraDescription? _backCamera;
  String? _cameraError;
  String? _sensorError;
  PointingEngineV2? _engine;
  PointingEngineReading? _engineReading;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _compassTimeout;
  double? _magneticHeading;
  double? _cameraElevation;
  final DateTime _arDebugStarted = DateTime.now();
  final List<String> _arDebugMarks = <String>[];
  String? _arDebugLogPath;
  bool _showGuide = true;
  bool _showCalibrationGuide = false;
  final PointingEngineV3Field _fieldV3 = PointingEngineV3Field();
  StreamSubscription<GyroscopeEvent>? _fieldGyroscopeSubscription;
  final List<_ArFieldTimedHeading> _fieldAbsoluteSamples =
      <_ArFieldTimedHeading>[];
  double? _fieldGravityX;
  double? _fieldGravityY;
  double? _fieldGravityZ;
  double _fieldProjectedYawRateRadiansPerSecond = 0;
  DateTime? _fieldLastGyroTime;
  String? _fieldAnchorEvent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(_start());
  }

  Future<void> _start() async {
    await widget.controller.prepare(
      beacon: widget.beacon,
      observerHeightMeters: widget.observerHeightMeters,
    );
    if (!mounted || widget.controller.solution == null) return;
    _createEngine();
    await _findAndInitializeCamera();
    if (mounted && !_showGuide) _startSensors();
  }

  void _createEngine() {
    final solution = widget.controller.solution!;
    _engine = PointingEngineV2(
      targetAzimuthDegrees: solution.initialBearingDegrees,
      targetElevationDegrees: solution.elevationAngleDegrees,
      declinationDegrees: widget.controller.declinationDegrees,
    );
    _engineReading = null;
    _magneticHeading = null;
    _cameraElevation = null;
    _sensorError = null;
    _fieldV3.reset();
    _fieldAbsoluteSamples.clear();
    _fieldLastGyroTime = null;
    _fieldAnchorEvent = null;
  }

  void _startSensors() {
    _stopSensors();
    if (widget.controller.hasMagnetometer == false) return;
    final compassEvents = FlutterCompass.events;
    if (compassEvents == null) {
      setState(() => _sensorError = 'Bussola non disponibile.');
      return;
    }
    _compassSubscription = compassEvents.listen(
      _onCompass,
      onError: (_) {
        if (mounted) {
          setState(() => _sensorError = 'Lettura bussola interrotta.');
        }
      },
    );
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccelerometer);
    _fieldGyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onFieldGyroscope);
    _compassTimeout = Timer(const Duration(seconds: 5), () {
      if (mounted && _magneticHeading == null) {
        setState(() {
          _sensorError =
              'La bussola non invia dati. Il dispositivo potrebbe non '
              'avere un magnetometro.';
        });
      }
    });
  }

  void _stopSensors() {
    _compassTimeout?.cancel();
    _compassTimeout = null;
    unawaited(_compassSubscription?.cancel());
    unawaited(_accelerometerSubscription?.cancel());
    unawaited(_fieldGyroscopeSubscription?.cancel());
    _compassSubscription = null;
    _accelerometerSubscription = null;
    _fieldGyroscopeSubscription = null;
    _fieldLastGyroTime = null;
  }

  void _onCompass(CompassEvent event) {
    final heading = event.heading;
    if (!mounted || heading == null) return;
    _compassTimeout?.cancel();
    _magneticHeading = heading;
    final now = DateTime.now();
    final absoluteTrue = PointingEngineV3Field.normalize(
      heading + widget.controller.declinationDegrees,
    );
    _fieldAbsoluteSamples.add(_ArFieldTimedHeading(now, absoluteTrue));
    final cutoff = now.subtract(const Duration(seconds: 3));
    _fieldAbsoluteSamples.removeWhere((sample) => sample.time.isBefore(cutoff));
    _tryAutoAnchorFieldV3();
    _updateEngine();
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (!mounted) return;
    const alpha = 0.90;
    _fieldGravityX = _fieldGravityX == null
        ? event.x
        : alpha * _fieldGravityX! + (1 - alpha) * event.x;
    _fieldGravityY = _fieldGravityY == null
        ? event.y
        : alpha * _fieldGravityY! + (1 - alpha) * event.y;
    _fieldGravityZ = _fieldGravityZ == null
        ? event.z
        : alpha * _fieldGravityZ! + (1 - alpha) * event.z;
    _cameraElevation = DeviceOrientationCalculator.cameraElevationDegrees(
      x: event.x,
      y: event.y,
      z: event.z,
    );
    if (_engineReading == null && _magneticHeading != null) {
      _updateEngine();
    }
  }

  void _onFieldGyroscope(GyroscopeEvent event) {
    if (!mounted) return;
    final now = DateTime.now();
    final previous = _fieldLastGyroTime;
    _fieldLastGyroTime = now;
    if (previous == null) return;

    final gx = _fieldGravityX;
    final gy = _fieldGravityY;
    final gz = _fieldGravityZ;
    if (gx == null || gy == null || gz == null) return;
    final gravityNorm = math.sqrt(gx * gx + gy * gy + gz * gz);
    if (gravityNorm < 5) return;
    final projectedRate =
        event.x * gx / gravityNorm +
        event.y * gy / gravityNorm +
        event.z * gz / gravityNorm;
    _fieldProjectedYawRateRadiansPerSecond = projectedRate;
    final dt = now.difference(previous).inMicroseconds / 1000000.0;
    final stableMean = _fieldStableAbsoluteMean;
    final stationary =
        (projectedRate * 180 / math.pi).abs() <= 3.0 &&
        _fieldAbsoluteSpreadDegrees <= 2.5;
    _fieldV3.update(
      projectedYawRateRadiansPerSecond: projectedRate,
      deltaSeconds: dt,
      deviceStationary: stationary,
      stableAbsoluteTrueHeadingDegrees: stationary ? stableMean : null,
    );
    _tryAutoAnchorFieldV3();
    setState(() {});
  }

  double get _fieldAbsoluteSpreadDegrees {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 2));
    final values = _fieldAbsoluteSamples
        .where((sample) => sample.time.isAfter(cutoff))
        .map((sample) => sample.heading)
        .toList();
    if (values.length < 8) return double.infinity;
    final mean = _fieldCircularMean(values);
    var maximum = 0.0;
    for (final value in values) {
      final delta = PointingEngineV3Field.signedAngle(value - mean).abs();
      if (delta > maximum) maximum = delta;
    }
    return maximum;
  }

  double? get _fieldStableAbsoluteMean {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 2));
    final values = _fieldAbsoluteSamples
        .where((sample) => sample.time.isAfter(cutoff))
        .map((sample) => sample.heading)
        .toList();
    if (values.length < 8 || _fieldAbsoluteSpreadDegrees > 2.5) return null;
    return _fieldCircularMean(values);
  }

  double _fieldCircularMean(List<double> values) {
    var sinSum = 0.0;
    var cosSum = 0.0;
    for (final value in values) {
      final radians = value * math.pi / 180;
      sinSum += math.sin(radians);
      cosSum += math.cos(radians);
    }
    return PointingEngineV3Field.normalize(
      math.atan2(sinSum, cosSum) * 180 / math.pi,
    );
  }

  void _tryAutoAnchorFieldV3() {
    if (_fieldV3.anchored) return;
    final stableMean = _fieldStableAbsoluteMean;
    final yawDps = _fieldProjectedYawRateRadiansPerSecond * 180 / math.pi;
    if (stableMean == null || yawDps.abs() > 3.0) return;
    _fieldV3.anchorAbsolute(stableMean);
    _fieldAnchorEvent =
        'AUTO_ANCHOR true=${stableMean.toStringAsFixed(6)} '
        'spread=${_fieldAbsoluteSpreadDegrees.toStringAsFixed(6)}';
  }

  double? _fieldDelta(double? heading) {
    final target = widget.controller.solution?.initialBearingDegrees;
    if (target == null || heading == null) return null;
    return PointingEngineV3Field.signedAngle(target - heading);
  }

  void _updateEngine() {
    final engine = _engine;
    final heading = _magneticHeading;
    final elevation = _cameraElevation;
    if (engine == null || heading == null || elevation == null) return;
    final reading = engine.update(
      magneticHeadingDegrees: heading,
      cameraElevationDegrees: elevation,
    );
    if (mounted) {
      setState(() {
        _engineReading = reading;
        if (reading.state == PointingEngineState.unstable) {
          _showCalibrationGuide = true;
        }
      });
    }
  }

  Future<void> _markArDebug() async {
    final reading = _engineReading;
    final solution = widget.controller.solution;
    if (reading == null || solution == null) return;

    final now = DateTime.now().toUtc();
    final line = [
      'FLAG${_arDebugMarks.length + 1}',
      'utc=${now.toIso8601String()}',
      'beacon=${widget.beacon.name}',
      'target_true_deg=${solution.initialBearingDegrees.toStringAsFixed(6)}',
      'target_elev_deg=${solution.elevationAngleDegrees.toStringAsFixed(6)}',
      'declination_deg=${widget.controller.declinationDegrees.toStringAsFixed(6)}',
      'magnetic_heading_deg=${reading.magneticHeadingDegrees.toStringAsFixed(6)}',
      'true_heading_deg=${reading.trueHeadingDegrees.toStringAsFixed(6)}',
      'horizontal_delta_deg=${reading.horizontalDeltaDegrees.toStringAsFixed(6)}',
      'camera_elevation_deg=${reading.cameraElevationDegrees.toStringAsFixed(6)}',
      'vertical_delta_deg=${reading.verticalDeltaDegrees.toStringAsFixed(6)}',
      'state=${reading.state.name}',
      'warmup=${reading.warmupProgress.toStringAsFixed(3)}',
      'centered=${reading.centered}',
      'v3_anchored=${_fieldV3.anchored}',
      'v3_anchor=${_fieldAnchorEvent ?? ''}',
      'v3_gyro_heading_deg=${_fieldV3.snapshot.gyroHeadingDegrees?.toStringAsFixed(6) ?? ''}',
      'v3_gyro_delta_deg=${_fieldDelta(_fieldV3.snapshot.gyroHeadingDegrees)?.toStringAsFixed(6) ?? ''}',
      'v3_fusion_heading_deg=${_fieldV3.snapshot.guardedFusionHeadingDegrees?.toStringAsFixed(6) ?? ''}',
      'v3_fusion_delta_deg=${_fieldDelta(_fieldV3.snapshot.guardedFusionHeadingDegrees)?.toStringAsFixed(6) ?? ''}',
      'absolute_spread_deg=${_fieldAbsoluteSpreadDegrees.isFinite ? _fieldAbsoluteSpreadDegrees.toStringAsFixed(6) : ''}',
      'projected_yaw_rate_dps=${(_fieldProjectedYawRateRadiansPerSecond * 180 / math.pi).toStringAsFixed(6)}',
      'camera_orientation=portrait',
    ].join(' | ');

    _arDebugMarks.add(line);
    final content = <String>[
      'GPS POINTER • AR DEBUG',
      'engine=PointingEngineV2 unchanged + PointingEngineV3Field parallel',
      'session_started=${_arDebugStarted.toUtc().toIso8601String()}',
      'beacon=${widget.beacon.name}',
      'marks=${_arDebugMarks.length}',
      '',
      ..._arDebugMarks,
    ].join('\n');

    final file = await DiagnosticLogStore.writeText(
      category: 'AR',
      subject: widget.beacon.name,
      content: content,
      timestamp: _arDebugStarted,
    );
    _arDebugLogPath = file.path;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('TARGET REALE AR ${_arDebugMarks.length} salvato.'),
      ),
    );
  }

  Future<void> _shareArDebug() async {
    final path = _arDebugLogPath;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crea prima almeno una FLAG AR.')),
        );
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'GPS Pointer AR debug ${widget.beacon.name}',
      ),
    );
  }

  Future<void> _refreshPosition() async {
    if (widget.controller.busy) return;
    _stopSensors();
    setState(() {
      _engine = null;
      _engineReading = null;
      _sensorError = null;
    });
    await widget.controller.prepare(
      beacon: widget.beacon,
      observerHeightMeters: widget.observerHeightMeters,
      refreshPosition: true,
    );
    if (!mounted || widget.controller.solution == null) return;
    _createEngine();
    if (!_showGuide) _startSensors();
    setState(() {});
  }

  void _restartSensors() {
    if (widget.controller.solution == null) return;
    _stopSensors();
    _createEngine();
    _showCalibrationGuide = false;
    _startSensors();
    setState(() {});
  }

  void _acceptGuide() {
    setState(() => _showGuide = false);
    _restartSensors();
  }

  Future<void> _findAndInitializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'Fotocamera non disponibile.');
        return;
      }
      _backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _initializeCamera(_backCamera!);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() => _cameraError = _cameraMessage(error));
      }
    }
  }

  Future<void> _initializeCamera(CameraDescription description) async {
    final previous = _camera;
    _camera = null;
    await previous?.dispose();
    final next = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _camera = next;
    try {
      await next.initialize();
      if (mounted) setState(() => _cameraError = null);
    } on CameraException catch (error) {
      await next.dispose();
      _camera = null;
      if (mounted) setState(() => _cameraError = _cameraMessage(error));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    final description = _backCamera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _camera = null;
      unawaited(camera.dispose());
    } else if (state == AppLifecycleState.resumed && description != null) {
      unawaited(_initializeCamera(description));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSensors();
    unawaited(_camera?.dispose());
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('AR • ${widget.beacon.name}'),
        actions: [
          IconButton(
            onPressed:
                widget.controller.busy || _showGuide || _engineReading == null
                ? null
                : _markArDebug,
            tooltip: 'TARGET REALE QUI • salva confronto V2/V3',
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            onPressed: _arDebugLogPath == null ? null : _shareArDebug,
            tooltip: 'Esporta debug AR',
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            onPressed: widget.controller.busy
                ? null
                : () {
                    _stopSensors();
                    setState(() => _showGuide = true);
                  },
            tooltip: 'Istruzioni',
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            onPressed: widget.controller.busy || _showGuide
                ? null
                : _restartSensors,
            tooltip: 'Ristabilizza bussola',
            icon: const Icon(Icons.compass_calibration),
          ),
          IconButton(
            onPressed: widget.controller.busy || _showGuide
                ? null
                : _refreshPosition,
            tooltip: 'Aggiorna posizione osservatore',
            icon: const Icon(Icons.gps_fixed),
          ),
        ],
      ),
      body: SafeArea(child: _body(context)),
    ),
  );

  Widget _body(BuildContext context) {
    if (widget.controller.busy) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              widget.controller.busyMessage,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final error = widget.controller.errorMessage;
    if (error != null) return _error(error);
    final solution = widget.controller.solution;
    if (solution == null) return _error('Puntamento non disponibile.');
    final camera = _camera;
    if (_cameraError != null) return _error(_cameraError!);
    if (camera == null || !camera.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final reading = _engineReading;
    final ready = reading?.state == PointingEngineState.ready;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          Center(child: CameraPreview(camera)),
          const _CenterReticle(),
          if (ready) ...[
            _TargetOverlay(
              viewportSize: constraints.biggest,
              horizontalDeltaDegrees: reading!.horizontalDeltaDegrees,
              verticalDeltaDegrees: reading.verticalDeltaDegrees,
              centered: reading.centered,
              color: const Color(0xFF29C7E8),
              label: 'V2',
            ),
            if (_fieldDelta(_fieldV3.snapshot.gyroHeadingDegrees) != null)
              _TargetOverlay(
                viewportSize: constraints.biggest,
                horizontalDeltaDegrees: _fieldDelta(
                  _fieldV3.snapshot.gyroHeadingDegrees,
                )!,
                verticalDeltaDegrees: reading.verticalDeltaDegrees,
                centered:
                    _fieldDelta(_fieldV3.snapshot.gyroHeadingDegrees)!.abs() <=
                        2 &&
                    reading.verticalDeltaDegrees.abs() <= 1,
                color: const Color(0xFF63D98A),
                label: 'G',
              ),
            if (_fieldDelta(_fieldV3.snapshot.guardedFusionHeadingDegrees) !=
                null)
              _TargetOverlay(
                viewportSize: constraints.biggest,
                horizontalDeltaDegrees: _fieldDelta(
                  _fieldV3.snapshot.guardedFusionHeadingDegrees,
                )!,
                verticalDeltaDegrees: reading.verticalDeltaDegrees,
                centered:
                    _fieldDelta(
                          _fieldV3.snapshot.guardedFusionHeadingDegrees,
                        )!.abs() <=
                        2 &&
                    reading.verticalDeltaDegrees.abs() <= 1,
                color: const Color(0xFFFFB454),
                label: 'F',
              ),
          ],
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _ArStatus(
              beaconName: widget.beacon.name,
              reading: reading,
              sensorError: _sensorError,
              controller: widget.controller,
              solution: solution,
              v3Anchored: _fieldV3.anchored,
              v3GyroDelta: _fieldDelta(_fieldV3.snapshot.gyroHeadingDegrees),
              v3FusionDelta: _fieldDelta(
                _fieldV3.snapshot.guardedFusionHeadingDegrees,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _ArDetails(controller: widget.controller),
          ),
          if (_showGuide)
            GuidanceOverlay(
              title: 'Puntamento in realtà aumentata',
              illustration: GuidanceIllustration.augmentedReality,
              steps: const [
                'Tieni il telefono in mano, verticale portrait, nella stessa posizione con cui farai il puntamento.',
                'Allontanati da antenna, metallo, magneti e cavi elettrici.',
                'Resta fermo per 1–2 secondi durante la stabilizzazione iniziale, senza appoggiare il telefono.',
                'Il mirino del radiofaro apparirà soltanto quando le letture saranno stabili.',
              ],
              actionLabel: 'Inizia stabilizzazione',
              onAction: _acceptGuide,
            ),
          if (_showCalibrationGuide && !_showGuide)
            GuidanceOverlay(
              title: 'Sensori AR instabili',
              illustration: GuidanceIllustration.figureEight,
              steps: const [
                'Allontanati da antenna e oggetti metallici e prova prima a restare fermo per qualche secondo.',
                'Solo se l’instabilità continua, muovi lentamente il telefono descrivendo una figura a 8.',
                'Riprendi il telefono nella normale posizione d’uso, verticale, inquadra la zona e tienilo fermo.',
              ],
              actionLabel: 'Ho calibrato: riprova',
              onAction: _restartSensors,
            ),
        ],
      ),
    );
  }

  Widget _error(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );

  static String _cameraMessage(CameraException error) =>
      error.code == 'CameraAccessDenied'
      ? 'Permesso fotocamera negato. Abilitalo nelle impostazioni Android.'
      : 'Fotocamera non avviata: ${error.code}';
}

final class _CenterReticle extends StatelessWidget {
  const _CenterReticle();

  @override
  Widget build(BuildContext context) => const Center(
    child: _Crosshair(color: Colors.white70, size: 42, stroke: 2),
  );
}

final class _Crosshair extends StatelessWidget {
  const _Crosshair({
    required this.color,
    required this.size,
    required this.stroke,
  });

  final Color color;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CrosshairPainter(color: color, stroke: stroke),
  );
}

final class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter({required this.color, required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.22;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, center.dy - radius),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + radius),
      Offset(center.dx, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(center.dx - radius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + radius, center.dy),
      Offset(size.width, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.stroke != stroke;
}

final class _TargetOverlay extends StatelessWidget {
  const _TargetOverlay({
    required this.viewportSize,
    required this.horizontalDeltaDegrees,
    required this.verticalDeltaDegrees,
    required this.centered,
    required this.color,
    required this.label,
  });

  final Size viewportSize;
  final double horizontalDeltaDegrees;
  final double verticalDeltaDegrees;
  final bool centered;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final size = viewportSize;
    final visibleHorizontally = horizontalDeltaDegrees.abs() <= 35;
    if (!visibleHorizontally) {
      return Align(
        alignment: horizontalDeltaDegrees > 0
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.88),
            shape: BoxShape.circle,
          ),
          child: Icon(
            horizontalDeltaDegrees > 0
                ? Icons.chevron_right
                : Icons.chevron_left,
            color: Colors.white,
            size: 42,
          ),
        ),
      );
    }
    final visibleVertically = verticalDeltaDegrees.abs() <= 25;
    if (!visibleVertically) {
      return Align(
        alignment: verticalDeltaDegrees > 0
            ? Alignment.topCenter
            : Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 110),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.88),
            shape: BoxShape.circle,
          ),
          child: Icon(
            verticalDeltaDegrees > 0
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            color: Colors.white,
            size: 42,
          ),
        ),
      );
    }
    final x =
        (size.width / 2) +
        (horizontalDeltaDegrees / 35) * (size.width / 2 - 40);
    final y =
        (size.height / 2) -
        (verticalDeltaDegrees / 25) * (size.height / 2 - 150);
    return Positioned(
      left: x - 25,
      top: y - 25,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          _Crosshair(
            color: centered ? const Color(0xFF45E07A) : color,
            size: 50,
            stroke: 3,
          ),
          Positioned(
            top: -20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              color: Colors.black87,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ArFieldTimedHeading {
  const _ArFieldTimedHeading(this.time, this.heading);

  final DateTime time;
  final double heading;
}

final class _ArStatus extends StatelessWidget {
  const _ArStatus({
    required this.beaconName,
    required this.reading,
    required this.sensorError,
    required this.controller,
    required this.solution,
    required this.v3Anchored,
    required this.v3GyroDelta,
    required this.v3FusionDelta,
  });

  final String beaconName;
  final PointingEngineReading? reading;
  final String? sensorError;
  final PointingController controller;
  final PointingCalculation solution;
  final bool v3Anchored;
  final double? v3GyroDelta;
  final double? v3FusionDelta;

  @override
  Widget build(BuildContext context) => _GlassPanel(
    child: Column(
      children: [
        Text(
          beaconName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _instruction(),
          style: TextStyle(
            color: _instructionColor(),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          _diagnostics(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    ),
  );

  Color _instructionColor() {
    if (controller.hasMagnetometer == false || sensorError != null) {
      return const Color(0xFFFF7A6E);
    }
    final value = reading;
    if (value == null || value.state == PointingEngineState.warmingUp) {
      return const Color(0xFF71D7EE);
    }
    if (value.state == PointingEngineState.unstable) {
      return const Color(0xFFFF7A6E);
    }
    if (value.centered) return const Color(0xFF63D98A);
    return const Color(0xFFFFB454);
  }

  String _instruction() {
    if (controller.hasMagnetometer == false) {
      return 'MAGNETOMETRO NON PRESENTE';
    }
    if (sensorError != null) return sensorError!;
    final value = reading;
    if (value == null) return 'Mantieni fermo il telefono';
    if (value.state == PointingEngineState.warmingUp) {
      if (value.warmupProgress >= 1) {
        return 'Verifico stabilità bussola…';
      }
      return 'Stabilizzazione bussola '
          '${(value.warmupProgress * 100).round()}%';
    }
    if (value.state == PointingEngineState.unstable) {
      return 'SENSORI INSTABILI • ristabilizza';
    }
    if (value.centered) return 'PUNTAMENTO CENTRATO';
    if (value.horizontalDeltaDegrees.abs() > 2) {
      return value.horizontalDeltaDegrees > 0
          ? 'Ruota a destra '
                '${value.horizontalDeltaDegrees.abs().toStringAsFixed(0)}°'
          : 'Ruota a sinistra '
                '${value.horizontalDeltaDegrees.abs().toStringAsFixed(0)}°';
    }
    if (value.verticalDeltaDegrees.abs() > 1) {
      return value.verticalDeltaDegrees > 0
          ? 'Alza ${value.verticalDeltaDegrees.abs().toStringAsFixed(0)}°'
          : 'Abbassa ${value.verticalDeltaDegrees.abs().toStringAsFixed(0)}°';
    }
    return 'Mantieni la posizione';
  }

  String _diagnostics() {
    final value = reading;
    final target = solution.initialBearingDegrees.toStringAsFixed(1);
    final tilt = solution.elevationAngleDegrees.toStringAsFixed(1);
    if (value == null) {
      return 'Target $target° • ${_distance(solution.distanceMeters)} • '
          'tilt $tilt°\n'
          'In attesa dei sensori…';
    }
    return 'Target $target° • ${_distance(solution.distanceMeters)} • '
        'tilt $tilt°\n'
        'Mag raw ${value.magneticHeadingDegrees.toStringAsFixed(1)}° • '
        'decl ${controller.declinationDegrees.toStringAsFixed(1)}° • '
        'geo filtr. ${value.trueHeadingDegrees.toStringAsFixed(1)}°\n'
        'Camera ${value.cameraElevationDegrees.toStringAsFixed(1)}° • '
        'delta H ${value.horizontalDeltaDegrees.toStringAsFixed(1)}° • '
        'sensori ${_sensorState(value.state)}\n'
        'V2 Δ ${value.horizontalDeltaDegrees.toStringAsFixed(1)}° • '
        'G ${v3GyroDelta?.toStringAsFixed(1) ?? '—'}° • '
        'F ${v3FusionDelta?.toStringAsFixed(1) ?? '—'}° • '
        '${v3Anchored ? 'V3 ANCORATO' : 'V3 IN ATTESA'}';
  }

  static String _sensorState(PointingEngineState state) => switch (state) {
    PointingEngineState.warmingUp => 'in stabilizzazione',
    PointingEngineState.ready => 'stabilizzati',
    PointingEngineState.unstable => 'instabili',
  };

  static String _distance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(2)} km'
      : '${meters.toStringAsFixed(0)} m';
}

final class _ArDetails extends StatelessWidget {
  const _ArDetails({required this.controller});

  final PointingController controller;

  @override
  Widget build(BuildContext context) => _GlassPanel(
    child: Text(
      'Terreno locale Open-Meteo ${controller.terrainElevationMeters!.toStringAsFixed(1)} m'
      ' + installatore ${controller.observerHeightMeters.toStringAsFixed(1)} m'
      ' = quota osservatore ${controller.observerElevationMeters!.toStringAsFixed(1)} m\n'
      'Posizione bloccata: ${controller.positionSamplesUsed} campioni • '
      'GPS ±${controller.location!.horizontalAccuracyMeters.toStringAsFixed(1)} m\n'
      'AR CAMPO: V2 blu • V3 Gyro verde • V3 Fusion arancio.',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white),
    ),
  );
}

final class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white30),
    ),
    child: child,
  );
}

final class _Messages extends StatefulWidget {
  const _Messages({required this.controller});

  final CatalogueController controller;

  @override
  State<_Messages> createState() => _MessagesState();
}

final class _MessagesState extends State<_Messages> {
  Timer? _noticeTimer;
  String? _hiddenNotice;
  String? _lastNotice;

  @override
  void initState() {
    super.initState();
    _lastNotice = widget.controller.noticeMessage;
    widget.controller.addListener(_handleControllerChanged);
    _scheduleNoticeAutoHide(_lastNotice);
  }

  @override
  void didUpdateWidget(covariant _Messages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _lastNotice = widget.controller.noticeMessage;
      _scheduleNoticeAutoHide(_lastNotice);
    }
  }

  void _handleControllerChanged() {
    final notice = widget.controller.noticeMessage;
    if (notice == _lastNotice) return;
    _lastNotice = notice;
    _scheduleNoticeAutoHide(notice);
  }

  void _scheduleNoticeAutoHide(String? notice) {
    _noticeTimer?.cancel();
    _hiddenNotice = null;
    if (notice == null) return;

    final duration = notice == 'Posizione per distanze e ordinamento acquisita.'
        ? const Duration(milliseconds: 450)
        : const Duration(seconds: 2);

    _noticeTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() => _hiddenNotice = notice);
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.controller.errorMessage;
    final rawNotice = widget.controller.noticeMessage;
    final notice = rawNotice == _hiddenNotice ? null : rawNotice;
    if (error == null && notice == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final isError = error != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 120),
      child: Container(
        key: ValueKey<String>(error ?? notice!),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error ?? notice!),
            for (final issue in widget.controller.issues.take(8))
              Text('• $issue'),
          ],
        ),
      ),
    );
  }
}

final class _ServerCatalogueException implements Exception {
  const _ServerCatalogueException(this.code, this.message);
  final String code;
  final String message;
}
