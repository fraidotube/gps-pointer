import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_visual_theme.dart';

const Duration kLaunchSplashMinimumDuration = Duration(milliseconds: 4200);

final class LaunchSplashGate extends StatefulWidget {
  const LaunchSplashGate({required this.child, required this.theme, super.key});

  final Widget child;
  final AppVisualTheme theme;

  @override
  State<LaunchSplashGate> createState() => _LaunchSplashGateState();
}

final class _LaunchSplashGateState extends State<LaunchSplashGate> {
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF04111A),
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF04111A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // SAFE: il tempo parte DOPO il primo frame realmente disegnato.
    // In questo modo i 4,2 s sono tempo VISIBILE, non tempo consumato
    // durante l'inizializzazione precedente a runApp().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(kLaunchSplashMinimumDuration, () {
        if (!mounted) return;
        setState(() => _finished = true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF04111A),
        useMaterial3: true,
      ),
      home: LaunchSplashView(theme: widget.theme),
    );
  }
}

final class LaunchSplashView extends StatefulWidget {
  const LaunchSplashView({required this.theme, super.key});

  final AppVisualTheme theme;

  @override
  State<LaunchSplashView> createState() => _LaunchSplashViewState();
}

final class _LaunchSplashViewState extends State<LaunchSplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.theme == AppVisualTheme.radarPro
      ? _RadarProSplash(
          key: const ValueKey('launch-splash-radarPro'),
          animation: _animation,
        )
      : _ClassicSplash(
          key: const ValueKey('launch-splash-classic'),
          animation: _animation,
        );
}

final class _RadarProSplash extends StatelessWidget {
  const _RadarProSplash({required this.animation, super.key});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF04111A),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const _MockupBackground(stronger: true),
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) => CustomPaint(
            painter: _RadarSweepPainter(progress: animation.value),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) => Transform.rotate(
                    angle: animation.value * math.pi * 2,
                    child: const _GpsPointerMark(size: 152),
                  ),
                ),
                const SizedBox(height: 26),
                const _GradientBrandTitle(),
                const SizedBox(height: 9),
                const Text(
                  'P U N T A  ·  M I S U R A  ·  C O N N E T T I',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF80DBED),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.15,
                  ),
                ),
                const SizedBox(height: 34),
                const _InstrumentPanel(),
                const Spacer(flex: 3),
                const _LoadingStrip(
                  label: 'INIZIALIZZAZIONE STRUMENTI',
                  accent: Color(0xFFFFA026),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

final class _ClassicSplash extends StatelessWidget {
  const _ClassicSplash({required this.animation, super.key});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF07131C),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const _MockupBackground(stronger: false),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 224,
                  height: 224,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: const Color(0xFF28647E),
                      width: 1.4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4421BEDA),
                        blurRadius: 32,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(48),
                    child: Image.asset(
                      'asset/fry_app.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'GPS Pointer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'APP PUNTAMENTO GPS',
                  style: TextStyle(
                    color: Color(0xFF76D6EA),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.1,
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) => Transform.rotate(
                    angle: animation.value * math.pi * 2,
                    child: const _GpsPointerMark(size: 66),
                  ),
                ),
                const Spacer(flex: 3),
                const _LoadingStrip(
                  label: 'CARICAMENTO GPS POINTER',
                  accent: Color(0xFF22C8E7),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

final class _MockupBackground extends StatelessWidget {
  const _MockupBackground({required this.stronger});

  final bool stronger;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: stronger
                ? const [
                    Color(0xFF06354E),
                    Color(0xFF071A28),
                    Color(0xFF020A11),
                  ]
                : const [
                    Color(0xFF0A2C3E),
                    Color(0xFF071722),
                    Color(0xFF041018),
                  ],
            stops: const [0, .58, 1],
          ),
        ),
      ),
      CustomPaint(painter: _TopoPainter(opacity: stronger ? .15 : .09)),
    ],
  );
}

final class _GradientBrandTitle extends StatelessWidget {
  const _GradientBrandTitle();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.white, Color(0xFF9EEBFF)],
        ).createShader(bounds),
        child: const Text(
          'GPS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 54,
            height: .9,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 2,
          ),
        ),
      ),
      const Text(
        'Pointer',
        style: TextStyle(
          color: Color(0xFF48D5F2),
          fontSize: 36,
          height: 1,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          letterSpacing: 1.5,
        ),
      ),
    ],
  );
}

final class _InstrumentPanel extends StatelessWidget {
  const _InstrumentPanel();

  @override
  Widget build(BuildContext context) => Container(
    width: 280,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xB80B2231),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF2A6C88)),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _InstrumentItem(icon: Icons.explore, label: 'AZIMUT'),
        _InstrumentItem(icon: Icons.network_check, label: 'LINK'),
        _InstrumentItem(icon: Icons.view_in_ar, label: 'AR'),
      ],
    ),
  );
}

final class _InstrumentItem extends StatelessWidget {
  const _InstrumentItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Color(0xFF7EE6F6), size: 24),
      SizedBox(height: 5),
      Text(
        label,
        style: TextStyle(
          color: Color(0xFFA7C7D4),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
        ),
      ),
    ],
  );
}

final class _GpsPointerMark extends StatelessWidget {
  const _GpsPointerMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: const _GpsPointerMarkPainter()),
  );
}

final class _GpsPointerMarkPainter extends CustomPainter {
  const _GpsPointerMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .36;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .045
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE8FBFF);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -.25,
      math.pi * 1.58,
      false,
      ring,
    );

    final cyan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .025
      ..color = const Color(0xFF29CDEA);
    canvas.drawCircle(c, radius * .72, cyan);

    final arrow = Path()
      ..moveTo(c.dx + radius * .90, c.dy - radius * .85)
      ..lineTo(c.dx + radius * .15, c.dy + radius * .08)
      ..lineTo(c.dx - radius * .05, c.dy + radius * .55)
      ..lineTo(c.dx - radius * .22, c.dy + radius * .13)
      ..lineTo(c.dx - radius * .62, c.dy + radius * .23)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFA026),
    );

    final north = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: const Color(0xFFA9ECF8),
          fontSize: size.width * .12,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    north.paint(
      canvas,
      Offset(c.dx - north.width / 2, c.dy - radius - north.height * 1.2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

final class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFA1C0CD),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          width: 220,
          height: 5,
          child: LinearProgressIndicator(
            backgroundColor: const Color(0xFF16313F),
            color: accent,
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'durata minima 4,2 s',
        style: TextStyle(
          color: Color(0xFF678795),
          fontSize: 9,
          letterSpacing: .3,
        ),
      ),
    ],
  );
}

final class _TopoPainter extends CustomPainter {
  const _TopoPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF62D7ED).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 11; i++) {
      final y = size.height * (.07 + i * .09);
      final path = Path()..moveTo(-24, y);
      for (double x = -24; x <= size.width + 24; x += 28) {
        final wave = math.sin((x / size.width * math.pi * 3.8) + i * .67);
        path.lineTo(x, y + wave * (8 + i * .35));
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopoPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

final class _RadarSweepPainter extends CustomPainter {
  const _RadarSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .50, size.height * .41);
    final radius = math.min(size.width, size.height) * .33;

    final ringPaint = Paint()
      ..color = const Color(0xFF28CDE9).withValues(alpha: .09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(center, radius * i / 5, ringPaint);
    }

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: const [Color(0x001AC5E3), Color(0x551AC5E3), Color(0x001AC5E3)],
        stops: const [0, .12, .30],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
