import 'radio_link_simulation.dart';

abstract interface class RadioLinkSimulationRepository {
  Future<List<RadioLinkSimulation>> loadAll();
  Future<void> save(RadioLinkSimulation simulation);
  Future<void> delete(String id);
}
