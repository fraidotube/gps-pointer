import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/app_visual_theme.dart';
import '../application/device_location_service.dart';
import '../application/weather_service.dart';
import 'home_weather_strip.dart';

final class MainHubScreen extends StatelessWidget {
  const MainHubScreen({
    required this.visualThemeController,
    required this.onPostazioni,
    required this.onCopertura,
    required this.onPtp,
    required this.onRapporti,
    required this.onDownload,
    required this.onSettings,
    required this.onDebug,
    required this.onWeatherRadar,
    required this.onComida,
    required this.onUpdates,
    this.locationService,
    this.weatherService,
    super.key,
  });

  final AppVisualThemeController visualThemeController;
  final VoidCallback onPostazioni;
  final VoidCallback onCopertura;
  final VoidCallback onPtp;
  final VoidCallback onRapporti;
  final VoidCallback onDownload;
  final VoidCallback onSettings;
  final VoidCallback onDebug;
  final VoidCallback onWeatherRadar;
  final VoidCallback onComida;
  final VoidCallback onUpdates;
  final DeviceLocationService? locationService;
  final WeatherService? weatherService;

  @override
  Widget build(BuildContext context) => visualThemeController.isRadarPro
      ? _RadarProHome(
          onPostazioni: onPostazioni,
          onCopertura: onCopertura,
          onPtp: onPtp,
          onRapporti: onRapporti,
          onDownload: onDownload,
          onSettings: onSettings,
          onDebug: onDebug,
          onWeatherRadar: onWeatherRadar,
          onComida: onComida,
          onUpdates: onUpdates,
          locationService: locationService,
          weatherService: weatherService,
        )
      : _ClassicHome(
          onPostazioni: onPostazioni,
          onCopertura: onCopertura,
          onPtp: onPtp,
          onRapporti: onRapporti,
          onDownload: onDownload,
          onSettings: onSettings,
          onDebug: onDebug,
          onWeatherRadar: onWeatherRadar,
          onComida: onComida,
          onUpdates: onUpdates,
          locationService: locationService,
          weatherService: weatherService,
        );
}

final class _RadarProHome extends StatelessWidget {
  const _RadarProHome({
    required this.onPostazioni,
    required this.onCopertura,
    required this.onPtp,
    required this.onRapporti,
    required this.onDownload,
    required this.onSettings,
    required this.onDebug,
    required this.onWeatherRadar,
    required this.onComida,
    required this.onUpdates,
    required this.locationService,
    required this.weatherService,
  });

  final VoidCallback onPostazioni;
  final VoidCallback onCopertura;
  final VoidCallback onPtp;
  final VoidCallback onRapporti;
  final VoidCallback onDownload;
  final VoidCallback onSettings;
  final VoidCallback onDebug;
  final VoidCallback onWeatherRadar;
  final VoidCallback onComida;
  final VoidCallback onUpdates;
  final DeviceLocationService? locationService;
  final WeatherService? weatherService;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final compact = mq.size.height < 720;
    final gap = compact ? 8.0 : 10.0;
    final tileHeight = compact ? 105.0 : 116.0;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _RadarMockupBackdrop(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, 12),
              child: Column(
                children: [
                  _RadarHeader(onMenu: () => _showQuickMenu(context)),
                  if (locationService != null && weatherService != null) ...[
                    const SizedBox(height: 8),
                    HomeWeatherStrip(
                      locationService: locationService!,
                      weatherService: weatherService!,
                    ),
                  ],
                  SizedBox(height: compact ? 10 : 14),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: gap,
                            mainAxisSpacing: gap,
                            childAspectRatio: mq.size.width / 2 / tileHeight,
                            children: [
                              _RadarTile(
                                icon: Icons.cell_tower,
                                title: 'Postazioni Radio',
                                subtitle: 'Catalogo e servizi',
                                onTap: onPostazioni,
                              ),
                              _RadarTile(
                                icon: Icons.radar,
                                title: 'Copertura',
                                subtitle: 'Profilo e link',
                                onTap: onCopertura,
                              ),
                              _RadarTile(
                                icon: Icons.swap_horiz_rounded,
                                title: 'Punto Punto',
                                subtitle: 'Collegamento PTP',
                                onTap: onPtp,
                              ),
                              _RadarTile(
                                icon: Icons.dynamic_feed_outlined,
                                title: 'News & Video',
                                subtitle: '',
                                onTap: onUpdates,
                              ),
                              _RadarTile(
                                icon: Icons.restaurant_menu,
                                assetIcon: 'asset/comida_button.png',
                                title: 'Comida',
                                subtitle: 'Locali vicino a te',
                                onTap: onComida,
                              ),
                            ],
                          ),
                          SizedBox(height: gap),
                          _RadarWeatherTile(onTap: onWeatherRadar),
                          SizedBox(height: gap),
                          _RadarReportsTile(onTap: onRapporti),
                          SizedBox(height: gap),
                          _RadarSettingsTile(onTap: onSettings),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickMenu(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _menuItem(
                    sheetContext,
                    icon: Icons.cell_tower,
                    title: 'Postazioni Radio',
                    action: onPostazioni,
                  ),
                  _menuItem(
                    sheetContext,
                    icon: Icons.radar,
                    title: 'Copertura',
                    action: onCopertura,
                  ),
                  _menuItem(
                    sheetContext,
                    icon: Icons.swap_horiz_rounded,
                    title: 'Punto Punto',
                    action: onPtp,
                  ),
                  _menuItem(
                    sheetContext,
                    icon: Icons.radar_outlined,
                    title: 'Radar meteo',
                    action: onWeatherRadar,
                  ),
                  _menuItem(
                    sheetContext,
                    icon: Icons.restaurant_menu,
                    title: 'Comida',
                    action: onComida,
                  ),
                  _menuItem(
                    sheetContext,
                    icon: Icons.dynamic_feed_outlined,
                    title: 'News & Video',
                    action: onUpdates,
                  ),
                  _menuItem(
                    sheetContext,
                    icon: Icons.assignment_outlined,
                    title: 'Rapporto d’intervento',
                    action: onRapporti,
                  ),
                  const Divider(),
                  _menuItem(
                    sheetContext,
                    icon: Icons.settings_outlined,
                    title: 'Impostazioni',
                    action: onSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Disclaimer'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showDisclaimer(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback action,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: () {
      Navigator.pop(context);
      action();
    },
  );

  Future<void> _showDisclaimer(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Disclaimer GPS Pointer'),
      content: const SingleChildScrollView(
        child: Text(
          'GPS Pointer è uno strumento di supporto al puntamento e alla '
          'valutazione tecnica sul campo. Le indicazioni di copertura, LOS, '
          'Fresnel, quote, meteo, azimut e orientamento dipendono dai dati '
          'disponibili, dai modelli esterni e dalla qualità dei sensori del '
          'dispositivo. Prima dell’installazione definitiva è sempre '
          'necessaria la verifica tecnica sul posto.\n\n'
          'Dati meteo e quote online: Open-Meteo.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

final class _RadarHeader extends StatelessWidget {
  const _RadarHeader({required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: Row(
      children: [
        IconButton(
          tooltip: 'Menu',
          onPressed: onMenu,
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFFE9F7FB),
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
          ),
          icon: const Icon(Icons.menu_rounded, size: 25),
        ),
        const SizedBox(width: 3),
        const _MiniCompassMark(),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GPS Pointer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .1,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Puntamento e copertura radio',
                style: TextStyle(
                  color: Color(0xFFA7BDCA),
                  fontSize: 10.5,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 6),
          child: Icon(
            Icons.sensors_outlined,
            color: Color(0xFF38C7E3),
            size: 21,
          ),
        ),
      ],
    ),
  );
}

final class _MiniCompassMark extends StatelessWidget {
  const _MiniCompassMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 28,
    child: CustomPaint(painter: _MiniCompassPainter()),
  );
}

final class _MiniCompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFFEAF7FA);
    canvas.drawCircle(center, size.width * .38, ring);
    final arrow = Path()
      ..moveTo(size.width * .24, size.height * .72)
      ..lineTo(size.width * .73, size.height * .23)
      ..lineTo(size.width * .62, size.height * .59)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFFFFA026));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

final class _RadarTile extends StatelessWidget {
  const _RadarTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.assetIcon,
  });

  final IconData icon;
  final String? assetIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xEB173243), Color(0xE90D2432)],
          ),
          border: Border.all(color: const Color(0x243FC2DD)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x37000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (assetIcon != null)
                SizedBox(
                  width: 92,
                  height: 42,
                  child: Image.asset(assetIcon!, fit: BoxFit.contain),
                )
              else
                Icon(icon, color: const Color(0xFFF5FAFC), size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB2C6D0),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

final class _RadarWeatherTile extends StatelessWidget {
  const _RadarWeatherTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xEE0B3544), Color(0xEE0A2635)],
          ),
          border: Border.all(color: const Color(0x8843CFE8)),
        ),
        child: const Row(
          children: [
            Icon(Icons.radar_outlined, color: Color(0xFF79E2F3), size: 30),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Radar meteo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Pioggia radar • punto corrente • previsioni',
                    style: TextStyle(color: Color(0xFFB7CBD4), fontSize: 10),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFF79E2F3)),
          ],
        ),
      ),
    ),
  );
}

final class _RadarReportsTile extends StatelessWidget {
  const _RadarReportsTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xEE122A47), Color(0xEE173C63)],
          ),
          border: Border.all(color: const Color(0x553E8BD8)),
        ),
        child: const Row(
          children: [
            Icon(Icons.assignment_outlined, color: Colors.white, size: 30),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rapporto d’intervento',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Modulo Connesi • firme touch • PDF',
                    style: TextStyle(color: Color(0xFFBCD0E6), fontSize: 10),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFFBCD0E6)),
          ],
        ),
      ),
    ),
  );
}

final class _RadarSettingsTile extends StatelessWidget {
  const _RadarSettingsTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                colors: [Color(0xE0373441), Color(0xE51F2936)],
              ),
              border: Border.all(color: const Color(0x32FFB266)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.settings_outlined,
                  color: Color(0xFFF2F7F9),
                  size: 26,
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Impostazioni',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Preferenze e account',
                      style: TextStyle(color: Color(0xFFCCBAC0), fontSize: 9.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _RadarMockupBackdrop extends StatelessWidget {
  const _RadarMockupBackdrop();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Color(0xFF03131E)),
      Positioned.fill(
        top: -4,
        bottom: -4,
        child: ClipRect(
          child: Transform(
            alignment: Alignment.centerRight,
            transform: Matrix4.diagonal3Values(1.065, 1, 1),
            child: Image.asset(
              'asset/pro_home_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xF003131E),
              Color(0xD9071925),
              Color(0x69071925),
              Color(0x08000000),
            ],
            stops: [0, .44, .72, 1],
          ),
        ),
      ),
      const CustomPaint(painter: _RadarTopoOverlayPainter()),
    ],
  );
}

final class _RadarTopoOverlayPainter extends CustomPainter {
  const _RadarTopoOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = const Color(0xFF66D8EA).withValues(alpha: .055);
    for (var i = 0; i < 10; i++) {
      final path = Path();
      final y0 = size.height * (.04 + i * .052);
      path.moveTo(-20, y0);
      for (double x = -20; x <= size.width + 20; x += 18) {
        path.lineTo(
          x,
          y0 +
              math.sin(x / 46 + i * .73) * 4 +
              math.sin(x / 22 + i * 1.4) * 1.6,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

final class _ClassicHome extends StatelessWidget {
  const _ClassicHome({
    required this.onPostazioni,
    required this.onCopertura,
    required this.onPtp,
    required this.onRapporti,
    required this.onDownload,
    required this.onSettings,
    required this.onDebug,
    required this.onWeatherRadar,
    required this.onComida,
    required this.onUpdates,
    required this.locationService,
    required this.weatherService,
  });

  final VoidCallback onPostazioni;
  final VoidCallback onCopertura;
  final VoidCallback onPtp;
  final VoidCallback onRapporti;
  final VoidCallback onDownload;
  final VoidCallback onSettings;
  final VoidCallback onDebug;
  final VoidCallback onWeatherRadar;
  final VoidCallback onComida;
  final VoidCallback onUpdates;
  final DeviceLocationService? locationService;
  final WeatherService? weatherService;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tileWidth = (width - 44) / 2;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Menu',
                  onPressed: () => _showQuickMenu(context),
                  icon: const Icon(Icons.menu_rounded),
                ),
                const SizedBox(width: 4),
                Image.asset(
                  'asset/fry_pointer.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPS Pointer',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text('Strumenti per installatori'),
                    ],
                  ),
                ),
              ],
            ),
            if (locationService != null && weatherService != null) ...[
              const SizedBox(height: 10),
              HomeWeatherStrip(
                locationService: locationService!,
                weatherService: weatherService!,
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ClassicButton(
                  width: tileWidth,
                  icon: Icons.cell_tower,
                  title: 'Postazioni Radio',
                  subtitle: 'Catalogo e puntamento',
                  onTap: onPostazioni,
                ),
                _ClassicButton(
                  width: tileWidth,
                  icon: Icons.radar,
                  title: 'Copertura',
                  subtitle: 'Profilo e link',
                  onTap: onCopertura,
                ),
                _ClassicButton(
                  width: tileWidth,
                  icon: Icons.swap_horiz_rounded,
                  title: 'Punto Punto',
                  subtitle: 'Collegamento PTP',
                  onTap: onPtp,
                ),
                _ClassicButton(
                  width: tileWidth,
                  icon: Icons.dynamic_feed_outlined,
                  title: 'News & Video',
                  subtitle: '',
                  onTap: onUpdates,
                ),
                _ClassicButton(
                  width: tileWidth,
                  icon: Icons.restaurant_menu,
                  assetIcon: 'asset/comida_button.png',
                  title: 'Comida',
                  subtitle: 'Locali vicino a te',
                  onTap: onComida,
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onWeatherRadar,
              icon: const Icon(Icons.radar_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text(
                  'RADAR METEO',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF122A47),
                foregroundColor: Colors.white,
              ),
              onPressed: onRapporti,
              icon: const Icon(Icons.assignment_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'RAPPORTO D’INTERVENTO',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'IMPOSTAZIONI',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickMenu(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _classicMenuItem(
                  sheetContext,
                  icon: Icons.cell_tower,
                  title: 'Postazioni Radio',
                  action: onPostazioni,
                ),
                _classicMenuItem(
                  sheetContext,
                  icon: Icons.radar,
                  title: 'Copertura',
                  action: onCopertura,
                ),
                _classicMenuItem(
                  sheetContext,
                  icon: Icons.swap_horiz_rounded,
                  title: 'Punto Punto',
                  action: onPtp,
                ),
                _classicMenuItem(
                  sheetContext,
                  icon: Icons.radar_outlined,
                  title: 'Radar meteo',
                  action: onWeatherRadar,
                ),
                _classicMenuItem(
                  sheetContext,
                  icon: Icons.restaurant_menu,
                  title: 'Comida',
                  action: onComida,
                ),
                _classicMenuItem(
                  sheetContext,
                  icon: Icons.dynamic_feed_outlined,
                  title: 'News & Video',
                  action: onUpdates,
                ),
                _classicMenuItem(
                  sheetContext,
                  icon: Icons.assignment_outlined,
                  title: 'Rapporto d’intervento',
                  action: onRapporti,
                ),
                const Divider(),
                _classicMenuItem(
                  sheetContext,
                  icon: Icons.settings_outlined,
                  title: 'Impostazioni',
                  action: onSettings,
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Disclaimer'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showDisclaimer(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );

  Widget _classicMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback action,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: () {
      Navigator.pop(context);
      action();
    },
  );

  Future<void> _showDisclaimer(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Disclaimer GPS Pointer'),
      content: const SingleChildScrollView(
        child: Text(
          'GPS Pointer è uno strumento di supporto al puntamento e alla '
          'valutazione tecnica sul campo. Le indicazioni di copertura, LOS, '
          'Fresnel, quote, meteo e direzione dipendono dai dati disponibili, '
          'dalla precisione dei sensori e dai modelli utilizzati. '
          'Verificare sempre sul posto le condizioni reali prima '
          'dell’installazione. Le informazioni meteo e radar sono servizi '
          'informativi di terze parti e possono non essere disponibili.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

final class _ClassicButton extends StatelessWidget {
  const _ClassicButton({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.assetIcon,
  });

  final double width;
  final IconData icon;
  final String? assetIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 142,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (assetIcon != null)
                SizedBox(
                  width: 104,
                  height: 48,
                  child: Image.asset(assetIcon!, fit: BoxFit.contain),
                )
              else
                Icon(icon, size: 36),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
