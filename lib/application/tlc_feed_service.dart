import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_auth.dart';

final class TlcFeedItem {
  const TlcFeedItem({
    required this.id,
    required this.kind,
    required this.source,
    required this.title,
    required this.summary,
    required this.url,
    this.publishedAt,
    this.imageUrl,
    this.channel,
  });

  final String id;
  final String kind;
  final String source;
  final String title;
  final String summary;
  final String url;
  final DateTime? publishedAt;
  final String? imageUrl;
  final String? channel;

  factory TlcFeedItem.fromJson(Map<String, dynamic> json) => TlcFeedItem(
    id: json['id'] as String? ?? '',
    kind: json['kind'] as String? ?? 'news',
    source: json['source'] as String? ?? '',
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    url: json['url'] as String? ?? '',
    publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    imageUrl: json['image_url'] as String?,
    channel: json['channel'] as String?,
  );
}

final class TlcFeedResult {
  const TlcFeedResult({
    required this.news,
    required this.videos,
    required this.warnings,
  });

  final List<TlcFeedItem> news;
  final List<TlcFeedItem> videos;
  final List<String> warnings;
}

final class TlcFeedException implements Exception {
  const TlcFeedException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class TlcFeedService {
  TlcFeedService({
    required this.serverBaseUri,
    required this.authController,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri serverBaseUri;
  final AppAuthController authController;
  final http.Client _client;

  Future<TlcFeedResult> fetch() async {
    var token = authController.accessToken;
    if (token == null || token.isEmpty) {
      final refreshed = await authController.refreshAccessToken();
      if (!refreshed) {
        throw const TlcFeedException('Sessione GPS Pointer non disponibile.');
      }
      token = authController.accessToken;
    }

    var response = await _get(token!);
    if (response.statusCode == 401) {
      final refreshed = await authController.refreshAccessToken();
      if (!refreshed || authController.accessToken == null) {
        throw const TlcFeedException('Sessione scaduta. Accedi nuovamente.');
      }
      response = await _get(authController.accessToken!);
    }

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      payload = decoded;
    } on FormatException {
      throw const TlcFeedException('Risposta non valida dal server.');
    }

    if (response.statusCode != 200 || payload['ok'] != true) {
      throw TlcFeedException(
        payload['message'] as String? ??
            'Aggiornamenti TLC temporaneamente non disponibili.',
      );
    }

    List<TlcFeedItem> parseItems(String key) {
      final raw = payload[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(TlcFeedItem.fromJson)
          .where((item) => item.title.isNotEmpty && item.url.isNotEmpty)
          .toList(growable: false);
    }

    final warnings = (payload['warnings'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);

    return TlcFeedResult(
      news: parseItems('news'),
      videos: parseItems('videos'),
      warnings: warnings,
    );
  }

  Future<http.Response> _get(String token) => _client
      .get(
        serverBaseUri.resolve('/api/v1/tlc/feed'),
        headers: {'Authorization': 'Bearer $token'},
      )
      .timeout(const Duration(seconds: 20));

  void dispose() => _client.close();
}
