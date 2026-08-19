import 'package:flutter/material.dart';

import '../application/device_location_service.dart';
import '../application/weather_service.dart';
import '../core/domain/geo_point.dart';

final class HomeWeatherStrip extends StatefulWidget {
  const HomeWeatherStrip({
    required this.locationService,
    required this.weatherService,
    super.key,
  });

  final DeviceLocationService locationService;
  final WeatherService weatherService;

  @override
  State<HomeWeatherStrip> createState() => _HomeWeatherStripState();
}

final class _HomeWeatherStripState extends State<HomeWeatherStrip> {
  WeatherSnapshot? _weather;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final reading = await widget.locationService.readCurrentPosition();
      final weather = await widget.weatherService.current(
        GeoPoint.validated(
          latitude: reading.latitude,
          longitude: reading.longitude,
        ),
      );
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : _load,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xC90A2230),
            border: Border.all(color: const Color(0x4438C7E3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_outlined,
                color: Color(0xFF79E2F3),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _loading
                    ? const Text(
                        'Meteo posizione corrente...',
                        style: TextStyle(color: Color(0xFFA7BDCA)),
                      )
                    : weather == null
                    ? const Text(
                        'Meteo non disponibile',
                        style: TextStyle(color: Color(0xFFA7BDCA)),
                      )
                    : Text(
                        '${weather.temperatureCelsius.toStringAsFixed(0)}°C · '
                        '${weather.description} · '
                        'vento ${weather.windSpeedKmh.toStringAsFixed(0)} km/h',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              Icon(
                _loading ? Icons.hourglass_top : Icons.refresh,
                color: const Color(0xFF79E2F3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
