import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

import 'render_style.dart';

class RenderTypography {
  static double parseScalar(dynamic raw, double defaultValue) {
    if (raw is num) return raw.toDouble();
    if (raw is! String) return defaultValue;

    final clean = raw.toLowerCase().trim();
    final value = double.tryParse(
      clean.replaceAll(RegExp(r'[^0-9eE+\-\.]+$'), ''),
    );
    if (value == null || value.isNaN) return defaultValue;
    if (clean.endsWith('pt')) return value * 1.333333;
    if (clean.endsWith('em') || clean.endsWith('rem')) return value * 16.0;
    return value;
  }

  static double sceneScaleRef(ResolvedScene scene) {
    final diag = math.sqrt(
      scene.bbox.width * scene.bbox.width + scene.bbox.height * scene.bbox.height,
    );
    return diag > 0 ? diag : 100.0;
  }

  static double textFontSize(Meta meta) {
    return parseScalar(meta.extra['fontSize'], 12.0);
  }

  static double annotationFontSize(Meta meta, ResolvedScene scene) {
    return parseScalar(
      meta.extra['fontSize'],
      math.max(sceneScaleRef(scene) * 0.04, 1),
    );
  }

  static double dimensionFontSize(Meta meta, ResolvedScene scene) {
    return parseScalar(
      meta.extra['fontSize'],
      math.max(sceneScaleRef(scene) * 0.04, 1),
    );
  }

  static double arrowSize(Meta meta, ResolvedScene scene) {
    return parseScalar(
      meta.extra['arrowSize'],
      math.max(sceneScaleRef(scene) * 0.03, 0.5),
    );
  }

  static String fontFamily(Meta meta, {String defaultFamily = 'sans-serif'}) {
    return meta.extra['fontFamily']?.toString() ?? defaultFamily;
  }

  static Color textColor(
    Meta meta, {
    required Color fallback,
    Color? defaultFill,
  }) {
    if (meta.fill != null) {
      return RenderStyle.parseColor(meta.fill!) ?? fallback;
    }
    return defaultFill ?? fallback;
  }

  static double approxTextWidth(String text, double fontSize) {
    final lines = text.split('\n');
    final longest = lines.fold<int>(0, (maxLen, line) => math.max(maxLen, line.length));
    return longest * fontSize * 0.6;
  }
}
