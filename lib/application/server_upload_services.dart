import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/intervention_report.dart';
import '../core/simulation/radio_link_simulation.dart';
import 'app_auth.dart';
import 'simulation_exchange_codec.dart';

final class ServerUploadException implements Exception {
  const ServerUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class GpsPointerServerUploadService {
  GpsPointerServerUploadService({
    required this.client,
    required this.authController,
    required this.baseUri,
    required this.deviceId,
    required this.deviceName,
  });

  final http.Client client;
  final AppAuthController authController;
  final Uri baseUri;
  final String deviceId;
  final String deviceName;

  Uri _uri(String path) =>
      baseUri.replace(path: path, query: null, fragment: null);

  Future<int> uploadSimulation(RadioLinkSimulation simulation) async {
    final payload = SimulationExchangeCodec.encode(
      simulation: simulation,
      deviceId: deviceId,
      deviceName: deviceName,
    );
    Future<http.Response> send(String token) => client
        .post(
          _uri('/api/v1/simulations'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type':
                'application/vnd.gpspointer.simulation+json; charset=utf-8',
          },
          body: utf8.encode(payload),
        )
        .timeout(const Duration(seconds: 45));

    var token = await _validToken();
    var response = await send(token);
    if (response.statusCode == 401 &&
        await authController.refreshAccessToken()) {
      token = authController.accessToken ?? '';
      response = await send(token);
    }
    final json = _decodeResponse(response);
    final id = json['simulation_id'];
    if (id is! num) {
      throw const ServerUploadException(
        'Risposta server simulazione non valida.',
      );
    }
    return id.toInt();
  }

  Future<void> uploadInterventionReport({
    required InterventionReport report,
    required File pdfFile,
  }) async {
    Future<http.StreamedResponse> send(String token) async {
      final request = http.MultipartRequest(
        'POST',
        _uri('/api/v1/intervention-reports'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['metadata'] = jsonEncode(report.toServerMetadata());
      request.files.add(
        await http.MultipartFile.fromPath(
          'pdf_file',
          pdfFile.path,
          filename: '${report.id}.pdf',
        ),
      );
      return client.send(request).timeout(const Duration(seconds: 45));
    }

    var token = await _validToken();
    var streamed = await send(token);
    var response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 &&
        await authController.refreshAccessToken()) {
      token = authController.accessToken ?? '';
      streamed = await send(token);
      response = await http.Response.fromStream(streamed);
    }
    _decodeResponse(response);
  }

  Future<String> _validToken() async {
    final token = authController.accessToken;
    if (token != null && token.isNotEmpty) return token;
    if (await authController.refreshAccessToken()) {
      final refreshed = authController.accessToken;
      if (refreshed != null && refreshed.isNotEmpty) return refreshed;
    }
    throw const ServerUploadException(
      'Sessione server non disponibile. Accedi nuovamente.',
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      body = null;
    }
    if (response.statusCode >= 400 || body?['ok'] != true) {
      throw ServerUploadException(
        body?['message']?.toString() ??
            'Server GPS Pointer: errore HTTP ${response.statusCode}.',
      );
    }
    return body!;
  }
}
