import 'package:flutter/material.dart';

import 'relgeo_theme_extension.dart';
import 'workbench_visual_profile.dart';

const _relGeoAccent = Color(0xFF00A88F);
const _relGeoDarkAccent = Color(0xFF33D6B8);

ThemeData buildRelGeoLightTheme() {
  return _buildRelGeoTheme(
    ColorScheme.fromSeed(
      seedColor: _relGeoAccent,
      brightness: Brightness.light,
    ),
    WorkbenchVisualProfile.paper,
  );
}

ThemeData buildRelGeoDarkTheme() {
  return _buildRelGeoTheme(
    ColorScheme.fromSeed(
      seedColor: _relGeoDarkAccent,
      brightness: Brightness.dark,
    ),
    WorkbenchVisualProfile.cadDark,
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
