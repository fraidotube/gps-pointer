import '../domain/radio_beacon_catalogue.dart';

abstract interface class RadioBeaconRepository {
  Future<RadioBeaconCatalogue?> load();

  /// Replaces the complete catalogue only after validation has succeeded.
  Future<void> replace(RadioBeaconCatalogue catalogue);
}

final class InMemoryRadioBeaconRepository implements RadioBeaconRepository {
  RadioBeaconCatalogue? _catalogue;

  @override
  Future<RadioBeaconCatalogue?> load() async => _catalogue;

  @override
  Future<void> replace(RadioBeaconCatalogue catalogue) async {
    _catalogue = catalogue;
  }
}
