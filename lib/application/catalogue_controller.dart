import 'package:flutter/foundation.dart';

import '../core/core.dart';
import 'catalogue_export_service.dart';
import 'device_installation_id_service.dart';
import 'device_location_service.dart';
import 'radio_beacon_file_picker.dart';

typedef UtcClock = DateTime Function();
typedef CatalogueImportApproval =
    Future<bool> Function(CatalogueImportPreview preview);

final class CatalogueImportPreview {
  const CatalogueImportPreview({
    required this.fileName,
    required this.exportedAtUtc,
    required this.sourceDeviceId,
    required this.sourceDeviceName,
    required this.fileNameDiffers,
    required this.deviceDiffers,
  });

  final String fileName;
  final DateTime? exportedAtUtc;
  final String? sourceDeviceId;
  final String? sourceDeviceName;
  final bool fileNameDiffers;
  final bool deviceDiffers;

  bool get requiresApproval => fileNameDiffers || deviceDiffers;
}

final class CatalogueController extends ChangeNotifier {
  static const standardCatalogueFileName = 'radiofari_gps_pointer.txt';

  factory CatalogueController({
    required RadioBeaconImportService importService,
    required RadioBeaconFilePicker filePicker,
    required RadioBeaconElevationService elevationService,
    required DeviceLocationService locationService,
    required CatalogueExportService exportService,
    required DeviceInstallationIdService identityService,
    UtcClock? clock,
  }) => CatalogueController._(
    importService,
    filePicker,
    elevationService,
    locationService,
    exportService,
    identityService,
    clock ?? DateTime.now,
  );

  CatalogueController._(
    this._importService,
    this._filePicker,
    this._elevationService,
    this._locationService,
    this._exportService,
    this._identityService,
    this._clock,
  );

  final RadioBeaconImportService _importService;
  final RadioBeaconFilePicker _filePicker;
  final RadioBeaconElevationService _elevationService;
  final DeviceLocationService _locationService;
  final CatalogueExportService _exportService;
  final DeviceInstallationIdService _identityService;
  final UtcClock _clock;
  final RadioBeaconFileExporter _exporter = const RadioBeaconFileExporter();

  RadioBeaconCatalogue? _catalogue;
  String? _errorMessage;
  String? _noticeMessage;
  List<RadioBeaconImportIssue> _issues = const [];
  bool _busy = false;
  DeviceLocationReading? _catalogueFilterLocation;
  DeviceIdentity? _deviceIdentity;

  RadioBeaconCatalogue? get catalogue => _catalogue;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  List<RadioBeaconImportIssue> get issues => List.unmodifiable(_issues);
  bool get busy => _busy;
  DeviceIdentity get deviceIdentity => _deviceIdentity!;
  String get installationId => deviceIdentity.installationId;
  String? get deviceDisplayName => deviceIdentity.displayName;
  DeviceLocationReading? get catalogueFilterLocation =>
      _catalogueFilterLocation;

  GeoPoint? get catalogueFilterPosition {
    final reading = _catalogueFilterLocation;
    if (reading == null) return null;
    return GeoPoint.validated(
      latitude: reading.latitude,
      longitude: reading.longitude,
    );
  }

  Future<void> initialize() async {
    await _execute(() async {
      _deviceIdentity = await _identityService.loadOrCreate();
      _catalogue = await _importService.currentCatalogue();
    });
  }

  Future<void> updateDeviceDisplayName(String displayName) async {
    await _execute(() async {
      _deviceIdentity = await _identityService.updateDisplayName(displayName);
      _noticeMessage = 'Nome dispositivo aggiornato.';
    });
  }

  Future<bool> importCatalogue({CatalogueImportApproval? approve}) async {
    var success = false;
    await _execute(() async {
      final selected = await _filePicker.selectFile();
      if (selected == null) return;
      final parsed = _importService.parser.parse(selected.content);
      final preview = CatalogueImportPreview(
        fileName: selected.name,
        exportedAtUtc: parsed.exportedAtUtc,
        sourceDeviceId: parsed.deviceId,
        sourceDeviceName: parsed.deviceName,
        fileNameDiffers: selected.name != standardCatalogueFileName,
        deviceDiffers:
            parsed.deviceId != null && parsed.deviceId != installationId,
      );
      if (preview.requiresApproval) {
        if (approve == null) {
          throw const FormatException(
            'Il file richiede una conferma esplicita prima dell’importazione.',
          );
        }
        if (!await approve(preview)) {
          _noticeMessage = 'Importazione annullata. Archivio non modificato.';
          return;
        }
      }
      await _importService.importText(
        selected.content,
        sourceFileName: selected.name,
        importedAt: _clock().toUtc(),
      );
      _catalogue = await _importService.currentCatalogue();
      success = true;
      await _fillMissingElevations();
      _noticeMessage = parsed.exportedAtUtc == null || parsed.deviceId == null
          ? 'Archivio v3 caricato. Metadata mancanti completati da questo dispositivo.'
          : 'Archivio v3 caricato correttamente.';
    });
    return success;
  }

  Future<bool> refreshCatalogueFilterPosition() async {
    var success = false;
    await _execute(() async {
      _catalogueFilterLocation = await _locationService.readCurrentPosition();
      _noticeMessage = 'Posizione per distanze e ordinamento acquisita.';
      success = true;
    });
    return success;
  }

  Future<void> loadOpenMeteo(String beaconId) async {
    await _execute(() async {
      final beacon = _find(beaconId);
      final enriched = await _elevationService.loadTerrainElevation(beacon);
      await _replaceBeacon(
        RadioBeacon(
          id: enriched.id,
          name: enriched.name,
          position: enriched.position,
          terrainElevationMeters: enriched.terrainElevationMeters,
          poleHeightMeters: enriched.poleHeightMeters,
          elevationSource: 'open_meteo_copernicus_glo90',
        ),
      );
      _noticeMessage = 'Quota Open-Meteo acquisita.';
    });
  }

  Future<void> measureOnSite(String beaconId) async {
    await _execute(() async {
      final reading = await _locationService.readCurrentPosition();
      final beacon = _find(beaconId);
      await _replaceBeacon(
        beacon.copyWith(
          position: GeoPoint.validated(
            latitude: reading.latitude,
            longitude: reading.longitude,
          ),
          terrainElevationMeters: reading.altitudeMeters,
          elevationSource: 'gps_msl_rilevato_sul_posto',
          horizontalAccuracyMeters: reading.horizontalAccuracyMeters,
          verticalAccuracyMeters: reading.verticalAccuracyMeters,
        ),
      );
      _noticeMessage = 'Posizione e quota GPS acquisite.';
    });
  }

  Future<void> updateManual({
    required String beaconId,
    required double terrainElevationMeters,
    required double poleHeightMeters,
  }) async {
    await _execute(() async {
      if (!terrainElevationMeters.isFinite ||
          !poleHeightMeters.isFinite ||
          poleHeightMeters < 0) {
        throw const FormatException('Valori manuali non validi.');
      }
      final beacon = _find(beaconId);
      await _replaceBeacon(
        RadioBeacon(
          id: beacon.id,
          name: beacon.name,
          position: beacon.position,
          terrainElevationMeters: terrainElevationMeters,
          poleHeightMeters: poleHeightMeters,
          elevationSource: 'manuale',
        ),
      );
      _noticeMessage = 'Quota e altezza palo aggiornate.';
    });
  }

  Future<bool> addManualBeacon({
    required String name,
    required double latitude,
    required double longitude,
    required double? terrainElevationMeters,
    required double poleHeightMeters,
  }) async {
    var success = false;
    await _execute(() async {
      final current = _catalogue;
      if (current == null) {
        throw const FormatException('Archivio radiofari non disponibile.');
      }
      final normalizedName = name.trim();
      if (normalizedName.isEmpty) {
        throw const FormatException('Il nome è obbligatorio.');
      }
      final generatedId = RadioBeaconIdGenerator.generate(
        name: normalizedName,
        existingIds: current.beacons.map((beacon) => beacon.id),
      );
      if (!poleHeightMeters.isFinite || poleHeightMeters < 0) {
        throw const FormatException('Altezza palo non valida.');
      }
      if (terrainElevationMeters != null && !terrainElevationMeters.isFinite) {
        throw const FormatException('Quota terreno non valida.');
      }

      final candidate = RadioBeacon(
        id: generatedId,
        name: normalizedName,
        position: GeoPoint.validated(latitude: latitude, longitude: longitude),
        terrainElevationMeters: terrainElevationMeters,
        poleHeightMeters: poleHeightMeters,
        elevationSource: terrainElevationMeters == null ? null : 'manuale',
      );
      final proposed = RadioBeaconCatalogue(
        beacons: [...current.beacons, candidate],
        sourceFileName: current.sourceFileName,
        importedAt: current.importedAt,
      );

      // SAFE gate: serialize and re-parse the complete future catalogue before
      // the transactional repository replacement. Any invalid existing or new
      // row aborts the operation and leaves the previous catalogue untouched.
      final validated = _importService.parser.parse(
        _exporter.export(
          proposed,
          exportedAtUtc: _clock().toUtc(),
          deviceId: installationId,
          deviceName: deviceDisplayName!,
        ),
      );
      final replacement = RadioBeaconCatalogue(
        beacons: validated.beacons,
        sourceFileName: current.sourceFileName,
        importedAt: current.importedAt,
      );
      await _importService.replaceCatalogue(replacement);
      _catalogue = replacement;
      _noticeMessage = 'Radiofaro $normalizedName aggiunto.';
      success = true;
    });
    return success;
  }

  Future<void> exportCatalogue() async {
    await _execute(() async {
      final current = _catalogue;
      if (current == null) return;
      final name = deviceDisplayName;
      if (name == null) {
        throw const FormatException('Configura prima il nome dispositivo.');
      }
      await _exportService.export(
        _exporter.export(
          current,
          exportedAtUtc: _clock().toUtc(),
          deviceId: installationId,
          deviceName: name,
        ),
      );
    });
  }

  Future<void> _fillMissingElevations() async {
    final current = _catalogue;
    if (current == null) return;
    var failures = 0;
    for (final beacon in List<RadioBeacon>.from(current.beacons)) {
      if (beacon.terrainElevationMeters != null) continue;
      try {
        final enriched = await _elevationService.loadTerrainElevation(beacon);
        await _replaceBeacon(
          RadioBeacon(
            id: enriched.id,
            name: enriched.name,
            position: enriched.position,
            terrainElevationMeters: enriched.terrainElevationMeters,
            poleHeightMeters: enriched.poleHeightMeters,
            elevationSource: 'open_meteo_copernicus_glo90',
          ),
        );
      } catch (_) {
        failures++;
      }
    }
    if (failures > 0) {
      _noticeMessage =
          '$failures quote non acquisite. Il catalogo resta utilizzabile.';
    }
  }

  RadioBeacon _find(String id) =>
      _catalogue!.beacons.singleWhere((beacon) => beacon.id == id);

  Future<void> _replaceBeacon(RadioBeacon replacement) async {
    final current = _catalogue!;
    final updated = RadioBeaconCatalogue(
      beacons: current.beacons
          .map((beacon) => beacon.id == replacement.id ? replacement : beacon)
          .toList(growable: false),
      sourceFileName: current.sourceFileName,
      importedAt: current.importedAt,
    );
    await _importService.replaceCatalogue(updated);
    _catalogue = updated;
  }

  Future<void> _execute(Future<void> Function() action) async {
    _busy = true;
    _errorMessage = null;
    _noticeMessage = null;
    _issues = const [];
    notifyListeners();
    try {
      await action();
    } on RadioBeaconImportException catch (error) {
      _errorMessage =
          'Il file non è valido. L’archivio precedente non è stato modificato.';
      _issues = error.issues;
    } on RadioBeaconFileSelectionException catch (error) {
      _errorMessage = error.message;
    } on DeviceLocationException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Operazione non completata: $error';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
