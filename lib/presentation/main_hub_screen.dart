import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/app_visual_theme.dart';

final class MainHubScreen extends StatelessWidget {
  const MainHubScreen({
    required this.visualThemeController,
    required this.onPostazioni,
    required this.onCopertura,
    required this.onPtp,
    required this.onDownload,
    required this.onAdd,
    required this.onSettings,
    required this.onDebug,
    super.key,
  });

  final AppVisualThemeController visualThemeController;
  final VoidCallback onPostazioni;
  final VoidCallback onCopertura;
  final VoidCallback onPtp;
  final VoidCallback onDownload;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  final VoidCallback onDebug;

  @override
  Widget build(BuildContext context) => visualThemeController.isRadarPro
      ? _RadarProHome(
          onPostazioni: onPostazioni,
          onCopertura: onCopertura,
          onPtp: onPtp,
          onDownload: onDownload,
          onAdd: onAdd,
          onSettings: onSettings,
          onDebug: onDebug,
        )
      : _ClassicHome(
          onPostazioni: onPostazioni,
          onCopertura: onCopertura,
          onPtp: onPtp,
          onDownload: onDownload,
          onAdd: onAdd,
          onSettings: onSettings,
          onDebug: onDebug,
        );
}

final class _RadarProHome extends StatelessWidget {
  const _RadarProHome({
    required this.onPostazioni,
    required this.onCopertura,
    required this.onPtp,
    required this.onDownload,
    required this.onAdd,
    required this.onSettings,
    required this.onDebug,
  });

  final VoidCallback onPostazioni;
  final VoidCallback onCopertura;
  final VoidCallback onPtp;
  final VoidCallback onDownload;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  final VoidCallback onDebug;

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
                  SizedBox(height: compact ? 14 : 20),
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
                                icon: Icons.cloud_download_outlined,
                                title: 'Scarica',
                                subtitle: 'Postazioni dal server',
                                onTap: onDownload,
                              ),
                              _RadarTile(
                                icon: Icons.add_location_alt_outlined,
                                title: 'Aggiungi',
                                subtitle: 'Nuova postazione',
                                onTap: onAdd,
                              ),
                              _RadarTile(
                                icon: Icons.bug_report_outlined,
                                title: 'Debug',
                                subtitle: 'Log e diagnostica',
                                onTap: onDebug,
                              ),
                            ],
                          ),
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
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.cell_tower),
                  title: const Text('Postazioni Radio'),
                  onTap: () {
                    Navigator.pop(context);
                    onPostazioni();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Impostazioni'),
                  onTap: () {
                    Navigator.pop(context);
                    onSettings();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Debug'),
                  onTap: () {
                    Navigator.pop(context);
                    onDebug();
                  },
                ),
              ],
            ),
          ),
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
  });

  final IconData icon;
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
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB2C6D0), fontSize: 9.5),
              ),
            ],
          ),
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
        child: Image.asset(
          'asset/pro_home_background.png',
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.high,
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
    required this.onDownload,
    required this.onAdd,
    required this.onSettings,
    required this.onDebug,
  });

  final VoidCallback onPostazioni;
  final VoidCallback onCopertura;
  final VoidCallback onPtp;
  final VoidCallback onDownload;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  final VoidCallback onDebug;

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
                  icon: Icons.cloud_download_outlined,
                  title: 'Scarica',
                  subtitle: 'Postazioni dal server',
                  onTap: onDownload,
                ),
                _ClassicButton(
                  width: tileWidth,
                  icon: Icons.add_location_alt_outlined,
                  title: 'Aggiungi',
                  subtitle: 'Nuova postazione',
                  onTap: onAdd,
                ),
                _ClassicButton(
                  width: tileWidth,
                  icon: Icons.bug_report_outlined,
                  title: 'Debug',
                  subtitle: 'Log e diagnostica',
                  onTap: onDebug,
                ),
              ],
            ),
            const SizedBox(height: 14),
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
}

final class _ClassicButton extends StatelessWidget {
  const _ClassicButton({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double width;
  final IconData icon;
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
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
