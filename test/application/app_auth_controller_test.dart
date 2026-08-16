import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/application/app_auth.dart';

void main() {
  test(
    'login valido registra sessione e salva solo refresh per accesso rapido',
    () async {
      final api = _FakeApi();
      final store = _FakeStore();
      final controller = AppAuthController(
        api: api,
        store: store,
        deviceUnlock: _FakeUnlock(),
        deviceId: 'DEVICE-1',
        deviceNameProvider: () => 'Samsung Test',
        appVersion: '1.0.0+20',
      );

      await controller.initialize();
      final ok = await controller.login(
        username: 'utente',
        password: 'password',
        enableQuickUnlock: true,
      );

      expect(ok, isTrue);
      expect(controller.state, AppAuthState.signedIn);
      expect(store.refreshToken, 'refresh-1');
      expect(api.lastDeviceId, 'DEVICE-1');
      expect(api.lastDeviceName, 'Samsung Test');
    },
  );

  test('sblocco locale usa refresh e ruota il token salvato', () async {
    final api = _FakeApi();
    final store = _FakeStore(
      refreshToken: 'refresh-old',
      username: 'utente',
      displayName: 'Utente Test',
      quickUnlock: true,
    );
    final controller = AppAuthController(
      api: api,
      store: store,
      deviceUnlock: _FakeUnlock(),
      deviceId: 'DEVICE-1',
      deviceNameProvider: () => 'Samsung Test',
      appVersion: '1.0.0+20',
    );

    await controller.initialize();
    expect(controller.state, AppAuthState.locked);
    final ok = await controller.unlock();

    expect(ok, isTrue);
    expect(controller.state, AppAuthState.signedIn);
    expect(store.refreshToken, 'refresh-2');
  });

  test('refresh esplicito ruota access e refresh token', () async {
    final api = _FakeApi();
    final store = _FakeStore(
      refreshToken: 'refresh-old',
      username: 'utente',
      displayName: 'Utente Test',
      quickUnlock: true,
    );
    final controller = AppAuthController(
      api: api,
      store: store,
      deviceUnlock: _FakeUnlock(),
      deviceId: 'DEVICE-1',
      deviceNameProvider: () => 'Samsung Test',
      appVersion: '1.0.0+21',
    );

    await controller.initialize();
    final ok = await controller.refreshAccessToken();

    expect(ok, isTrue);
    expect(controller.accessToken, 'access-2');
    expect(store.refreshToken, 'refresh-2');
  });

  test('revoca dispositivo cancella la sessione locale', () async {
    final api = _FakeApi(refreshError: true);
    final store = _FakeStore(
      refreshToken: 'refresh-old',
      username: 'utente',
      displayName: 'Utente Test',
      quickUnlock: true,
    );
    final controller = AppAuthController(
      api: api,
      store: store,
      deviceUnlock: _FakeUnlock(),
      deviceId: 'DEVICE-1',
      deviceNameProvider: () => 'Samsung Test',
      appVersion: '1.0.0+20',
    );

    await controller.initialize();
    final ok = await controller.unlock();

    expect(ok, isFalse);
    expect(controller.state, AppAuthState.signedOut);
    expect(store.refreshToken, isNull);
  });
}

final class _FakeApi implements AppAuthApi {
  _FakeApi({this.refreshError = false});

  final bool refreshError;
  String? lastDeviceId;
  String? lastDeviceName;

  @override
  Future<(AppAuthTokens, AppAuthUser)> login({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    required String appVersion,
  }) async {
    lastDeviceId = deviceId;
    lastDeviceName = deviceName;
    return (
      const AppAuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      const AppAuthUser(
        username: 'utente',
        displayName: 'Utente Test',
        role: 'admin',
        roleLabel: 'Amministratore',
      ),
    );
  }

  @override
  Future<AppAuthTokens> refresh({
    required String refreshToken,
    required String deviceId,
    required String appVersion,
  }) async {
    if (refreshError) {
      throw const AppAuthException(
        'device_revoked',
        'Dispositivo non autorizzato o revocato.',
      );
    }
    return const AppAuthTokens(
      accessToken: 'access-2',
      refreshToken: 'refresh-2',
    );
  }

  @override
  Future<void> logout(String accessToken) async {}
}

final class _FakeStore implements AppAuthStore {
  _FakeStore({
    this.refreshToken,
    this.username,
    this.displayName,
    this.quickUnlock = false,
  });

  String? refreshToken;
  String? username;
  String? displayName;
  bool quickUnlock;

  @override
  Future<void> clear() async {
    refreshToken = null;
    username = null;
    displayName = null;
    quickUnlock = false;
  }

  @override
  Future<String?> readDisplayName() async => displayName;

  @override
  Future<bool> readQuickUnlockEnabled() async => quickUnlock;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<String?> readUsername() async => username;

  @override
  Future<void> save({
    required String refreshToken,
    required AppAuthUser user,
    required bool quickUnlockEnabled,
  }) async {
    this.refreshToken = refreshToken;
    username = user.username;
    displayName = user.displayName;
    quickUnlock = quickUnlockEnabled;
  }
}

final class _FakeUnlock implements DeviceUnlockService {
  @override
  Future<bool> authenticate() async => true;

  @override
  Future<bool> isAvailable() async => true;
}
