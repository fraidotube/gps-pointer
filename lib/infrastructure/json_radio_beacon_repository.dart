import 'dart:convert';
import 'dart:io';

import '../core/core.dart';

final class JsonRadioBeaconRepository implements RadioBeaconRepository {
  JsonRadioBeaconRepository(this.file);

  static const _schemaVersion = 1;
  final File file;

  @override
  Future<RadioBeaconCatalogue?> load() async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != _schemaVersion ||
          decoded['sourceFileName'] is! String ||
          decoded['importedAt'] is! String ||
          decoded['beacons'] is! List<dynamic>) {
        throw const FormatException('Schema archivio non valido.');
      }

      final beacons = (decoded['beacons'] as List<dynamic>)
          .map(_beaconFromJson)
          .toList(growable: false);
      return RadioBeaconCatalogue(
        beacons: beacons,
        sourceFileName: decoded['sourceFileName'] as String,
        importedAt: DateTime.parse(decoded['importedAt'] as String),
      );
    } catch (error) {
      throw FormatException('Archivio locale non valido.', error);
    }
  }

  @override
  Future<void> replace(RadioBeaconCatalogue catalogue) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    final encoded = jsonEncode(<String, Object>{
      'schemaVersion': _schemaVersion,
      'sourceFileName': catalogue.sourceFileName,
      'importedAt': catalogue.importedAt.toIso8601String(),
      'beacons': catalogue.beacons.map(_beaconToJson).toList(growable: false),
    });

    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString(encoded, flush: true);

    if (await backup.exists()) await backup.delete();
    final hadPrevious = await file.exists();
    if (hadPrevious) await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await file.exists()) await file.delete();
      if (await backup.exists()) await backup.rename(file.path);
      rethrow;
    }
  }

  static RadioBeacon _beaconFromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Radiofaro non valido.');
    }
    final id = value['id'];
    final name = value['name'];
    final latitude = value['latitude'];
    final longitude = value['longitude'];
    final terrain = value['terrainElevationMeters'];
    final pole = value['poleHeightMeters'];
    final source = value['elevationSource'];
    final horizontalAccuracy = value['horizontalAccuracyMeters'];
    final verticalAccuracy = value['verticalAccuracyMeters'];
    if (id is! String ||
        name is! String ||
        latitude is! num ||
        longitude is! num ||
        (terrain != null && terrain is! num) ||
        pole is! num ||
        (source != null && source is! String) ||
        (horizontalAccuracy != null && horizontalAccuracy is! num) ||
        (verticalAccuracy != null && verticalAccuracy is! num)) {
      throw const FormatException('Campi radiofaro non validi.');
    }
    return RadioBeacon(
      id: id,
      name: name,
      position: GeoPoint.validated(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
      terrainElevationMeters: (terrain as num?)?.toDouble(),
      poleHeightMeters: pole.toDouble(),
      elevationSource: source as String?,
      horizontalAccuracyMeters: (horizontalAccuracy as num?)?.toDouble(),
      verticalAccuracyMeters: (verticalAccuracy as num?)?.toDouble(),
    );
  }

  static Map<String, Object?> _beaconToJson(RadioBeacon beacon) => {
    'id': beacon.id,
    'name': beacon.name,
    'latitude': beacon.position.latitude,
    'longitude': beacon.position.longitude,
    'terrainElevationMeters': beacon.terrainElevationMeters,
    'poleHeightMeters': beacon.poleHeightMeters,
    'elevationSource': beacon.elevationSource,
    'horizontalAccuracyMeters': beacon.horizontalAccuracyMeters,
    'verticalAccuracyMeters': beacon.verticalAccuracyMeters,
  };
}
