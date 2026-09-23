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

class WorkbenchVisualProfile {
  final String id;
  final String label;
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
  final WorkbenchBehaviorPreset behavior;

  const WorkbenchVisualProfile({
    required this.id,
    required this.label,
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
    required this.behavior,
  });

  Color roleColor(String role) {
    return roleColors[role] ?? Colors.white;
  }

  static const cadDark = WorkbenchVisualProfile(
    id: 'cad-dark',
    label: 'CAD Dark',
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
    behavior: WorkbenchBehaviorPreset(
      showAnchors: false,
      showLabels: false,
      showBoundingBoxes: false,
      hiddenRoles: {'construction', 'guide', 'hidden'},
      baseGridWorldStep: 25.0,
    ),
  );

  static const all = [cadDark, blueprint, paper];

  static WorkbenchVisualProfile byId(String id) {
    for (final profile in all) {
      if (profile.id == id) return profile;
    }
    return cadDark;
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
