import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppVisualTheme {
  classic,
  radarPro;

  String get storageValue => name;

  String get label => switch (this) {
    AppVisualTheme.classic => 'Classico',
    AppVisualTheme.radarPro => 'Radar Pro',
  };

  String get description => switch (this) {
    AppVisualTheme.classic =>
      'Tema storico GPS Pointer con Fry, sobrio e operativo.',
    AppVisualTheme.radarPro =>
      'Interfaccia completamente Radar Pro: niente Fry, navy, cyan, ambra e pannelli strumentali.',
  };

  static AppVisualTheme fromStorage(String? value) =>
      AppVisualTheme.values.firstWhere(
        (item) => item.storageValue == value?.trim(),
        orElse: () => AppVisualTheme.classic,
      );
}

abstract interface class LauncherIconBridge {
  Future<void> apply(AppVisualTheme theme);
}

final class AndroidLauncherIconBridge implements LauncherIconBridge {
  const AndroidLauncherIconBridge();

  static const MethodChannel _channel = MethodChannel(
    'io.github.fraidotube.gpspointer/launcher_icon',
  );

  @override
  Future<void> apply(AppVisualTheme theme) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setLauncherIcon', {
        'theme': theme.storageValue,
      });
    } on MissingPluginException {
      // Non bloccare l'app se il canale nativo non è disponibile.
    } on PlatformException {
      // Il tema interno deve restare utilizzabile anche se il launcher
      // ritarda o rifiuta temporaneamente il cambio icona.
    }
  }
}

final class AppVisualThemeController extends ChangeNotifier {
  AppVisualThemeController({
    required this._storageFile,
    this._launcherIconBridge = const AndroidLauncherIconBridge(),
    AppVisualTheme initialTheme = AppVisualTheme.classic,
  }) : _theme = initialTheme;

  final File _storageFile;
  final LauncherIconBridge _launcherIconBridge;
  AppVisualTheme _theme;
  bool _busy = false;

  AppVisualTheme get theme => _theme;
  bool get busy => _busy;
  bool get isRadarPro => _theme == AppVisualTheme.radarPro;

  Future<void> initialize() async {
    try {
      if (await _storageFile.exists()) {
        _theme = AppVisualTheme.fromStorage(await _storageFile.readAsString());
      }
    } on FileSystemException {
      _theme = AppVisualTheme.classic;
    }
    notifyListeners();
  }

  Future<void> setTheme(AppVisualTheme theme) async {
    if (_busy || theme == _theme) return;
    _busy = true;
    notifyListeners();
    try {
      await _storageFile.parent.create(recursive: true);
      await _storageFile.writeAsString(theme.storageValue, flush: true);
      _theme = theme;
      notifyListeners();
      await _launcherIconBridge.apply(theme);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

@immutable
final class GpsVisualStyle extends ThemeExtension<GpsVisualStyle> {
  const GpsVisualStyle({
    required this.radarPro,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.panel,
    required this.panelStrong,
    required this.border,
    required this.cyan,
    required this.amber,
    required this.muted,
  });

  final bool radarPro;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color panel;
  final Color panelStrong;
  final Color border;
  final Color cyan;
  final Color amber;
  final Color muted;

  @override
  GpsVisualStyle copyWith({
    bool? radarPro,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? panel,
    Color? panelStrong,
    Color? border,
    Color? cyan,
    Color? amber,
    Color? muted,
  }) => GpsVisualStyle(
    radarPro: radarPro ?? this.radarPro,
    backgroundTop: backgroundTop ?? this.backgroundTop,
    backgroundBottom: backgroundBottom ?? this.backgroundBottom,
    panel: panel ?? this.panel,
    panelStrong: panelStrong ?? this.panelStrong,
    border: border ?? this.border,
    cyan: cyan ?? this.cyan,
    amber: amber ?? this.amber,
    muted: muted ?? this.muted,
  );

  @override
  GpsVisualStyle lerp(covariant GpsVisualStyle? other, double t) {
    if (other == null) return this;
    return GpsVisualStyle(
      radarPro: t < .5 ? radarPro : other.radarPro,
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(
        backgroundBottom,
        other.backgroundBottom,
        t,
      )!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelStrong: Color.lerp(panelStrong, other.panelStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

ThemeData gpsPointerTheme(AppVisualTheme mode) {
  if (mode == AppVisualTheme.classic) {
    const cyan = Color(0xFF19A7C4);
    const background = Color(0xFF07131C);
    const panel = Color(0xFF10232E);
    const border = Color(0xFF254653);
    const muted = Color(0xFF9FB6C2);

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cyan,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: const CardThemeData(
        color: panel,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0C1D27),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
      ),
      useMaterial3: true,
      extensions: const [
        GpsVisualStyle(
          radarPro: false,
          backgroundTop: background,
          backgroundBottom: background,
          panel: panel,
          panelStrong: Color(0xFF132A36),
          border: border,
          cyan: cyan,
          amber: Color(0xFFFFA026),
          muted: muted,
        ),
      ],
    );
  }

  const background = Color(0xFF020A11);
  const backgroundTop = Color(0xFF07354D);
  const panel = Color(0xE80B2231);
  const panelStrong = Color(0xFF123A50);
  const border = Color(0xFF2E6D89);
  const cyan = Color(0xFF85E9F7);
  const cyanStrong = Color(0xFF22C8E7);
  const amber = Color(0xFFFFA026);
  const muted = Color(0xFFA5C1CE);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: cyanStrong,
        brightness: Brightness.dark,
      ).copyWith(
        primary: cyan,
        secondary: amber,
        surface: panel,
        surfaceContainer: panel,
        surfaceContainerHigh: panelStrong,
        outline: border,
      );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
    side: const BorderSide(color: border),
  );

  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    useMaterial3: true,
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: rounded,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xF5071723),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: .15,
      ),
    ),
    dividerColor: border,
    iconTheme: const IconThemeData(color: cyan),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xB80B1C28),
      hintStyle: const TextStyle(color: Color(0xFF7594A3)),
      labelStyle: const TextStyle(color: muted),
      prefixIconColor: cyan,
      suffixIconColor: cyan,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: cyanStrong, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cyanStrong,
        foregroundColor: const Color(0xFF031016),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cyan,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: cyan),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xA6132A38),
      selectedColor: const Color(0xFF164B5D),
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF0B1C28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: border),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF17303D),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF061722),
      indicatorColor: Color(0xFF174F64),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: cyan)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: cyan,
      textColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: cyan,
        backgroundColor: const Color(0x9E0A2432),
        side: const BorderSide(color: border),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xFF0A1D29),
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: Colors.white),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF081B27),
      modalBackgroundColor: Color(0xFF081B27),
      surfaceTintColor: Colors.transparent,
    ),
    extensions: const [
      GpsVisualStyle(
        radarPro: true,
        backgroundTop: backgroundTop,
        backgroundBottom: background,
        panel: panel,
        panelStrong: panelStrong,
        border: border,
        cyan: cyan,
        amber: amber,
        muted: muted,
      ),
    ],
  );
}

final class GpsThemeBackground extends StatelessWidget {
  const GpsThemeBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<GpsVisualStyle>();
    if (style == null || !style.radarPro) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [style.backgroundTop, style.backgroundBottom],
              stops: const [0, .72],
            ),
          ),
        ),
        const IgnorePointer(
          child: CustomPaint(painter: _TopographicBackdropPainter()),
        ),
        child,
      ],
    );
  }
}

final class _TopographicBackdropPainter extends CustomPainter {
  const _TopographicBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF64D4EA).withValues(alpha: .055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var line = 0; line < 11; line++) {
      final path = Path();
      final baseY = size.height * (.06 + line * .095);
      path.moveTo(-20, baseY);
      for (double x = -20; x <= size.width + 20; x += 28) {
        final normalized = x / (size.width == 0 ? 1 : size.width);
        final y =
            baseY +
            9 * _pseudoWave(normalized * 7.0 + line * .61) +
            4 * _pseudoWave(normalized * 15.0 + line * .23);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  double _pseudoWave(double value) =>
      (value % 2.0 <= 1.0 ? value % 1.0 : 1.0 - value % 1.0) * 2 - 1;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

final class VisualThemeSelectorCard extends StatelessWidget {
  const VisualThemeSelectorCard({required this.controller, super.key});

  final AppVisualThemeController controller;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<GpsVisualStyle>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  color: style?.cyan ?? Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Tema grafico',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Puoi cambiare l’aspetto dell’app senza modificare dati, '
              'account o simulazioni. Su Android cambia anche l’icona launcher.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final mode in AppVisualTheme.values) ...[
              _ThemeOption(
                mode: mode,
                selected: controller.theme == mode,
                busy: controller.busy,
                onTap: () => controller.setTheme(mode),
              ),
              if (mode != AppVisualTheme.values.last)
                const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final AppVisualTheme mode;
  final bool selected;
  final bool busy;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final radar = mode == AppVisualTheme.radarPro;
    final border = selected
        ? (radar
              ? const Color(0xFF57D3EC)
              : Theme.of(context).colorScheme.primary)
        : const Color(0xFF294452);

    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: selected ? 1.6 : 1),
          gradient: radar
              ? const LinearGradient(
                  colors: [Color(0xFF123448), Color(0xFF081722)],
                )
              : null,
          color: radar ? null : const Color(0xFF10232E),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: radar
                    ? const Color(0xFF0A2131)
                    : const Color(0xFF0B1B24),
                border: Border.all(
                  color: radar
                      ? const Color(0xFF2A7186)
                      : const Color(0xFF294452),
                ),
              ),
              child: Icon(
                radar ? Icons.radar : Icons.explore_outlined,
                color: radar
                    ? const Color(0xFFFFA026)
                    : const Color(0xFF19A7C4),
                size: 31,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? border : const Color(0xFF617D89),
            ),
          ],
        ),
      ),
    );
  }
}
