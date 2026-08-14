import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import '../application/radio_beacon_file_picker.dart';

final class SystemRadioBeaconFilePicker implements RadioBeaconFilePicker {
  static const _maximumBytes = 2 * 1024 * 1024;

  @override
  Future<SelectedRadioBeaconFile?> selectFile() async {
    const textFiles = XTypeGroup(
      label: 'File radiofari GPS Pointer',
      extensions: <String>['txt'],
      mimeTypes: <String>['text/plain'],
    );
    final file = await openFile(acceptedTypeGroups: const [textFiles]);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.length > _maximumBytes) {
      throw const RadioBeaconFileSelectionException(
        'Il file supera il limite di 2 MB.',
      );
    }
    try {
      return SelectedRadioBeaconFile(
        name: file.name,
        content: utf8.decode(bytes),
      );
    } on FormatException {
      throw const RadioBeaconFileSelectionException(
        'Il file non è codificato correttamente in UTF-8.',
      );
    }
  }
}
