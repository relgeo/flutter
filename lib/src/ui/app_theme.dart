import 'package:flutter/material.dart';

import 'relgeo_theme_extension.dart';
import 'workbench_visual_profile.dart';

ThemeData buildRelGeoLightTheme({
  WorkbenchVisualProfile profile = WorkbenchVisualProfile.cad,
}) {
  final brightnessProfile = profile.forBrightness(Brightness.light);
  return _buildRelGeoTheme(
    ColorScheme.fromSeed(
      seedColor: brightnessProfile.accentColor,
      brightness: Brightness.light,
    ),
    brightnessProfile,
  );
}

ThemeData buildRelGeoDarkTheme({
  WorkbenchVisualProfile profile = WorkbenchVisualProfile.cad,
}) {
  final brightnessProfile = profile.forBrightness(Brightness.dark);
  return _buildRelGeoTheme(
    ColorScheme.fromSeed(
      seedColor: brightnessProfile.accentColor,
      brightness: Brightness.dark,
    ),
    brightnessProfile,
  );
}

ThemeData _buildRelGeoTheme(
  ColorScheme colorScheme,
  WorkbenchVisualProfile canvasProfile,
) {
  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);

  return base.copyWith(
    visualDensity: VisualDensity.compact,
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    ),
    popupMenuTheme: PopupMenuThemeData(color: colorScheme.surfaceContainer),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: TextStyle(color: colorScheme.onInverseSurface),
    ),
    extensions: <ThemeExtension<dynamic>>[
      RelGeoThemeExtension.fromProfile(canvasProfile),
    ],
  );
}
