import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

final class AppAuthUser {
  const AppAuthUser({
    required this.username,
    required this.displayName,
    required this.role,
    required this.roleLabel,
  });

  final String username;
  final String displayName;
  final String role;
  final String roleLabel;

  factory AppAuthUser.fromJson(Map<String, dynamic> json) => AppAuthUser(
    username: json['username'] as String? ?? '',
    displayName: json['display_name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    roleLabel: json['role_label'] as String? ?? '',
  );
}

final class AppAuthTokens {
  const AppAuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

final class AppAuthException implements Exception {
  const AppAuthException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract interface class AppAuthApi {
  Future<(AppAuthTokens, AppAuthUser)> login({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    required String appVersion,
  });

  Future<AppAuthTokens> refresh({
    required String refreshToken,
    required String deviceId,
    required String appVersion,
  });

  Future<void> logout(String accessToken);
}

final class HttpAppAuthApi implements AppAuthApi {
  HttpAppAuthApi({required this.client, required this.baseUri});

  final http.Client client;
  final Uri baseUri;

  Uri _uri(String path) =>
      baseUri.replace(path: path, query: null, fragment: null);

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AppAuthException(
        'invalid_response',
        'Risposta non valida dal server GPS Pointer.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AppAuthException(
        'invalid_response',
        'Risposta non valida dal server GPS Pointer.',
      );
    }
    if (response.statusCode >= 400 || decoded['ok'] != true) {
      throw AppAuthException(
        decoded['error'] as String? ?? 'server_error',
        decoded['message'] as String? ?? 'Autenticazione non riuscita.',
      );
    }
    return decoded;
  }

  @override
  Future<(AppAuthTokens, AppAuthUser)> login({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    required String appVersion,
  }) async {
    final response = await client
        .post(
          _uri('/api/v1/auth/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
            'device_id': deviceId,
            'device_name': deviceName,
            'platform': 'android',
            'app_version': appVersion,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final json = _decode(response);
    return (
      AppAuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      ),
      AppAuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<AppAuthTokens> refresh({
    required String refreshToken,
    required String deviceId,
    required String appVersion,
  }) async {
    final response = await client
        .post(
          _uri('/api/v1/auth/refresh'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'refresh_token': refreshToken,
            'device_id': deviceId,
            'app_version': appVersion,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final json = _decode(response);
    return AppAuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }

  @override
  Future<void> logout(String accessToken) async {
    final response = await client
        .post(
          _uri('/api/v1/auth/logout'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode >= 400 && response.statusCode != 401) {
      _decode(response);
    }
  }
}

abstract interface class AppAuthStore {
  Future<String?> readRefreshToken();
  Future<String?> readUsername();
  Future<String?> readDisplayName();
  Future<bool> readQuickUnlockEnabled();
  Future<void> save({
    required String refreshToken,
    required AppAuthUser user,
    required bool quickUnlockEnabled,
  });
  Future<void> clear();
}

final class SecureAppAuthStore implements AppAuthStore {
  SecureAppAuthStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          FlutterSecureStorage(
            aOptions: AndroidOptions(migrateWithBackup: true),
          );

  static const _refreshKey = 'gpsp.auth.refresh';
  static const _usernameKey = 'gpsp.auth.username';
  static const _displayNameKey = 'gpsp.auth.display_name';
  static const _quickUnlockKey = 'gpsp.auth.quick_unlock';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<String?> readUsername() => _storage.read(key: _usernameKey);

  @override
  Future<String?> readDisplayName() => _storage.read(key: _displayNameKey);

  @override
  Future<bool> readQuickUnlockEnabled() async =>
      await _storage.read(key: _quickUnlockKey) == '1';

  @override
  Future<void> save({
    required String refreshToken,
    required AppAuthUser user,
    required bool quickUnlockEnabled,
  }) async {
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _usernameKey, value: user.username);
    await _storage.write(key: _displayNameKey, value: user.displayName);
    await _storage.write(
      key: _quickUnlockKey,
      value: quickUnlockEnabled ? '1' : '0',
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _displayNameKey);
    await _storage.delete(key: _quickUnlockKey);
  }
}

abstract interface class DeviceUnlockService {
  Future<bool> isAvailable();
  Future<bool> authenticate();
}

final class LocalDeviceUnlockService implements DeviceUnlockService {
  LocalDeviceUnlockService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _authentication.isDeviceSupported();
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _authentication.authenticate(
        localizedReason: 'Sblocca GPS Pointer',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}

enum AppAuthState { loading, signedOut, locked, signedIn }

final class AppAuthController extends ChangeNotifier {
  AppAuthController({
    required this.api,
    required this.store,
    required this.deviceUnlock,
    required this.deviceId,
    required this.deviceNameProvider,
    required this.appVersion,
  });

  final AppAuthApi api;
  final AppAuthStore store;
  final DeviceUnlockService deviceUnlock;
  final String deviceId;
  final String Function() deviceNameProvider;
  final String appVersion;

  AppAuthState _state = AppAuthState.loading;
  bool _busy = false;
  String? _message;
  String? _accessToken;
  String? _refreshToken;
  AppAuthUser? _user;
  String? _savedUsername;
  String? _savedDisplayName;
  bool _quickUnlockAvailable = false;

  AppAuthState get state => _state;
  bool get busy => _busy;
  String? get message => _message;
  AppAuthUser? get user => _user;
  String? get accessToken => _accessToken;
  String? get savedUsername => _savedUsername;
  String? get savedDisplayName => _savedDisplayName;
  bool get quickUnlockAvailable => _quickUnlockAvailable;

  Future<void> initialize() async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      _savedUsername = await store.readUsername();
      _savedDisplayName = await store.readDisplayName();
      final quickEnabled = await store.readQuickUnlockEnabled();
      final refresh = await store.readRefreshToken();
      _quickUnlockAvailable =
          quickEnabled && refresh != null && await deviceUnlock.isAvailable();
      _state = refresh != null ? AppAuthState.locked : AppAuthState.signedOut;
    } catch (_) {
      _state = AppAuthState.signedOut;
      _message = 'Archivio credenziali sicuro non disponibile.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    required bool enableQuickUnlock,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      _message = 'Inserisci nome utente e password.';
      notifyListeners();
      return false;
    }
    return _run(() async {
      final (tokens, user) = await api.login(
        username: username.trim(),
        password: password,
        deviceId: deviceId,
        deviceName: deviceNameProvider(),
        appVersion: appVersion,
      );
      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      _user = user;
      _savedUsername = user.username;
      _savedDisplayName = user.displayName;
      if (enableQuickUnlock) {
        await store.save(
          refreshToken: tokens.refreshToken,
          user: user,
          quickUnlockEnabled: true,
        );
        _quickUnlockAvailable = await deviceUnlock.isAvailable();
      } else {
        await store.clear();
        _quickUnlockAvailable = false;
      }
      _state = AppAuthState.signedIn;
    });
  }

  Future<bool> unlock() async {
    if (!_quickUnlockAvailable) {
      _message = 'Accesso rapido non disponibile. Usa la password.';
      notifyListeners();
      return false;
    }
    final authenticated = await deviceUnlock.authenticate();
    if (!authenticated) {
      _message = 'Sblocco annullato o non riuscito.';
      notifyListeners();
      return false;
    }
    return _run(() async {
      final refresh = await store.readRefreshToken();
      if (refresh == null) {
        await store.clear();
        _state = AppAuthState.signedOut;
        throw const AppAuthException(
          'missing_refresh',
          'Sessione salvata non disponibile. Accedi con la password.',
        );
      }
      final tokens = await api.refresh(
        refreshToken: refresh,
        deviceId: deviceId,
        appVersion: appVersion,
      );
      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      final username = await store.readUsername() ?? _savedUsername ?? '';
      final displayName =
          await store.readDisplayName() ?? _savedDisplayName ?? username;
      _user = AppAuthUser(
        username: username,
        displayName: displayName,
        role: '',
        roleLabel: '',
      );
      await store.save(
        refreshToken: tokens.refreshToken,
        user: _user!,
        quickUnlockEnabled: true,
      );
      _state = AppAuthState.signedIn;
    });
  }

  Future<bool> refreshAccessToken() async {
    final refresh = _refreshToken ?? await store.readRefreshToken();
    if (refresh == null) {
      _message = 'Sessione non disponibile. Accedi nuovamente con la password.';
      _state = AppAuthState.signedOut;
      notifyListeners();
      return false;
    }
    return _run(() async {
      final tokens = await api.refresh(
        refreshToken: refresh,
        deviceId: deviceId,
        appVersion: appVersion,
      );
      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      final quickEnabled = await store.readQuickUnlockEnabled();
      if (quickEnabled) {
        final user =
            _user ??
            AppAuthUser(
              username: await store.readUsername() ?? _savedUsername ?? '',
              displayName:
                  await store.readDisplayName() ?? _savedDisplayName ?? '',
              role: '',
              roleLabel: '',
            );
        await store.save(
          refreshToken: tokens.refreshToken,
          user: user,
          quickUnlockEnabled: true,
        );
      }
    });
  }

  Future<void> usePasswordInstead() async {
    _state = AppAuthState.signedOut;
    _message = null;
    notifyListeners();
  }

  Future<void> logout() async {
    final token = _accessToken;
    _busy = true;
    notifyListeners();
    try {
      if (token != null) {
        try {
          await api.logout(token);
        } catch (_) {
          // Il logout locale deve riuscire anche senza connettività.
        }
      }
      await store.clear();
    } finally {
      _accessToken = null;
      _refreshToken = null;
      _user = null;
      _savedUsername = null;
      _savedDisplayName = null;
      _quickUnlockAvailable = false;
      _message = null;
      _state = AppAuthState.signedOut;
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _run(Future<void> Function() operation) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on AppAuthException catch (error) {
      if (error.code == 'device_revoked' ||
          error.code == 'refresh_expired' ||
          error.code == 'session_invalid' ||
          error.code == 'invalid_refresh') {
        await store.clear();
        _quickUnlockAvailable = false;
        _state = AppAuthState.signedOut;
      }
      _message = error.message;
      return false;
    } on Exception {
      _message = 'Server GPS Pointer non raggiungibile.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
