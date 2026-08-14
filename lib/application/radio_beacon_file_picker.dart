final class SelectedRadioBeaconFile {
  const SelectedRadioBeaconFile({required this.name, required this.content});

  final String name;
  final String content;
}

final class RadioBeaconFileSelectionException implements Exception {
  const RadioBeaconFileSelectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class RadioBeaconFilePicker {
  Future<SelectedRadioBeaconFile?> selectFile();
}
