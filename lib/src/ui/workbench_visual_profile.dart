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
  final WorkbenchCanvasAppearance? lightCanvasAppearance;
  final WorkbenchCanvasAppearance? darkCanvasAppearance;
  final WorkbenchBehaviorPreset behavior;

  const WorkbenchVisualProfile({
    required this.id,
    required this.label,
    required this.canvasAppearance,
    this.lightCanvasAppearance,
    this.darkCanvasAppearance,
    required this.behavior,
  });

  WorkbenchCanvasAppearance appearanceFor(Brightness brightness) {
    return switch (brightness) {
      Brightness.light => lightCanvasAppearance ?? canvasAppearance,
      Brightness.dark => darkCanvasAppearance ?? canvasAppearance,
    };
  }

  WorkbenchVisualProfile forBrightness(Brightness brightness) {
    return WorkbenchVisualProfile(
      id: id,
      label: label,
      canvasAppearance: appearanceFor(brightness),
      lightCanvasAppearance: lightCanvasAppearance,
      darkCanvasAppearance: darkCanvasAppearance,
      behavior: behavior,
    );
  }

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

  /// Adapts application chrome and selects the canvas palette variant for the
  /// same brightness. The visual profile keeps its identity while its canvas,
  /// grid, text, and semantic role colors maintain contrast in either mode.
  WorkbenchVisualProfile withChromeTheme(ColorScheme colorScheme) {
    final appearance = appearanceFor(colorScheme.brightness);
    return WorkbenchVisualProfile(
      id: id,
      label: label,
      canvasAppearance: WorkbenchCanvasAppearance(
        viewportBackgroundColor: appearance.viewportBackgroundColor,
        toolbarBackgroundColor: colorScheme.surface,
        overlayBackgroundColor: colorScheme.surfaceContainerHighest,
        gridMinorColor: appearance.gridMinorColor,
        gridMajorColor: appearance.gridMajorColor,
        accentColor: colorScheme.primary,
        accentSoftColor: colorScheme.primary.withValues(alpha: 0.14),
        borderColor: colorScheme.outlineVariant,
        mutedColor: colorScheme.onSurfaceVariant,
        roleColors: appearance.roleColors,
      ),
      behavior: behavior,
    );
  }

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
    lightCanvasAppearance: WorkbenchCanvasAppearance(
      viewportBackgroundColor: Color(0xFFF1F5F4),
      toolbarBackgroundColor: Color(0xFFE8EFED),
      overlayBackgroundColor: Color(0xFFE5EEEB),
      gridMinorColor: Color(0xFFD5E0DD),
      gridMajorColor: Color(0xFFB2C4BF),
      accentColor: Color(0xFF006B5B),
      accentSoftColor: Color(0x1A006B5B),
      borderColor: Color(0xFFC6D4D0),
      mutedColor: Color(0xFF526A65),
      roleColors: {
        'final': Color(0xFF006B5B),
        'construction': Color(0xFF687E79),
        'guide': Color(0xFF435B56),
        'centerline': Color(0xFFC62845),
        'hidden': Color(0xFF925900),
        'section': Color(0xFF9B3479),
        'cut': Color(0xFF9B3479),
        'fold': Color(0xFF285FA7),
        'dimension': Color(0xFF087653),
        'annotation': Color(0xFF087653),
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
    lightCanvasAppearance: WorkbenchCanvasAppearance(
      viewportBackgroundColor: Color(0xFFEAF3FA),
      toolbarBackgroundColor: Color(0xFFE0EEF8),
      overlayBackgroundColor: Color(0xFFDFECF6),
      gridMinorColor: Color(0xFFC9DDED),
      gridMajorColor: Color(0xFF94B6D1),
      accentColor: Color(0xFF145B91),
      accentSoftColor: Color(0x1A145B91),
      borderColor: Color(0xFFB7CDDF),
      mutedColor: Color(0xFF4F6F89),
      roleColors: {
        'final': Color(0xFF17496E),
        'construction': Color(0xFF5C7A91),
        'guide': Color(0xFF1E5C84),
        'centerline': Color(0xFF8B5C00),
        'hidden': Color(0xFF8B5C00),
        'section': Color(0xFFA33B70),
        'cut': Color(0xFFA33B70),
        'fold': Color(0xFF4C54A4),
        'dimension': Color(0xFF20724D),
        'annotation': Color(0xFF20724D),
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
    darkCanvasAppearance: WorkbenchCanvasAppearance(
      viewportBackgroundColor: Color(0xFF28251F),
      toolbarBackgroundColor: Color(0xFF302D26),
      overlayBackgroundColor: Color(0xFF363229),
      gridMinorColor: Color(0xFF474238),
      gridMajorColor: Color(0xFF655D4E),
      accentColor: Color(0xFFF2E5D1),
      accentSoftColor: Color(0x14F2E5D1),
      borderColor: Color(0xFF554F43),
      mutedColor: Color(0xFFBDB4A4),
      roleColors: {
        'final': Color(0xFFF4EBDD),
        'construction': Color(0xFFAAA293),
        'guide': Color(0xFFD4CBBB),
        'centerline': Color(0xFFFF7B70),
        'hidden': Color(0xFFE9A66A),
        'section': Color(0xFFEE88B6),
        'cut': Color(0xFFEE88B6),
        'fold': Color(0xFF9CB9FF),
        'dimension': Color(0xFF86D5A1),
        'annotation': Color(0xFF86D5A1),
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
}
