import 'package:flutter/material.dart';

import 'workbench_visual_profile.dart';

/// RelGeo-specific visual tokens that do not belong in [ColorScheme].
///
/// The extension is intentionally derived from the existing visual profile for
/// now. This gives the workbench a stable theme-owned token boundary without
/// forcing the larger profile/painter migration into one change.
@immutable
class RelGeoThemeExtension extends ThemeExtension<RelGeoThemeExtension> {
  const RelGeoThemeExtension({
    required this.canvasBackgroundColor,
    required this.canvasOverlayColor,
    required this.gridMinorColor,
    required this.gridMajorColor,
    required this.accentColor,
    required this.accentSoftColor,
    required this.borderColor,
    required this.mutedColor,
    required this.canvasTextColor,
    required this.canvasMutedTextColor,
    required this.diagnosticColor,
    required this.diagnosticOverlayColor,
    required this.selectedColor,
    required this.errorColor,
    required this.errorSoftColor,
    required this.successColor,
    required this.warningColor,
    required this.disabledColor,
    required this.roleColors,
  });

  factory RelGeoThemeExtension.fromProfile(WorkbenchVisualProfile profile) {
    return RelGeoThemeExtension(
      canvasBackgroundColor: profile.viewportBackgroundColor,
      canvasOverlayColor: profile.overlayBackgroundColor,
      gridMinorColor: profile.gridMinorColor,
      gridMajorColor: profile.gridMajorColor,
      accentColor: profile.accentColor,
      accentSoftColor: profile.accentSoftColor,
      borderColor: profile.borderColor,
      mutedColor: profile.mutedColor,
      canvasTextColor: profile.roleColor('final'),
      canvasMutedTextColor: profile.mutedColor,
      diagnosticColor: profile.roleColor('centerline'),
      diagnosticOverlayColor: profile.overlayBackgroundColor.withValues(
        alpha: 0.85,
      ),
      selectedColor: profile.accentColor,
      errorColor:
          profile.canvasAppearance.roleColors['centerline'] ??
          const Color(0xFFEF4444),
      errorSoftColor:
          (profile.canvasAppearance.roleColors['centerline'] ??
                  const Color(0xFFEF4444))
              .withValues(alpha: 0.1),
      successColor:
          profile.canvasAppearance.roleColors['dimension'] ??
          const Color(0xFF10B981),
      warningColor:
          profile.canvasAppearance.roleColors['hidden'] ??
          const Color(0xFFF59E0B),
      disabledColor: profile.mutedColor,
      roleColors: Map.unmodifiable(profile.roleColors),
    );
  }

  final Color canvasBackgroundColor;
  final Color canvasOverlayColor;
  final Color gridMinorColor;
  final Color gridMajorColor;
  final Color accentColor;
  final Color accentSoftColor;
  final Color borderColor;
  final Color mutedColor;
  final Color canvasTextColor;
  final Color canvasMutedTextColor;
  final Color diagnosticColor;
  final Color diagnosticOverlayColor;
  final Color selectedColor;
  final Color errorColor;
  final Color errorSoftColor;
  final Color successColor;
  final Color warningColor;
  final Color disabledColor;
  final Map<String, Color> roleColors;

  Color roleColor(String role, {Color fallback = Colors.white}) {
    return roleColors[role] ?? fallback;
  }

  @override
  RelGeoThemeExtension copyWith({
    Color? canvasBackgroundColor,
    Color? canvasOverlayColor,
    Color? gridMinorColor,
    Color? gridMajorColor,
    Color? accentColor,
    Color? accentSoftColor,
    Color? borderColor,
    Color? mutedColor,
    Color? canvasTextColor,
    Color? canvasMutedTextColor,
    Color? diagnosticColor,
    Color? diagnosticOverlayColor,
    Color? selectedColor,
    Color? errorColor,
    Color? errorSoftColor,
    Color? successColor,
    Color? warningColor,
    Color? disabledColor,
    Map<String, Color>? roleColors,
  }) {
    return RelGeoThemeExtension(
      canvasBackgroundColor:
          canvasBackgroundColor ?? this.canvasBackgroundColor,
      canvasOverlayColor: canvasOverlayColor ?? this.canvasOverlayColor,
      gridMinorColor: gridMinorColor ?? this.gridMinorColor,
      gridMajorColor: gridMajorColor ?? this.gridMajorColor,
      accentColor: accentColor ?? this.accentColor,
      accentSoftColor: accentSoftColor ?? this.accentSoftColor,
      borderColor: borderColor ?? this.borderColor,
      mutedColor: mutedColor ?? this.mutedColor,
      canvasTextColor: canvasTextColor ?? this.canvasTextColor,
      canvasMutedTextColor: canvasMutedTextColor ?? this.canvasMutedTextColor,
      diagnosticColor: diagnosticColor ?? this.diagnosticColor,
      diagnosticOverlayColor:
          diagnosticOverlayColor ?? this.diagnosticOverlayColor,
      selectedColor: selectedColor ?? this.selectedColor,
      errorColor: errorColor ?? this.errorColor,
      errorSoftColor: errorSoftColor ?? this.errorSoftColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      disabledColor: disabledColor ?? this.disabledColor,
      roleColors: roleColors ?? this.roleColors,
    );
  }

  @override
  RelGeoThemeExtension lerp(covariant RelGeoThemeExtension? other, double t) {
    if (other == null) return this;
    return RelGeoThemeExtension(
      canvasBackgroundColor: Color.lerp(
        canvasBackgroundColor,
        other.canvasBackgroundColor,
        t,
      )!,
      canvasOverlayColor: Color.lerp(
        canvasOverlayColor,
        other.canvasOverlayColor,
        t,
      )!,
      gridMinorColor: Color.lerp(gridMinorColor, other.gridMinorColor, t)!,
      gridMajorColor: Color.lerp(gridMajorColor, other.gridMajorColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      accentSoftColor: Color.lerp(accentSoftColor, other.accentSoftColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      mutedColor: Color.lerp(mutedColor, other.mutedColor, t)!,
      canvasTextColor: Color.lerp(canvasTextColor, other.canvasTextColor, t)!,
      canvasMutedTextColor: Color.lerp(
        canvasMutedTextColor,
        other.canvasMutedTextColor,
        t,
      )!,
      diagnosticColor: Color.lerp(diagnosticColor, other.diagnosticColor, t)!,
      diagnosticOverlayColor: Color.lerp(
        diagnosticOverlayColor,
        other.diagnosticOverlayColor,
        t,
      )!,
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t)!,
      errorColor: Color.lerp(errorColor, other.errorColor, t)!,
      errorSoftColor: Color.lerp(errorSoftColor, other.errorSoftColor, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      disabledColor: Color.lerp(disabledColor, other.disabledColor, t)!,
      roleColors: t < 0.5 ? roleColors : other.roleColors,
    );
  }
}
