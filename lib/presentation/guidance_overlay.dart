import 'dart:math' as math;

import 'package:flutter/material.dart';

enum GuidanceIllustration {
  horizontal,
  antennaTilt,
  augmentedReality,
  figureEight,
}

final class GuidanceOverlay extends StatelessWidget {
  const GuidanceOverlay({
    required this.title,
    required this.steps,
    required this.illustration,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String title;
  final List<String> steps;
  final GuidanceIllustration illustration;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xF207131C),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    CustomPaint(
                      size: const Size(260, 150),
                      painter: _GuidancePainter(
                        illustration: illustration,
                        colors: Theme.of(context).colorScheme,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final step in steps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(step)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAction,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(actionLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _GuidancePainter extends CustomPainter {
  const _GuidancePainter({required this.illustration, required this.colors});

  final GuidanceIllustration illustration;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    switch (illustration) {
      case GuidanceIllustration.horizontal:
        _horizontal(canvas, size);
        break;
      case GuidanceIllustration.antennaTilt:
        _antenna(canvas, size);
        break;
      case GuidanceIllustration.augmentedReality:
        _ar(canvas, size);
        break;
      case GuidanceIllustration.figureEight:
        _figureEight(canvas, size);
        break;
    }
  }

  Paint _stroke([Color? color, double width = 4]) => Paint()
    ..color = color ?? colors.primary
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _horizontal(Canvas canvas, Size size) {
    final groundY = size.height * 0.75;
    canvas.drawLine(
      Offset(18, groundY),
      Offset(size.width - 18, groundY),
      _stroke(colors.outline, 3),
    );
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, groundY - 28),
        width: 145,
        height: 42,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(phone, _stroke());
    canvas.drawCircle(
      Offset(size.width / 2, groundY - 28),
      5,
      Paint()..color = colors.primary,
    );
    _arrow(canvas, Offset(size.width / 2, 18), Offset(size.width / 2, 55));
  }

  void _antenna(Canvas canvas, Size size) {
    final poleX = size.width * 0.73;
    canvas.drawLine(
      Offset(poleX, 24),
      Offset(poleX, size.height - 12),
      _stroke(colors.outline, 5),
    );
    final antenna = Path()
      ..moveTo(poleX - 8, 35)
      ..quadraticBezierTo(poleX - 68, 70, poleX - 10, 108);
    canvas.drawPath(antenna, _stroke(colors.secondary, 8));
    canvas.save();
    canvas.translate(poleX - 72, 73);
    canvas.rotate(-8 * math.pi / 180);
    final phone = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-18, -48, 36, 96),
      const Radius.circular(7),
    );
    canvas.drawRRect(phone, _stroke());
    canvas.drawCircle(const Offset(0, 35), 3, Paint()..color = colors.primary);
    canvas.restore();
    _arrow(canvas, Offset(35, 105), Offset(72, 63));
  }

  void _ar(Canvas canvas, Size size) {
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 82,
        height: 132,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(phone, _stroke());
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 16, _stroke(colors.secondary, 3));
    canvas.drawLine(
      center - const Offset(27, 0),
      center - const Offset(16, 0),
      _stroke(),
    );
    canvas.drawLine(
      center + const Offset(16, 0),
      center + const Offset(27, 0),
      _stroke(),
    );
    canvas.drawLine(
      center - const Offset(0, 27),
      center - const Offset(0, 16),
      _stroke(),
    );
    canvas.drawLine(
      center + const Offset(0, 16),
      center + const Offset(0, 27),
      _stroke(),
    );
  }

  void _figureEight(Canvas canvas, Size size) {
    final path = Path();
    for (var index = 0; index <= 120; index++) {
      final t = index / 120 * math.pi * 2;
      final denominator = 1 + math.sin(t) * math.sin(t);
      final x = math.cos(t) / denominator;
      final y = math.sin(t) * math.cos(t) / denominator;
      final point = Offset(
        size.width / 2 + x * size.width * 0.35,
        size.height / 2 + y * size.height * 0.7,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, _stroke(colors.primary, 6));
  }

  void _arrow(Canvas canvas, Offset from, Offset to) {
    final paint = _stroke(colors.secondary, 4);
    canvas.drawLine(from, to, paint);
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    for (final offset in const [-0.6, 0.6]) {
      canvas.drawLine(
        to,
        Offset(
          to.dx - math.cos(angle + offset) * 13,
          to.dy - math.sin(angle + offset) * 13,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GuidancePainter oldDelegate) =>
      oldDelegate.illustration != illustration || oldDelegate.colors != colors;
}
