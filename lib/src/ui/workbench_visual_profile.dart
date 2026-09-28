import 'package:flutter/material.dart';

class WorkbenchBehaviorPreset {
  final bool showAnchors;
  final bool showLabels;
  final bool showBoundingBoxes;
  final Set<String> hiddenRoles;
  final double baseGridWorldStep;

  const WorkbenchBehaviorPreset({
    this.showAnchors = false,
    this.showLabels = false,
    this.showBoundingBoxes = false,
    this.hiddenRoles = const {'construction'},
    this.baseGridWorldStep = 20.0,
  });
}

/// Appearance tokens for the technical drawing surface.
///
/// Keeping this model separate from [WorkbenchBehaviorPreset] lets a profile
/// combine the same canvas look with a different interaction preset later,
/// without making theme or painter code depend on behavior flags.
@immutable
class WorkbenchCanvasAppearance {
  final Color viewportBackgroundColor;
  final Color toolbarBackgroundColor;
  final Color overlayBackgroundColor;
  final Color gridMinorColor;
  final Color gridMajorColor;
  final Color accentColor;
  final Color accentSoftColor;
  final Color borderColor;
  final Color mutedColor;
  final Map<String, Color> roleColors;

  const WorkbenchCanvasAppearance({
    required this.viewportBackgroundColor,
    required this.toolbarBackgroundColor,
    required this.overlayBackgroundColor,
    required this.gridMinorColor,
    required this.gridMajorColor,
    required this.accentColor,
    required this.accentSoftColor,
    required this.borderColor,
    required this.mutedColor,
    required this.roleColors,
  });

  Color roleColor(String role) => roleColors[role] ?? Colors.white;
}

class WorkbenchVisualProfile {
  final String id;
  final String label;
  final WorkbenchCanvasAppearance canvasAppearance;
  final WorkbenchBehaviorPreset behavior;

  const WorkbenchVisualProfile({
    required this.id,
    required this.label,
    required this.canvasAppearance,
    required this.behavior,
  });

  // Legacy getters keep existing callers source-compatible while migration
  // moves ownership to [canvasAppearance].
  Color get viewportBackgroundColor => canvasAppearance.viewportBackgroundColor;
  Color get toolbarBackgroundColor => canvasAppearance.toolbarBackgroundColor;
  Color get overlayBackgroundColor => canvasAppearance.overlayBackgroundColor;
  Color get gridMinorColor => canvasAppearance.gridMinorColor;
  Color get gridMajorColor => canvasAppearance.gridMajorColor;
  Color get accentColor => canvasAppearance.accentColor;
  Color get accentSoftColor => canvasAppearance.accentSoftColor;
  Color get borderColor => canvasAppearance.borderColor;
  Color get mutedColor => canvasAppearance.mutedColor;
  Map<String, Color> get roleColors => canvasAppearance.roleColors;

  Color roleColor(String role) => canvasAppearance.roleColor(role);

  static const cad = WorkbenchVisualProfile(
    id: 'cad',
    label: 'CAD',
    canvasAppearance: WorkbenchCanvasAppearance(
      viewportBackgroundColor: Color(0xFF0A0F1D),
      toolbarBackgroundColor: Color(0xFF0F172A),
      overlayBackgroundColor: Color(0xFF0A0F1D),
      gridMinorColor: Color(0xFF1E293B),
      gridMajorColor: Color(0xFF334155),
      accentColor: Color(0xFF00FFCC),
      accentSoftColor: Color(0x1A00FFCC),
      borderColor: Color(0xFF1E293B),
      mutedColor: Color(0xFF64748B),
      roleColors: {
        'final': Color(0xFF00FFCC),
        'construction': Color(0x6694A3B8),
        'guide': Color(0xFFE2E8F0),
        'centerline': Color(0xFFF43F5E),
        'hidden': Color(0xFFF59E0B),
        'section': Color(0xFFEC4899),
        'cut': Color(0xFFEC4899),
        'fold': Color(0xFF3B82F6),
        'dimension': Color(0xFF10B981),
        'annotation': Color(0xFF10B981),
      },
    ),
    behavior: WorkbenchBehaviorPreset(
      showAnchors: false,
      showLabels: false,
      showBoundingBoxes: false,
      hiddenRoles: {'construction'},
      baseGridWorldStep: 20.0,
    ),
  );

  static const blueprint = WorkbenchVisualProfile(
    id: 'blueprint',
    label: 'Blueprint',
    canvasAppearance: WorkbenchCanvasAppearance(
      viewportBackgroundColor: Color(0xFF071A2E),
      toolbarBackgroundColor: Color(0xFF0B2744),
      overlayBackgroundColor: Color(0xFF0A223A),
      gridMinorColor: Color(0xFF214A73),
      gridMajorColor: Color(0xFF3A6C9A),
      accentColor: Color(0xFF93C5FD),
      accentSoftColor: Color(0x1A93C5FD),
      borderColor: Color(0xFF234766),
      mutedColor: Color(0xFF8FB3D9),
      roleColors: {
        'final': Color(0xFFE0F2FE),
        'construction': Color(0x668FB3D9),
        'guide': Color(0xFFBAE6FD),
        'centerline': Color(0xFFFDE68A),
        'hidden': Color(0xFFFFD166),
        'section': Color(0xFFF9A8D4),
        'cut': Color(0xFFF9A8D4),
        'fold': Color(0xFFA5B4FC),
        'dimension': Color(0xFF86EFAC),
        'annotation': Color(0xFF86EFAC),
      },
    ),
    behavior: WorkbenchBehaviorPreset(
      showAnchors: false,
      showLabels: true,
      showBoundingBoxes: true,
      hiddenRoles: {},
      baseGridWorldStep: 10.0,
    ),
  );

  static const paper = WorkbenchVisualProfile(
    id: 'paper',
    label: 'Paper',
    canvasAppearance: WorkbenchCanvasAppearance(
      viewportBackgroundColor: Color(0xFFF8FAFC),
      toolbarBackgroundColor: Color(0xFFE2E8F0),
      overlayBackgroundColor: Color(0xFFF1F5F9),
      gridMinorColor: Color(0xFFCBD5E1),
      gridMajorColor: Color(0xFF94A3B8),
      accentColor: Color(0xFF0F172A),
      accentSoftColor: Color(0x140F172A),
      borderColor: Color(0xFFCBD5E1),
      mutedColor: Color(0xFF475569),
      roleColors: {
        'final': Color(0xFF0F172A),
        'construction': Color(0x66848CA0),
        'guide': Color(0xFF64748B),
        'centerline': Color(0xFFDC2626),
        'hidden': Color(0xFF7C2D12),
        'section': Color(0xFF9D174D),
        'cut': Color(0xFF9D174D),
        'fold': Color(0xFF1D4ED8),
        'dimension': Color(0xFF166534),
        'annotation': Color(0xFF166534),
      },
    ),
    behavior: WorkbenchBehaviorPreset(
      showAnchors: false,
      showLabels: false,
      showBoundingBoxes: false,
      hiddenRoles: {'construction', 'guide', 'hidden'},
      baseGridWorldStep: 25.0,
    ),
  );

  static const all = [cad, blueprint, paper];

  /// Returns a profile id that is safe to pass to a dropdown or renderer.
  ///
  /// Older builds briefly encoded canvas appearance and app theme together
  /// (`cad-dark`, `cad-light`, etc.). Theme is now an independent preference,
  /// so those persisted ids must collapse back to their canvas profile.
  static String normalizeId(String? id) {
    if (id == null || id.isEmpty) return cad.id;
    for (final profile in all) {
      if (profile.id == id) return profile.id;
    }
    final legacyBase = id.split('-').first;
    for (final profile in all) {
      if (profile.id == legacyBase) return profile.id;
    }
    return cad.id;
  }

  static WorkbenchVisualProfile byId(String id) {
    return all.firstWhere(
      (profile) => profile.id == normalizeId(id),
      orElse: () => cad,
    );
  }

  ThemeData materialTheme() {
    final base = viewportBackgroundColor.computeLuminance() < 0.5
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    final colorScheme = base.colorScheme.copyWith(
      primary: accentColor,
      secondary: accentColor,
      surface: toolbarBackgroundColor,
      surfaceContainerHighest: overlayBackgroundColor,
      outline: borderColor,
      onSurface: Colors.white,
      onPrimary: viewportBackgroundColor.computeLuminance() < 0.5
          ? Colors.black
          : Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: viewportBackgroundColor,
      dividerColor: borderColor,
      dialogTheme: DialogThemeData(
        backgroundColor: toolbarBackgroundColor,
        titleTextStyle: TextStyle(
          color: accentColor,
          fontFamily: 'Courier',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Courier',
          fontSize: 11,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: toolbarBackgroundColor,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Courier',
          fontSize: 11,
        ),
        actionTextColor: accentColor,
        behavior: SnackBarBehavior.floating,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        thumbColor: accentColor,
        inactiveTrackColor: borderColor,
        overlayColor: accentSoftColor,
        trackHeight: 2.5,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(
          color: accentColor,
          fontFamily: 'Courier',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          textStyle: const TextStyle(
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accentColor,
        unselectedLabelColor: mutedColor,
        indicatorColor: accentColor,
        dividerColor: borderColor,
        labelStyle: const TextStyle(
          fontFamily: 'Courier',
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
      iconTheme: IconThemeData(color: accentColor),
    );
  }
}
