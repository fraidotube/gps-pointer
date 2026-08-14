import 'package:flutter/foundation.dart';

import '../core/core.dart';
import 'device_location_service.dart';
import 'device_orientation_service.dart';

final class PointingController extends ChangeNotifier {
  factory PointingController({
    required DeviceLocationService locationService,
    required TerrainElevationProvider elevationProvider,
    required DeviceOrientationService orientationService,
    int positionSampleCount = 3,
  }) => PointingController._(
    locationService,
    elevationProvider,
    orientationService,
    positionSampleCount,
  );

  PointingController._(
    this._locationService,
    this._elevationProvider,
    this._orientationService,
    this._positionSampleCount,
  ) : assert(_positionSampleCount > 0);

  final DeviceLocationService _locationService;
  final TerrainElevationProvider _elevationProvider;
  final DeviceOrientationService _orientationService;
  final int _positionSampleCount;

  DeviceLocationReading? _location;
  double? _terrainElevationMeters;
  double _observerHeightMeters = 0;
  PointingCalculation? _solution;
  bool _busy = false;
  String? _errorMessage;
  String? _orientationWarning;
  String _busyMessage = 'Preparo il puntamento…';
  bool? _hasMagnetometer;
  double _declinationDegrees = 0;
  int _positionSamplesUsed = 0;

  DeviceLocationReading? get location => _location;
  double? get terrainElevationMeters => _terrainElevationMeters;
  double get observerHeightMeters => _observerHeightMeters;
  double? get observerElevationMeters => _terrainElevationMeters == null
      ? null
      : _terrainElevationMeters! + _observerHeightMeters;
  PointingCalculation? get solution => _solution;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;
  String? get orientationWarning => _orientationWarning;
  String get busyMessage => _busyMessage;
  bool? get hasMagnetometer => _hasMagnetometer;
  double get declinationDegrees => _declinationDegrees;
  int get positionSamplesUsed => _positionSamplesUsed;
  bool get hasLockedPosition => _location != null;

  Future<void> prepare({
    required RadioBeacon beacon,
    required double observerHeightMeters,
    bool refreshPosition = false,
  }) async {
    if (!observerHeightMeters.isFinite || observerHeightMeters < 0) {
      _errorMessage = 'Altezza dal terreno non valida.';
      notifyListeners();
      return;
    }
    final antennaElevation = beacon.antennaElevationMeters;
    if (antennaElevation == null) {
      _errorMessage = 'La quota dell’antenna non è disponibile.';
      notifyListeners();
      return;
    }
    _busy = true;
    _errorMessage = null;
    _orientationWarning = null;
    _busyMessage = _location == null || refreshPosition
        ? 'Stabilizzo la posizione GPS…'
        : 'Uso la posizione osservatore bloccata…';
    notifyListeners();
    try {
      final acquirePosition = _location == null || refreshPosition;
      final reading = acquirePosition ? await _readBestPosition() : _location!;
      final position = GeoPoint.validated(
        latitude: reading.latitude,
        longitude: reading.longitude,
      );
      final terrain = acquirePosition || _terrainElevationMeters == null
          ? await _readTerrainElevation(position)
          : _terrainElevationMeters!;
      _location = reading;
      _terrainElevationMeters = terrain;
      if (acquirePosition || _hasMagnetometer == null) {
        await _readOrientationInfo(reading);
      }
      _observerHeightMeters = observerHeightMeters;
      _solution = GeoCalculator.pointing(
        origin: position,
        originElevationMeters: terrain + observerHeightMeters,
        destination: beacon.position,
        destinationElevationMeters: antennaElevation,
      );
    } on DeviceLocationException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Puntamento non preparato: $error';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<DeviceLocationReading> _readBestPosition() async {
    DeviceLocationReading? best;
    _positionSamplesUsed = 0;
    for (var index = 0; index < _positionSampleCount; index++) {
      _busyMessage =
          'Stabilizzo la posizione GPS '
          '(${index + 1}/$_positionSampleCount)…';
      notifyListeners();
      final candidate = await _locationService.readCurrentPosition();
      _positionSamplesUsed++;
      if (best == null || _accuracy(candidate) < _accuracy(best)) {
        best = candidate;
      }
    }
    return best!;
  }

  Future<double> _readTerrainElevation(GeoPoint position) async {
    _busyMessage = 'Acquisisco la quota terreno Open-Meteo…';
    notifyListeners();
    return _elevationProvider.getTerrainElevationMeters(position);
  }

  Future<void> _readOrientationInfo(DeviceLocationReading reading) async {
    _busyMessage = 'Controllo bussola e nord geografico…';
    notifyListeners();
    try {
      final info = await _orientationService.readInfo(reading);
      _hasMagnetometer = info.hasMagnetometer;
      _declinationDegrees = info.declinationDegrees;
    } on DeviceOrientationException catch (error) {
      _hasMagnetometer = null;
      _declinationDegrees = 0;
      _orientationWarning = error.message;
    }
  }

  static double _accuracy(DeviceLocationReading reading) {
    final accuracy = reading.horizontalAccuracyMeters;
    return accuracy.isFinite && accuracy >= 0 ? accuracy : double.infinity;
  }
}
