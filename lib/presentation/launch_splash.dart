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
    backgroundColor: const Color(0xFF03131E),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          top: -6,
          bottom: -6,
          child: ClipRect(
            child: Transform(
              alignment: Alignment.centerRight,
              transform: Matrix4.diagonal3Values(1.065, 1, 1),
              child: Image.asset(
                'asset/pro_splash_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
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
                Color(0x7703131E),
                Color(0x1103131E),
                Color(0x22000000),
                Color(0x88000000),
              ],
              stops: [0, .38, .68, 1],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 760;
              return Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
                child: Column(
                  children: [
                    SizedBox(height: compact ? 10 : 28),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - value)),
                          child: Transform.scale(
                            scale: .94 + (.06 * value),
                            child: child,
                          ),
                        ),
                      ),
                      child: const _ProSplashWordmark(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'PUNTA. MISURA. CONNETTI.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                      ),
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => Opacity(
                        opacity:
                            .72 +
                            .28 *
                                ((math.sin(animation.value * math.pi * 2) + 1) /
                                    2),
                        child: child,
                      ),
                      child: const _LoadingStrip(
                        label: 'Caricamento dati...',
                        accent: Color(0xFFFFA026),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

final class _ProSplashWordmark extends StatelessWidget {
  const _ProSplashWordmark();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(
        width: 128,
        height: 128,
        child: CustomPaint(painter: _ProCompassLogoPainter()),
      ),
      const SizedBox(height: 6),
      const Text(
        'GPS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 45,
          height: .92,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
        ),
      ),
      const SizedBox(height: 2),
      const Text(
        'P O I N T E R',
        style: TextStyle(
          color: Color(0xFFFFA026),
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 4.1,
          shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
        ),
      ),
    ],
  );
}

final class _ProCompassLogoPainter extends CustomPainter {
  const _ProCompassLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .36;

    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .045
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        (-math.pi / 4) + i * math.pi / 2,
        math.pi / 2 - .34,
        false,
        ring,
      );
    }

    final whiteNeedle = Path()
      ..moveTo(size.width * .23, size.height * .79)
      ..lineTo(size.width * .50, size.height * .48)
      ..lineTo(size.width * .44, size.height * .63)
      ..close();
    canvas.drawPath(whiteNeedle, Paint()..color = Colors.white);

    final orangeNeedle = Path()
      ..moveTo(size.width * .45, size.height * .55)
      ..lineTo(size.width * .82, size.height * .18)
      ..lineTo(size.width * .61, size.height * .61)
      ..close();
    canvas.drawPath(orangeNeedle, Paint()..color = const Color(0xFFFFA026));

    canvas.drawCircle(
      center,
      size.shortestSide * .055,
      Paint()..color = const Color(0xFF071A26),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
