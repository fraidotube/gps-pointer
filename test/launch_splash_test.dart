import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pointer/application/app_visual_theme.dart';
import 'package:gps_pointer/presentation/launch_splash.dart';

void main() {
  testWidgets('Radar Pro splash remains visible for at least 4.2 seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const LaunchSplashGate(
        theme: AppVisualTheme.radarPro,
        child: MaterialApp(home: Text('HOME-RADAR')),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('launch-splash-radarPro')),
      findsOneWidget,
    );
    expect(find.text('HOME-RADAR'), findsNothing);

    await tester.pump(const Duration(milliseconds: 4100));
    expect(
      find.byKey(const ValueKey('launch-splash-radarPro')),
      findsOneWidget,
    );
    expect(find.text('HOME-RADAR'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('HOME-RADAR'), findsOneWidget);
  });

  testWidgets('Classic splash also remains visible for at least 4.2 seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const LaunchSplashGate(
        theme: AppVisualTheme.classic,
        child: MaterialApp(home: Text('HOME-CLASSIC')),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('launch-splash-classic')), findsOneWidget);
    expect(find.text('HOME-CLASSIC'), findsNothing);

    await tester.pump(const Duration(milliseconds: 4100));
    expect(find.byKey(const ValueKey('launch-splash-classic')), findsOneWidget);
    expect(find.text('HOME-CLASSIC'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('HOME-CLASSIC'), findsOneWidget);
  });
}
