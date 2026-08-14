import '../domain/radio_beacon_catalogue.dart';
import '../import/radio_beacon_file_parser.dart';
import '../repositories/radio_beacon_repository.dart';

final class RadioBeaconImportSummary {
  const RadioBeaconImportSummary({
    required this.formatVersion,
    required this.importedCount,
  });

  final int formatVersion;
  final int importedCount;
}

/// Parses and validates the whole file before replacing stored data.
final class RadioBeaconImportService {
  const RadioBeaconImportService({
    required this.parser,
    required this.repository,
  });

  final RadioBeaconFileParser parser;
  final RadioBeaconRepository repository;

  Future<RadioBeaconImportSummary> importText(
    String content, {
    required String sourceFileName,
    required DateTime importedAt,
  }) async {
    final result = parser.parse(content);
    final catalogue = RadioBeaconCatalogue(
      beacons: result.beacons,
      sourceFileName: sourceFileName,
      importedAt: importedAt,
    );
    await repository.replace(catalogue);
    return RadioBeaconImportSummary(
      formatVersion: result.formatVersion,
      importedCount: result.beacons.length,
    );
  }

  Future<RadioBeaconCatalogue?> currentCatalogue() => repository.load();

  Future<void> replaceCatalogue(RadioBeaconCatalogue catalogue) =>
      repository.replace(catalogue);
}
