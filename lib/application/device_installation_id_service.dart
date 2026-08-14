final class DeviceIdentity {
  const DeviceIdentity({required this.installationId, this.displayName});

  final String installationId;
  final String? displayName;
}

abstract interface class DeviceInstallationIdService {
  Future<DeviceIdentity> loadOrCreate();

  Future<DeviceIdentity> updateDisplayName(String displayName);
}
