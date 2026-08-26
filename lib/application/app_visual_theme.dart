import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppVisualTheme {
  classic,
  radarPro;

  String get storageValue => name;

  String get label => switch (this) {
    AppVisualTheme.classic => 'Semplice',
    AppVisualTheme.radarPro => 'Pro',
  };

  String get description => switch (this) {
    AppVisualTheme.classic =>
      'Interfaccia essenziale, pulita e leggera. Tutte le funzioni operative '
          'restano disponibili con una grafica lineare.',
    AppVisualTheme.radarPro =>
      'Interfaccia completa con grafica tecnica, meteo e strumenti avanzati. '
          'Tema consigliato.',
  };

  static AppVisualTheme fromStorage(String? value) =>
      AppVisualTheme.values.firstWhere(
        (item) => item.storageValue == value?.trim(),
        orElse: () => AppVisualTheme.radarPro,
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
    AppVisualTheme initialTheme = AppVisualTheme.radarPro,
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
      _theme = AppVisualTheme.radarPro;
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
  const backgroundTop = Color(0xFF061722);
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
    borderRadius: BorderRadius.circular(10),
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
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    tabBarTheme: const TabBarThemeData(
      labelColor: cyan,
      unselectedLabelColor: muted,
      indicatorColor: cyanStrong,
      dividerColor: border,
      labelStyle: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .4),
    ),
    iconTheme: const IconThemeData(color: cyan),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xB80B1C28),
      hintStyle: const TextStyle(color: Color(0xFF7594A3)),
      labelStyle: const TextStyle(color: muted),
      prefixIconColor: cyan,
      suffixIconColor: cyan,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: cyanStrong, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cyanStrong,
        foregroundColor: const Color(0xFF031016),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cyan,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: cyan),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xA6132A38),
      selectedColor: const Color(0xFF164B5D),
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF0B1C28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
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
      dense: false,
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
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF061722), Color(0xFF031019), Color(0xFF020A11)],
              stops: [0, .48, 1],
            ),
          ),
        ),
        const IgnorePointer(
          child: CustomPaint(painter: _ProfessionalGridBackdropPainter()),
        ),
        child,
      ],
    );
  }
}

final class _ProfessionalGridBackdropPainter extends CustomPainter {
  const _ProfessionalGridBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5BD8EA).withValues(alpha: .018)
      ..strokeWidth = .7;

    const step = 54.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

final class VisualThemeSelectorCard extends StatelessWidget {
  const VisualThemeSelectorCard({required this.controller, super.key});

  final AppVisualThemeController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ThemeOption(
        mode: AppVisualTheme.classic,
        selected: controller.theme == AppVisualTheme.classic,
        busy: controller.busy,
        onTap: () => controller.setTheme(AppVisualTheme.classic),
      ),
      const Divider(height: 1, indent: 52),
      _ThemeOption(
        mode: AppVisualTheme.radarPro,
        selected: controller.theme == AppVisualTheme.radarPro,
        busy: controller.busy,
        onTap: () => controller.setTheme(AppVisualTheme.radarPro),
      ),
    ],
  );
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
    final selectedColor = radar
        ? const Color(0xFF57D3EC)
        : Theme.of(context).colorScheme.primary;

    return ListTile(
      dense: true,
      enabled: !busy,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      leading: Icon(
        radar ? Icons.radar : Icons.explore_outlined,
        size: 23,
        color: selected ? selectedColor : null,
      ),
      title: Text(
        mode.label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected ? selectedColor : const Color(0xFF617D89),
        size: 22,
      ),
      onTap: busy ? null : onTap,
    );
  }
}
