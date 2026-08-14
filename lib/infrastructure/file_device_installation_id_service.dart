import 'dart:io';
import 'dart:math';

import '../application/device_installation_id_service.dart';

final class FileDeviceInstallationIdService
    implements DeviceInstallationIdService {
  FileDeviceInstallationIdService(this._idFile, this._nameFile);

  static final _validId = RegExp(
    r'^GPSP-[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$',
  );

  final File _idFile;
  final File _nameFile;

  @override
  Future<DeviceIdentity> loadOrCreate() async {
    var id = '';
    if (await _idFile.exists()) {
      id = (await _idFile.readAsString()).trim();
    }
    if (!_validId.hasMatch(id)) {
      id = _generate();
      await _idFile.writeAsString(id, flush: true);
    }
    final name = await _readName();
    return DeviceIdentity(installationId: id, displayName: name);
  }

  @override
  Future<DeviceIdentity> updateDisplayName(String displayName) async {
    final normalized = displayName.trim();
    if (normalized.isEmpty || normalized.length > 80) {
      throw const FormatException(
        'Il nome dispositivo deve contenere da 1 a 80 caratteri.',
      );
    }
    if (normalized.contains('\n') || normalized.contains('\r')) {
      throw const FormatException('Il nome dispositivo non è valido.');
    }
    final identity = await loadOrCreate();
    await _nameFile.writeAsString(normalized, flush: true);
    return DeviceIdentity(
      installationId: identity.installationId,
      displayName: normalized,
    );
  }

  Future<String?> _readName() async {
    if (!await _nameFile.exists()) return null;
    final name = (await _nameFile.readAsString()).trim();
    return name.isEmpty ? null : name;
  }

  static String _generate() {
    final random = Random.secure();
    final hex = List<int>.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return 'GPSP-${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
