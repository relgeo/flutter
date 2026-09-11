import 'package:flutter/material.dart';
import '../geometry/types.dart';

class RenderStyle {
  static const double defaultVisibleStrokeWidth = 0.5;

  static Color defaultWorkbenchRoleColor(String role) {
    switch (role) {
      case 'final':
        return const Color(0xFF00FFCC);
      case 'construction':
        return const Color(0x6694A3B8);
      case 'guide':
        return const Color(0xFFE2E8F0);
      case 'centerline':
        return const Color(0xFFF43F5E);
      case 'hidden':
        return const Color(0xFFF59E0B);
      case 'section':
      case 'cut':
        return const Color(0xFFEC4899);
      case 'fold':
        return const Color(0xFF3B82F6);
      case 'dimension':
      case 'annotation':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  static Color defaultFinalOutputRoleColor(String role) {
    switch (role) {
      case 'construction':
      case 'guide':
        return const Color(0xFF3B82F6);
      case 'centerline':
        return const Color(0xFFFF0000);
      case 'hidden':
        return const Color(0xFF555555);
      default:
        return const Color(0xFF000000);
    }
  }

  static Color defaultRoleColor(String role) {
    return defaultWorkbenchRoleColor(role);
  }

  static double defaultRoleStrokeWidth(String role) {
    switch (role) {
      case 'final':
        return 2.0;
      case 'section':
      case 'cut':
        return 1.8;
      case 'construction':
      case 'guide':
      case 'hidden':
      case 'fold':
        return 1.0;
      case 'centerline':
        return 1.2;
      case 'dimension':
      case 'annotation':
        return 1.0;
      default:
        return 1.5;
    }
  }

  static bool hasExplicitStrokeWidth(Meta meta) {
    return meta.strokeWidth != null;
  }

  static bool hasVisibleStroke(Meta meta) {
    final stroke = meta.stroke?.trim().toLowerCase();
    if (stroke == 'none') return false;
    return true;
  }

  static double resolvedStrokeWidth(Meta meta) {
    if (hasExplicitStrokeWidth(meta)) {
      return meta.strokeWidth!;
    }

    if (hasVisibleStroke(meta)) {
      return defaultVisibleStrokeWidth;
    }

    return defaultRoleStrokeWidth(meta.role);
  }

  static List<double> dashPatternForMeta(Meta meta, {double zoomScale = 1.0}) {
    if (meta.dash != null) {
      try {
        return meta.dash!
            .split(RegExp(r'\s+'))
            .map((s) => double.parse(s) / zoomScale)
            .toList();
      } catch (_) {}
    }
    switch (meta.role) {
      case 'construction':
        return [3.0 / zoomScale, 3.0 / zoomScale];
      case 'hidden':
        return [5.0 / zoomScale, 3.0 / zoomScale];
      case 'centerline':
        return [
          12.0 / zoomScale,
          3.0 / zoomScale,
          3.0 / zoomScale,
          3.0 / zoomScale,
        ];
      case 'guide':
        return [1.0 / zoomScale, 2.0 / zoomScale];
      case 'fold':
        return [2.0 / zoomScale, 2.0 / zoomScale];
      default:
        return [];
    }
  }

  static List<double> defaultFinalOutputDashPattern(
    String role, {
    double zoomScale = 1.0,
  }) {
    switch (role) {
      case 'construction':
      case 'guide':
        return [2.0 / zoomScale, 2.0 / zoomScale];
      case 'hidden':
        return [6.0 / zoomScale, 4.0 / zoomScale];
      case 'centerline':
        return [
          12.0 / zoomScale,
          3.0 / zoomScale,
          3.0 / zoomScale,
          3.0 / zoomScale,
        ];
      default:
        return [];
    }
  }

  static Paint paintForMeta(
    Meta meta, {
    required bool isFill,
    double zoomScale = 1.0,
    bool finalOutputPalette = false,
    Color? fallbackRoleColor,
  }) {
    final paint = Paint()..isAntiAlias = true;

    final roleColor =
        fallbackRoleColor ??
        (finalOutputPalette
            ? defaultFinalOutputRoleColor(meta.role)
            : defaultWorkbenchRoleColor(meta.role));

    Color color;
    if (isFill) {
      if (meta.fill != null) {
        color = parseColor(meta.fill!) ?? Colors.transparent;
      } else {
        color = Colors.transparent;
      }
    } else {
      if (meta.stroke != null) {
        color = parseColor(meta.stroke!) ?? roleColor;
      } else {
        color = roleColor;
      }
    }

    if (meta.opacity != null) {
      color = color.withOpacity(meta.opacity!);
    }

    paint.color = color;

    if (isFill) {
      paint.style = PaintingStyle.fill;
    } else {
      paint.style = PaintingStyle.stroke;
      final baseWidth = resolvedStrokeWidth(meta);
      paint.strokeWidth = baseWidth / zoomScale;
      paint.strokeCap = StrokeCap.round;
      paint.strokeJoin = StrokeJoin.round;
    }

    return paint;
  }

  static Color? parseColor(String str) {
    final s = str.trim().toLowerCase();
    if (s.startsWith('#')) {
      final hex = s.substring(1);
      if (hex.length == 3) {
        final r = hex[0] + hex[0];
        final g = hex[1] + hex[1];
        final b = hex[2] + hex[2];
        return Color(int.parse('FF$r$g$b', radix: 16));
      } else if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    if (s.startsWith('rgb')) {
      final match = RegExp(
        r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)',
      ).firstMatch(s);
      if (match != null) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        final aStr = match.group(4);
        final a = aStr != null ? double.parse(aStr) : 1.0;
        return Color.fromARGB((a * 255).toInt(), r, g, b);
      }
    }
    const colorsMap = {
      'red': Color(0xFFEF4444),
      'green': Color(0xFF10B981),
      'blue': Color(0xFF3B82F6),
      'yellow': Color(0xFFF59E0B),
      'orange': Color(0xFFF97316),
      'purple': Color(0xFF8B5CF6),
      'pink': Color(0xFFEC4899),
      'cyan': Color(0xFF06B6D4),
      'teal': Color(0xFF14B8A6),
      'white': Colors.white,
      'black': Colors.black,
      'gray': Colors.grey,
      'grey': Colors.grey,
    };
    return colorsMap[s];
  }

  static String colorToHex(Color color) {
    final rgb = color.value.toRadixString(16).padLeft(8, '0').substring(2);
    return '#$rgb';
  }
}
