import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

final class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class AppUpdateInfo {
  const AppUpdateInfo({
    required this.release,
    required this.versionName,
    required this.build,
    required this.apkName,
    required this.apkUri,
    required this.sha256,
  });

  final String release;
  final String versionName;
  final int build;
  final String apkName;
  final Uri apkUri;
  final String sha256;
}

final class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.localVersion,
    required this.localBuild,
    this.update,
  });

  final String localVersion;
  final int localBuild;
  final AppUpdateInfo? update;

  bool get updateAvailable => update != null;
}

final class AppUpdateService {
  AppUpdateService({required this.client});

  static final Uri _latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/fraidotube/gps-pointer/releases/latest',
  );
  static const String _manifestAssetName = 'gps-pointer-release.json';

  final http.Client client;

  Future<AppUpdateCheckResult> check() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final localBuild = int.tryParse(packageInfo.buildNumber);
    if (localBuild == null) {
      throw const AppUpdateException(
        'Build locale non leggibile. Aggiornamento non verificabile.',
      );
    }

    final releaseResponse = await client
        .get(
          _latestReleaseUri,
          headers: const <String, String>{
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'GPS-Pointer-Android',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (releaseResponse.statusCode != 200) {
      throw AppUpdateException(
        'Controllo aggiornamenti non riuscito '
        '(GitHub HTTP ${releaseResponse.statusCode}).',
      );
    }

    final releaseJson = _decodeJsonObject(
      releaseResponse.body,
      'release GitHub',
    );
    final assets = releaseJson['assets'];
    if (assets is! List) {
      throw const AppUpdateException(
        'Release GitHub senza elenco asset valido.',
      );
    }

    Map<String, dynamic>? manifestAsset;
    for (final asset in assets) {
      if (asset is Map && asset['name'] == _manifestAssetName) {
        manifestAsset = Map<String, dynamic>.from(asset);
        break;
      }
    }
    if (manifestAsset == null) {
      throw const AppUpdateException(
        'Release GitHub senza gps-pointer-release.json.',
      );
    }

    final manifestUrl = _requiredUri(
      manifestAsset['browser_download_url'],
      'URL manifest',
    );
    final manifestResponse = await client
        .get(manifestUrl)
        .timeout(const Duration(seconds: 15));
    if (manifestResponse.statusCode != 200) {
      throw AppUpdateException(
        'Manifest aggiornamento non scaricato '
        '(HTTP ${manifestResponse.statusCode}).',
      );
    }

    final manifest = _decodeJsonObject(
      manifestResponse.body,
      'gps-pointer-release.json',
    );
    final schema = manifest['schema'];
    final product = manifest['product'];
    if (schema != 1 || product != 'GPS Pointer') {
      throw const AppUpdateException('Manifest aggiornamento non compatibile.');
    }

    final release = _requiredString(manifest['release'], 'release');
    final versionName = _requiredString(manifest['versionName'], 'versionName');
    final remoteBuild = _requiredInt(manifest['build'], 'build');
    final apkName = _requiredString(manifest['apk'], 'apk');
    final expectedSha256 = _requiredSha256(manifest['sha256']);

    Map<String, dynamic>? apkAsset;
    for (final asset in assets) {
      if (asset is Map && asset['name'] == apkName) {
        apkAsset = Map<String, dynamic>.from(asset);
        break;
      }
    }
    if (apkAsset == null) {
      throw AppUpdateException(
        'APK dichiarato nel manifest non trovato: $apkName',
      );
    }

    if (remoteBuild <= localBuild) {
      return AppUpdateCheckResult(
        localVersion: packageInfo.version,
        localBuild: localBuild,
      );
    }

    return AppUpdateCheckResult(
      localVersion: packageInfo.version,
      localBuild: localBuild,
      update: AppUpdateInfo(
        release: release,
        versionName: versionName,
        build: remoteBuild,
        apkName: apkName,
        apkUri: _requiredUri(apkAsset['browser_download_url'], 'URL APK'),
        sha256: expectedSha256,
      ),
    );
  }

  Future<File> downloadAndVerify(AppUpdateInfo update) async {
    final tempDirectory = await getTemporaryDirectory();
    final updateDirectory = Directory(
      '${tempDirectory.path}${Platform.pathSeparator}gps_pointer_updates',
    );
    await updateDirectory.create(recursive: true);

    final safeFileName = update.apkName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final file = File(
      '${updateDirectory.path}${Platform.pathSeparator}$safeFileName',
    );
    if (await file.exists()) {
      await file.delete();
    }

    final request = http.Request('GET', update.apkUri);
    request.headers.addAll(const <String, String>{
      'Accept': 'application/octet-stream',
      'User-Agent': 'GPS-Pointer-Android',
    });
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw AppUpdateException(
        'Download APK non riuscito (HTTP ${response.statusCode}).',
      );
    }

    final sink = file.openWrite();
    try {
      await response.stream.timeout(const Duration(minutes: 5)).pipe(sink);
    } on Object {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }

    final actualSha256 = (await sha256.bind(file.openRead()).first).toString();
    if (actualSha256.toLowerCase() != update.sha256.toLowerCase()) {
      await file.delete();
      throw const AppUpdateException(
        'SHA256 APK non valido. Installazione bloccata.',
      );
    }
    return file;
  }

  static Map<String, dynamic> _decodeJsonObject(String source, String label) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // handled below
    }
    throw AppUpdateException('$label non contiene JSON valido.');
  }

  static String _requiredString(Object? value, String field) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw AppUpdateException('Campo $field mancante nel manifest.');
  }

  static int _requiredInt(Object? value, String field) {
    if (value is int && value > 0) return value;
    throw AppUpdateException('Campo $field non valido nel manifest.');
  }

  static Uri _requiredUri(Object? value, String field) {
    if (value is String) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.isScheme('https')) return uri;
    }
    throw AppUpdateException('$field non valido.');
  }

  static String _requiredSha256(Object? value) {
    if (value is String && RegExp(r'^[A-Fa-f0-9]{64}$').hasMatch(value)) {
      return value.toLowerCase();
    }
    throw const AppUpdateException('SHA256 non valido nel manifest.');
  }
}
