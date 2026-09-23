import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import '../geometry/utils.dart' as geom;
import 'render_hierarchy.dart';
import 'render_presentational.dart';
import 'render_style.dart';
import 'render_typography.dart';

const _activeRelGeoVersion = 'v0.5';

String _metadataAttributes(ResolvedObject obj, Meta meta) {
  final attrs = <String>[
    'id="${SvgExporter._escapeXml(obj.id)}"',
    'class="role-${SvgExporter._escapeXml(meta.role.replaceAll(RegExp(r'\\s+'), '-'))}"',
    'data-role="${SvgExporter._escapeXml(meta.role)}"',
  ];

  final intent = meta.extra['intent'];
  if (intent != null && intent.toString().trim().isNotEmpty) {
    attrs.add('data-intent="${SvgExporter._escapeXml(intent.toString())}"');
  }

  if (meta.label != null && meta.label!.trim().isNotEmpty) {
    attrs.add('data-label="${SvgExporter._escapeXml(meta.label!)}"');
  }

  return attrs.join(' ');
}

class SvgExporter {
  static double _physicalPresentationalScale({
    bool physicalPreview = false,
    double? viewScale,
  }) {
    if (!physicalPreview ||
        viewScale == null ||
        !viewScale.isFinite ||
        viewScale <= 0) {
      return 1.0;
    }
    return viewScale;
  }

  static String _vectorEffectAttr(Meta meta, {bool hasVisibleStroke = true}) {
    if (!hasVisibleStroke) return '';

    final extra = meta.extra;
    if (extra.containsKey('non-scaling-stroke')) {
      return extra['non-scaling-stroke'] == false
          ? ''
          : ' vector-effect="non-scaling-stroke"';
    }
    if (extra['hairline'] == true) {
      return ' vector-effect="non-scaling-stroke"';
    }
    if (!RenderStyle.hasExplicitStrokeWidth(meta)) {
      return ' vector-effect="non-scaling-stroke"';
    }
    return ' vector-effect="non-scaling-stroke"';
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static void _writeText(
    StringBuffer out, {
    required ResolvedObject obj,
    required Meta meta,
    required double x,
    required double y,
    required String content,
    required String indent,
    double presentationalScale = 1.0,
  }) {
    final strokeColor =
        RenderStyle.parseColor(meta.stroke ?? '') ??
        RenderStyle.defaultFinalOutputRoleColor(meta.role);
    final fill = RenderStyle.colorToHex(
      RenderTypography.textColor(
        meta,
        fallback: strokeColor,
        defaultFill: const Color(0xFF000000),
      ),
    );
    final fontSize = RenderTypography.textFontSize(meta) / presentationalScale;
    final fontFamily = RenderTypography.fontFamily(meta);
    final lines = content.split('\n');
    final rawLineHeight = meta.extra['lineHeight'];
    final lineStep = rawLineHeight == null ? '1em' : '${rawLineHeight}em';

    final attrs = _metadataAttributes(obj, meta);

    if (lines.length <= 1) {
      out.writeln(
        '$indent<text $attrs x="$x" y="$y" dominant-baseline="hanging" font-family="$fontFamily" font-size="$fontSize" fill="$fill">${_escapeXml(content)}</text>',
      );
      return;
    }

    out.writeln(
      '$indent<text $attrs x="$x" y="$y" dominant-baseline="hanging" font-family="$fontFamily" font-size="$fontSize" fill="$fill">',
    );
    for (var i = 0; i < lines.length; i++) {
      out.writeln(
        '$indent  <tspan x="$x" dy="${i == 0 ? '0' : lineStep}">${_escapeXml(lines[i])}</tspan>',
      );
    }
    out.writeln('$indent</text>');
  }

  static double _pointSize(
    Meta meta,
    ResolvedScene scene, {
    double presentationalScale = 1.0,
  }) {
    final raw = meta.extra['pointSize'];
    final parsed = raw == null ? null : double.tryParse(raw.toString());
    if (parsed != null && parsed.isFinite) {
      return parsed / presentationalScale;
    }
    final bbox = scene.bbox;
    final maxDim = math.sqrt(
      bbox.width * bbox.width + bbox.height * bbox.height,
    );
    final scaleRef = maxDim > 0 ? maxDim : 100.0;
    return math.max(scaleRef * 0.01, 0.5) / presentationalScale;
  }

  static String _pointShape(Meta meta) {
    final raw = meta.extra['pointShape']?.toString().trim();
    if (raw == null || raw.isEmpty) return 'plus';
    return raw;
  }

  static String _ellipseTransformDegrees(double rotation) {
    return (rotation * 180 / math.pi).toString();
  }

  static void _writeAnnotation(
    StringBuffer out, {
    required ResolvedScene scene,
    required ResolvedAnnotation annotation,
    required Meta meta,
    required String indent,
    double presentationalScale = 1.0,
  }) {
    final leader = annotation.leader;
    final text = annotation.text;
    final target = annotation.target;

    if (leader == null && target == null) return;

    final strokeColor =
        RenderStyle.parseColor(meta.stroke ?? '') ??
        RenderStyle.defaultFinalOutputRoleColor(meta.role);
    final strokeHex = RenderStyle.colorToHex(strokeColor);
    final strokeWidth = RenderStyle.resolvedStrokeWidth(meta);
    final fontSize =
        RenderTypography.annotationFontSize(meta, scene) / presentationalScale;
    final fontFamily = RenderTypography.fontFamily(meta);
    final fill = RenderStyle.colorToHex(
      RenderTypography.textColor(
        meta,
        fallback: strokeColor,
        defaultFill: const Color(0xFF333333),
      ),
    );
    final attrs = _metadataAttributes(annotation, meta);
    final lines = text.split('\n');
    final vectorEffect = _vectorEffectAttr(meta);
    double textX;
    double textY;

    if (leader != null) {
      final layout = RenderPresentational.annotationLeaderLayout(
        from: leader.fromPoint,
        to: leader.toPoint,
        text: text,
        fontSize: fontSize,
        arrowLength:
            RenderPresentational.annotationArrowLength / presentationalScale,
        arrowWidth:
            RenderPresentational.annotationArrowWidth / presentationalScale,
        gap: RenderPresentational.annotationGap / presentationalScale,
      );

      out.writeln(
        '$indent<line x1="${layout.from.x}" y1="${layout.from.y}" x2="${layout.to.x}" y2="${layout.to.y}" stroke="$strokeHex" stroke-width="$strokeWidth"$vectorEffect />',
      );
      out.writeln(
        '$indent<circle cx="${layout.from.x}" cy="${layout.from.y}" r="${(2 / presentationalScale).toStringAsFixed(1)}" fill="$strokeHex" stroke="none" />',
      );

      if (layout.arrowhead != null) {
        final arrow = layout.arrowhead!;
        out.writeln(
          '$indent<path d="M ${arrow.tip.x} ${arrow.tip.y} L ${arrow.wing1.x} ${arrow.wing1.y} L ${arrow.wing2.x} ${arrow.wing2.y} Z" fill="$strokeHex" stroke="none" />',
        );
      }

      out.writeln(
        '$indent<line x1="${layout.to.x}" y1="${layout.to.y}" x2="${layout.anchorLineEndX}" y2="${layout.to.y}" stroke="$strokeHex" stroke-width="$strokeWidth"$vectorEffect />',
      );

      textX = layout.textX;
      textY = layout.textY;
      out.writeln(
        '$indent<text $attrs x="$textX" y="$textY" dominant-baseline="hanging" font-family="$fontFamily" font-size="${fontSize.toStringAsFixed(1)}" fill="$fill">',
      );
    } else {
      final targetObj = target != null ? scene.objects[target] : null;
      if (targetObj == null) return;
      final targetBBox = geom.calculateBoundingBox({targetObj.id: targetObj});
      final layout = RenderPresentational.annotationTargetFallbackLayout(
        targetBBox: targetBBox,
        text: text,
        fontSize: fontSize,
        gap: RenderPresentational.annotationGap / presentationalScale,
      );
      textX = layout.textX;
      textY = layout.textY;
      out.writeln(
        '$indent<text $attrs x="$textX" y="$textY" dominant-baseline="hanging" font-family="$fontFamily" font-size="${fontSize.toStringAsFixed(1)}" fill="$fill">',
      );
    }

    for (var i = 0; i < lines.length; i++) {
      final line = _escapeXml(lines[i]);
      out.writeln(
        '$indent  <tspan x="$textX" dy="${i == 0 ? 0 : '1.2em'}">$line</tspan>',
      );
    }
    out.writeln('$indent</text>');
  }

  static void _writeDimension(
    StringBuffer out, {
    required ResolvedScene scene,
    required ResolvedDimension dim,
    required Meta meta,
    required String indent,
    double presentationalScale = 1.0,
  }) {
    final strokeColor =
        RenderStyle.parseColor(meta.stroke ?? '') ??
        RenderStyle.defaultFinalOutputRoleColor(meta.role);
    final strokeHex = RenderStyle.colorToHex(strokeColor);
    final strokeWidth = RenderStyle.resolvedStrokeWidth(meta);
    final textColor = RenderStyle.colorToHex(
      RenderTypography.textColor(
        meta,
        fallback: strokeColor,
        defaultFill: const Color(0xFF444444),
      ),
    );
    final scaleRef = RenderTypography.sceneScaleRef(scene);
    final arrowLength =
        RenderTypography.arrowSize(meta, scene) / presentationalScale;
    final arrowWidth = arrowLength / 3;
    final fontSize =
        RenderTypography.dimensionFontSize(meta, scene) / presentationalScale;
    final fontFamily = RenderTypography.fontFamily(meta);
    final attrs = _metadataAttributes(dim, meta);
    final vectorEffect = _vectorEffectAttr(meta);

    switch (dim.kind) {
      case 'linear':
        final from = dim.fromPoint;
        final to = dim.toPoint;
        if (from == null || to == null) return;
        final layout = RenderPresentational.linearDimensionLayout(
          from: from,
          to: to,
          offset: dim.offset / presentationalScale,
          arrowLength: arrowLength,
          arrowWidth: arrowWidth,
        );
        if (layout == null) return;

        out.writeln(
          '$indent<g stroke="$strokeHex" stroke-width="$strokeWidth" fill="none"$vectorEffect>',
        );
        out.writeln(
          '$indent  <line x1="${layout.extension1.from.x}" y1="${layout.extension1.from.y}" x2="${layout.extension1.to.x}" y2="${layout.extension1.to.y}" />',
        );
        out.writeln(
          '$indent  <line x1="${layout.extension2.from.x}" y1="${layout.extension2.from.y}" x2="${layout.extension2.to.x}" y2="${layout.extension2.to.y}" />',
        );
        out.writeln(
          '$indent  <line x1="${layout.dimensionLine.from.x}" y1="${layout.dimensionLine.from.y}" x2="${layout.dimensionLine.to.x}" y2="${layout.dimensionLine.to.y}" />',
        );
        out.writeln('$indent</g>');

        out.writeln(
          '$indent<path d="M ${layout.arrowStart.tip.x} ${layout.arrowStart.tip.y} L ${layout.arrowStart.wing1.x} ${layout.arrowStart.wing1.y} L ${layout.arrowStart.wing2.x} ${layout.arrowStart.wing2.y} Z" fill="$strokeHex" stroke="none" />',
        );
        out.writeln(
          '$indent<path d="M ${layout.arrowEnd.tip.x} ${layout.arrowEnd.tip.y} L ${layout.arrowEnd.wing1.x} ${layout.arrowEnd.wing1.y} L ${layout.arrowEnd.wing2.x} ${layout.arrowEnd.wing2.y} Z" fill="$strokeHex" stroke="none" />',
        );
        out.writeln(
          '$indent<text $attrs x="${layout.labelX}" y="${layout.labelY}" text-anchor="middle" dominant-baseline="central" transform="rotate(${layout.labelRotationDeg}, ${layout.labelX}, ${layout.labelY}) translate(0, -${layout.labelOffset})" font-size="${fontSize}px" font-family="$fontFamily" fill="$textColor" stroke="none">${_escapeXml(dim.text)}</text>',
        );
        return;
      case 'radius':
      case 'diameter':
        final target = dim.target != null ? scene.objects[dim.target] : null;
        double? cx;
        double? cy;
        double? radius;
        if (target is ResolvedCircle) {
          cx = target.cx;
          cy = target.cy;
          radius = target.radius;
        } else if (target is ResolvedArc) {
          cx = target.cx;
          cy = target.cy;
          radius = target.radius;
        } else {
          return;
        }
        final layout = RenderPresentational.radialDimensionLayout(
          center: (x: cx, y: cy),
          radius: radius,
          arrowLength: arrowLength,
          arrowWidth: arrowWidth,
          diameter: dim.kind == 'diameter',
        );
        if (layout == null) return;
        out.writeln(
          '$indent<line x1="${layout.baseLine.from.x}" y1="${layout.baseLine.from.y}" x2="${layout.baseLine.to.x}" y2="${layout.baseLine.to.y}" stroke="$strokeHex" stroke-width="$strokeWidth"$vectorEffect />',
        );
        out.writeln(
          '$indent<path d="M ${layout.arrowPrimary.tip.x} ${layout.arrowPrimary.tip.y} L ${layout.arrowPrimary.wing1.x} ${layout.arrowPrimary.wing1.y} L ${layout.arrowPrimary.wing2.x} ${layout.arrowPrimary.wing2.y} Z" fill="$strokeHex" stroke="none" />',
        );
        if (layout.arrowSecondary != null) {
          out.writeln(
            '$indent<path d="M ${layout.arrowSecondary!.tip.x} ${layout.arrowSecondary!.tip.y} L ${layout.arrowSecondary!.wing1.x} ${layout.arrowSecondary!.wing1.y} L ${layout.arrowSecondary!.wing2.x} ${layout.arrowSecondary!.wing2.y} Z" fill="$strokeHex" stroke="none" />',
          );
        }
        out.writeln(
          '$indent<path d="M ${layout.leader1.from.x} ${layout.leader1.from.y} L ${layout.leader1.to.x} ${layout.leader1.to.y} L ${layout.leader2.to.x} ${layout.leader2.to.y}" fill="none" stroke="$strokeHex" stroke-width="$strokeWidth"$vectorEffect />',
        );
        out.writeln(
          '$indent<text $attrs x="${layout.textX}" y="${layout.textY}" dominant-baseline="central" font-size="${fontSize}px" font-family="$fontFamily" fill="$textColor" stroke="none">${_escapeXml(dim.text)}</text>',
        );
        return;
      case 'angle':
        if (dim.between.length != 2) return;
        final line1 = scene.objects[dim.between[0]];
        final line2 = scene.objects[dim.between[1]];
        if (line1 is! ResolvedLine || line2 is! ResolvedLine) return;
        final layout = RenderPresentational.angleDimensionLayout(
          line1: line1,
          line2: line2,
          scaleRef: scaleRef,
          arrowLength: arrowLength,
          presentationalScale: presentationalScale,
        );
        if (layout == null) return;
        out.writeln(
          '$indent<path d="M ${layout.startX} ${layout.startY} A ${layout.radius} ${layout.radius} 0 ${layout.sweepAngle.abs() > math.pi ? 1 : 0} ${layout.sweepAngle >= 0 ? 1 : 0} ${layout.endX} ${layout.endY}" fill="none" stroke="$strokeHex" stroke-width="$strokeWidth"$vectorEffect />',
        );
        out.writeln(
          '$indent<text $attrs x="${layout.textX}" y="${layout.textY}" text-anchor="middle" dominant-baseline="central" font-size="${fontSize}px" font-family="$fontFamily" fill="$textColor" stroke="none">${_escapeXml(dim.text)}</text>',
        );
        return;
      default:
        return;
    }
  }

  static String generateSVG(
    ResolvedScene scene, {
    bool showConstruction = false,
    String? sheetId,
    Set<String>? hiddenRoles,
  }) {
    final effectiveHiddenRoles = hiddenRoles ?? const {'construction'};
    if (sheetId != null && scene.sheets.containsKey(sheetId)) {
      return _generateSheetSVG(
        scene,
        sheetId,
        showConstruction: showConstruction,
        hiddenRoles: effectiveHiddenRoles,
      );
    }

    final bbox = scene.bbox;
    final buf = StringBuffer();

    buf.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buf.writeln('<svg xmlns="http://www.w3.org/2000/svg"');
    buf.writeln(
      '     width="${bbox.width}${scene.unit.name}" height="${bbox.height}${scene.unit.name}"',
    );
    buf.writeln(
      '     viewBox="${bbox.x} ${bbox.y} ${bbox.width} ${bbox.height}">',
    );
    buf.writeln('  <!-- Generated by RelGeo CAD Workbench v0.5 -->');
    buf.writeln('  <rect width="100%" height="100%" fill="#0F172A" />');

    String style(Meta meta, {bool isFill = false}) {
      final sc =
          RenderStyle.parseColor(meta.stroke ?? '') ??
          RenderStyle.defaultFinalOutputRoleColor(meta.role);
      final sh = RenderStyle.colorToHex(sc);
      final sw = RenderStyle.resolvedStrokeWidth(meta);
      final da = meta.dash != null
          ? RenderStyle.dashPatternForMeta(meta)
          : RenderStyle.defaultFinalOutputDashPattern(meta.role);
      final ds = da.isNotEmpty ? ' stroke-dasharray="${da.join(',')}"' : '';
      final ve = _vectorEffectAttr(
        meta,
        hasVisibleStroke: meta.stroke?.trim().toLowerCase() != 'none',
      );
      if (isFill && meta.fill != null) {
        final fc = RenderStyle.parseColor(meta.fill!) ?? Colors.transparent;
        if (fc != Colors.transparent) {
          final fh = RenderStyle.colorToHex(fc);
          return 'fill="$fh" stroke="$sh" stroke-width="$sw"$ds$ve';
        }
      }
      return 'fill="none" stroke="$sh" stroke-width="$sw"$ds$ve';
    }

    String attrs(ResolvedObject obj, Meta meta) =>
        _metadataAttributes(obj, meta);

    bool shouldRenderRole(String role) {
      if (role == 'construction') return showConstruction;
      if (effectiveHiddenRoles.contains(role)) return false;
      return true;
    }

    void writePrimitive(
      StringBuffer out,
      ResolvedObject obj,
      Meta meta, {
      double presentationalScale = 1.0,
    }) {
      final transform = RenderHierarchy.transformToSvg(obj.transforms);
      if (transform != null) {
        out.writeln('  <g transform="$transform">');
      }
      switch (obj) {
        case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
          out.writeln(
            '  <line ${attrs(obj, meta)} x1="$x1" y1="$y1" x2="$x2" y2="$y2" ${style(meta)} />',
          );
        case ResolvedRect(:final x, :final y, :final width, :final height):
          out.writeln(
            '  <rect ${attrs(obj, meta)} x="$x" y="$y" width="$width" height="$height" ${style(meta, isFill: true)} />',
          );
        case ResolvedCircle(:final cx, :final cy, :final radius):
          out.writeln(
            '  <circle ${attrs(obj, meta)} cx="$cx" cy="$cy" r="$radius" ${style(meta, isFill: true)} />',
          );
        case ResolvedEllipse(
          :final cx,
          :final cy,
          :final rx,
          :final ry,
          :final rotation,
        ):
          final transform = rotation == 0
              ? ''
              : ' transform="rotate(${_ellipseTransformDegrees(rotation)} $cx $cy)"';
          out.writeln(
            '  <ellipse ${attrs(obj, meta)} cx="$cx" cy="$cy" rx="$rx" ry="$ry"$transform ${style(meta, isFill: true)} />',
          );
        case ResolvedArc(
          :final cx,
          :final cy,
          :final radius,
          :final startAngle,
          :final endAngle,
          :final sweep,
          :final largeArc,
        ):
          double sa = startAngle;
          double ea = endAngle;
          if (sweep == 1 && ea < sa) ea += 2 * math.pi;
          if (sweep == 0 && ea > sa) ea -= 2 * math.pi;
          final x1 = cx + radius * math.cos(sa);
          final y1 = cy + radius * math.sin(sa);
          final x2 = cx + radius * math.cos(ea);
          final y2 = cy + radius * math.sin(ea);
          out.writeln(
            '  <path ${attrs(obj, meta)} d="M $x1 $y1 A $radius $radius 0 $largeArc $sweep $x2 $y2" ${style(meta)} />',
          );
        case ResolvedQuadratic(
          :final x1,
          :final y1,
          :final cpx,
          :final cpy,
          :final x2,
          :final y2,
        ):
          out.writeln(
            '  <path ${attrs(obj, meta)} d="M $x1 $y1 Q $cpx $cpy $x2 $y2" ${style(meta)} />',
          );
        case ResolvedCubic(
          :final x1,
          :final y1,
          :final cp1x,
          :final cp1y,
          :final cp2x,
          :final cp2y,
          :final x2,
          :final y2,
        ):
          out.writeln(
            '  <path ${attrs(obj, meta)} d="M $x1 $y1 C $cp1x $cp1y $cp2x $cp2y $x2 $y2" ${style(meta)} />',
          );
        case ResolvedPath(:final segments, :final closed):
          _writeSVGSegments(
            out,
            segments,
            closed,
            style(meta, isFill: closed),
            attrs: attrs(obj, meta),
          );
        case ResolvedPolygon(:final segments):
          _writeSVGSegments(
            out,
            segments,
            true,
            style(meta, isFill: true),
            attrs: attrs(obj, meta),
          );
        case ResolvedBoolean(:final segments):
          _writeSVGSegments(
            out,
            segments,
            true,
            style(meta, isFill: true),
            attrs: attrs(obj, meta),
          );
        case ResolvedPoint(:final x, :final y):
          final size = _pointSize(
            meta,
            scene,
            presentationalScale: presentationalScale,
          );
          final pointShape = _pointShape(meta);
          if (pointShape == 'circle') {
            out.writeln(
              '  <circle ${attrs(obj, meta)} cx="$x" cy="$y" r="$size" ${style(meta, isFill: true)} />',
            );
          } else {
            final d =
                'M ${x - size} $y L ${x + size} $y M $x ${y - size} L $x ${y + size}';
            out.writeln('  <path ${attrs(obj, meta)} d="$d" ${style(meta)} />');
          }
        case ResolvedText(:final x, :final y, :final content):
          _writeText(
            out,
            obj: obj,
            meta: meta,
            x: x,
            y: y,
            content: content,
            indent: '  ',
            presentationalScale: presentationalScale,
          );
        case ResolvedDimension():
          _writeDimension(
            out,
            scene: scene,
            dim: obj,
            meta: meta,
            indent: '  ',
          );
        case ResolvedAnnotation():
          _writeAnnotation(
            out,
            scene: scene,
            annotation: obj,
            meta: meta,
            indent: '  ',
          );
        default:
          break;
      }
      if (transform != null) {
        out.writeln('  </g>');
      }
    }

    RenderHierarchy.renderRootedObjects(
      objects: scene.objects,
      objectLookup: scene.objects,
      shouldRenderRole: shouldRenderRole,
      renderPrimitive: (obj, meta) => writePrimitive(buf, obj, meta),
      withTransformScope: (transforms, renderChild) {
        final transform = RenderHierarchy.transformToSvg(transforms);
        if (transform != null) {
          buf.writeln('  <g transform="$transform">');
        }
        renderChild();
        if (transform != null) {
          buf.writeln('  </g>');
        }
      },
    );

    buf.writeln('</svg>');
    return buf.toString();
  }

  static String _generateSheetSVG(
    ResolvedScene scene,
    String sheetId, {
    bool showConstruction = false,
    required Set<String> hiddenRoles,
  }) {
    final sheet = scene.sheets[sheetId]!;
    final width = sheet.width;
    final height = sheet.height;
    final buf = StringBuffer();

    double p = 10;
    switch (scene.unit) {
      case LengthUnit.cm:
        p = 1;
      case LengthUnit.m:
        p = 0.01;
      case LengthUnit.px:
        p = 10 * (96 / 25.4);
      default:
        p = 10;
    }
    final mm = p / 10;

    String displayUnit(LengthUnit unit) {
      if (unit == LengthUnit.m) return 'mm';
      if (unit == LengthUnit.ip) return 'in';
      return unit.name;
    }

    bool shouldRenderRole(String role) {
      if (role == 'construction') return showConstruction;
      if (hiddenRoles.contains(role)) return false;
      return true;
    }

    String style(Meta meta, {bool isFill = false}) {
      final sc =
          RenderStyle.parseColor(meta.stroke ?? '') ??
          RenderStyle.defaultFinalOutputRoleColor(meta.role);
      final sh = RenderStyle.colorToHex(sc);
      final sw = RenderStyle.resolvedStrokeWidth(meta);
      final da = meta.dash != null
          ? RenderStyle.dashPatternForMeta(meta)
          : RenderStyle.defaultFinalOutputDashPattern(meta.role);
      final ds = da.isNotEmpty ? ' stroke-dasharray="${da.join(',')}"' : '';
      final ve = _vectorEffectAttr(
        meta,
        hasVisibleStroke: meta.stroke?.trim().toLowerCase() != 'none',
      );
      if (isFill && meta.fill != null) {
        final fc = RenderStyle.parseColor(meta.fill!) ?? Colors.transparent;
        if (fc != Colors.transparent) {
          final fh = RenderStyle.colorToHex(fc);
          return 'fill="$fh" stroke="$sh" stroke-width="$sw"$ds$ve';
        }
      }
      return 'fill="none" stroke="$sh" stroke-width="$sw"$ds$ve';
    }

    String attrs(ResolvedObject obj, Meta meta) =>
        _metadataAttributes(obj, meta);

    void writePrimitive(
      StringBuffer out,
      ResolvedObject obj,
      Meta meta, {
      double presentationalScale = 1.0,
    }) {
      if (!meta.visible || !shouldRenderRole(meta.role)) return;
      final transform = RenderHierarchy.transformToSvg(obj.transforms);
      if (transform != null) {
        out.writeln('      <g transform="$transform">');
      }

      switch (obj) {
        case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
          out.writeln(
            '      <line ${attrs(obj, meta)} x1="$x1" y1="$y1" x2="$x2" y2="$y2" ${style(meta)} />',
          );
        case ResolvedRect(:final x, :final y, :final width, :final height):
          out.writeln(
            '      <rect ${attrs(obj, meta)} x="$x" y="$y" width="$width" height="$height" ${style(meta, isFill: true)} />',
          );
        case ResolvedCircle(:final cx, :final cy, :final radius):
          out.writeln(
            '      <circle ${attrs(obj, meta)} cx="$cx" cy="$cy" r="$radius" ${style(meta, isFill: true)} />',
          );
        case ResolvedEllipse(
          :final cx,
          :final cy,
          :final rx,
          :final ry,
          :final rotation,
        ):
          final transform = rotation == 0
              ? ''
              : ' transform="rotate(${_ellipseTransformDegrees(rotation)} $cx $cy)"';
          out.writeln(
            '      <ellipse ${attrs(obj, meta)} cx="$cx" cy="$cy" rx="$rx" ry="$ry"$transform ${style(meta, isFill: true)} />',
          );
        case ResolvedArc(
          :final cx,
          :final cy,
          :final radius,
          :final startAngle,
          :final endAngle,
          :final sweep,
          :final largeArc,
        ):
          double sa = startAngle;
          double ea = endAngle;
          if (sweep == 1 && ea < sa) ea += 2 * math.pi;
          if (sweep == 0 && ea > sa) ea -= 2 * math.pi;
          final x1 = cx + radius * math.cos(sa);
          final y1 = cy + radius * math.sin(sa);
          final x2 = cx + radius * math.cos(ea);
          final y2 = cy + radius * math.sin(ea);
          out.writeln(
            '      <path ${attrs(obj, meta)} d="M $x1 $y1 A $radius $radius 0 $largeArc $sweep $x2 $y2" ${style(meta)} />',
          );
        case ResolvedQuadratic(
          :final x1,
          :final y1,
          :final cpx,
          :final cpy,
          :final x2,
          :final y2,
        ):
          out.writeln(
            '      <path ${attrs(obj, meta)} d="M $x1 $y1 Q $cpx $cpy $x2 $y2" ${style(meta)} />',
          );
        case ResolvedCubic(
          :final x1,
          :final y1,
          :final cp1x,
          :final cp1y,
          :final cp2x,
          :final cp2y,
          :final x2,
          :final y2,
        ):
          out.writeln(
            '      <path ${attrs(obj, meta)} d="M $x1 $y1 C $cp1x $cp1y $cp2x $cp2y $x2 $y2" ${style(meta)} />',
          );
        case ResolvedPath(:final segments, :final closed):
          _writeSVGSegments(
            out,
            segments,
            closed,
            style(meta, isFill: closed),
            attrs: attrs(obj, meta),
            indent: '      ',
          );
        case ResolvedPolygon(:final segments):
          _writeSVGSegments(
            out,
            segments,
            true,
            style(meta, isFill: true),
            attrs: attrs(obj, meta),
            indent: '      ',
          );
        case ResolvedBoolean(:final segments):
          _writeSVGSegments(
            out,
            segments,
            true,
            style(meta, isFill: true),
            attrs: attrs(obj, meta),
            indent: '      ',
          );
        case ResolvedPoint(:final x, :final y):
          final size = _pointSize(
            meta,
            scene,
            presentationalScale: presentationalScale,
          );
          final pointShape = _pointShape(meta);
          if (pointShape == 'circle') {
            out.writeln(
              '      <circle ${attrs(obj, meta)} cx="$x" cy="$y" r="$size" ${style(meta, isFill: true)} />',
            );
          } else {
            final d =
                'M ${x - size} $y L ${x + size} $y M $x ${y - size} L $x ${y + size}';
            out.writeln(
              '      <path ${attrs(obj, meta)} d="$d" ${style(meta)} />',
            );
          }
        case ResolvedText(:final x, :final y, :final content):
          _writeText(
            out,
            obj: obj,
            meta: meta,
            x: x,
            y: y,
            content: content,
            indent: '      ',
            presentationalScale: presentationalScale,
          );
        case ResolvedDimension():
          _writeDimension(
            out,
            scene: scene,
            dim: obj,
            meta: meta,
            indent: '      ',
            presentationalScale: presentationalScale,
          );
        case ResolvedAnnotation():
          _writeAnnotation(
            out,
            scene: scene,
            annotation: obj,
            meta: meta,
            indent: '      ',
            presentationalScale: presentationalScale,
          );
        default:
          break;
      }
      if (transform != null) {
        out.writeln('      </g>');
      }
    }

    buf.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buf.writeln('<svg xmlns="http://www.w3.org/2000/svg"');
    buf.writeln(
      '     width="${scene.unit == LengthUnit.m ? width * 1000 : width}${displayUnit(scene.unit)}"',
    );
    buf.writeln(
      '     height="${scene.unit == LengthUnit.m ? height * 1000 : height}${displayUnit(scene.unit)}"',
    );
    buf.writeln('     viewBox="0 0 $width $height">');
    buf.writeln(
      '  <rect x="-10" y="-10" width="${width + 20}" height="${height + 20}" fill="#f3f4f6" />',
    );

    final marginSize = (scene.padding) * mm;
    buf.writeln(
      '  <rect x="$marginSize" y="$marginSize" width="${width - 2 * marginSize}" height="${height - 2 * marginSize}" fill="none" stroke="#333" stroke-width="${0.8 * mm}" />',
    );

    for (final placement in sheet.views) {
      final view = scene.views[placement.use];
      if (view == null) continue;
      final presentationalScale = _physicalPresentationalScale(
        physicalPreview: true,
        viewScale: view.scaleFactor,
      );

      final viewOriginX = view.scaleFactor != 0
          ? view.bbox.x / view.scaleFactor
          : view.bbox.x;
      final viewOriginY = view.scaleFactor != 0
          ? view.bbox.y / view.scaleFactor
          : view.bbox.y;

      buf.writeln('  <!-- Viewport: ${placement.use} -->');
      buf.writeln(
        '  <g transform="translate(${placement.x}, ${placement.y}) scale(${view.scaleFactor}) translate(${-viewOriginX}, ${-viewOriginY})">',
      );
      RenderHierarchy.renderRootedObjects(
        objects: view.objects,
        objectLookup: view.objects,
        shouldRenderRole: shouldRenderRole,
        renderPrimitive: (obj, meta) => writePrimitive(
          buf,
          obj,
          meta,
          presentationalScale: presentationalScale,
        ),
        withTransformScope: (transforms, renderChild) {
          final transform = RenderHierarchy.transformToSvg(transforms);
          if (transform != null) {
            buf.writeln('      <g transform="$transform">');
          }
          renderChild();
          if (transform != null) {
            buf.writeln('      </g>');
          }
        },
      );
      buf.writeln('  </g>');
      buf.writeln(
        '  <rect x="${placement.x}" y="${placement.y}" width="${placement.width}" height="${placement.height}" fill="none" stroke="#666" stroke-width="${0.5 * mm}" stroke-dasharray="${2 * mm} ${2 * mm}" />',
      );
      buf.writeln(
        '  <text x="${placement.x}" y="${placement.y + placement.height + 8 * mm}" font-size="${6 * mm}px" font-family="sans-serif" fill="#666">${_escapeXml(placement.use)} (Scale ${_escapeXml(view.scale.toString())})</text>',
      );
    }

    final titleMeta = <String, dynamic>{
      ...?scene.meta?.extra,
      ...?sheet.meta?.extra,
    };
    final sheetNameText = _escapeXml(
      (titleMeta['title'] ?? sheetId).toString(),
    );
    final relgeoVersionText = _escapeXml(_activeRelGeoVersion);
    final documentVersionText = _escapeXml(
      (titleMeta['version'] ?? '-').toString(),
    );
    final dateText = _escapeXml((titleMeta['date'] ?? '-').toString());
    final sheetSizeText = _escapeXml(
      (titleMeta['sheetSize'] ?? (sheet.size is String ? sheet.size : 'Custom'))
          .toString(),
    );
    final tx = width - marginSize - 80 * mm;
    final ty = height - marginSize - 25 * mm;

    buf.writeln('  <g transform="translate($tx, $ty)">');
    buf.writeln(
      '    <rect x="0" y="0" width="${80 * mm}" height="${25 * mm}" fill="white" stroke="#333" stroke-width="${0.8 * mm}" />',
    );
    buf.writeln(
      '    <line x1="0" y1="${8 * mm}" x2="${80 * mm}" y2="${8 * mm}" stroke="#333" stroke-width="${0.5 * mm}" />',
    );
    buf.writeln(
      '    <line x1="${45 * mm}" y1="${8 * mm}" x2="${45 * mm}" y2="${25 * mm}" stroke="#333" stroke-width="${0.5 * mm}" />',
    );
    buf.writeln(
      '    <text x="${4 * mm}" y="${6 * mm}" font-size="${4.5 * mm}px" font-family="sans-serif" font-weight="bold" fill="#333">SHEET: $sheetNameText</text>',
    );
    buf.writeln(
      '    <text x="${4 * mm}" y="${14 * mm}" font-size="${3.5 * mm}px" font-family="sans-serif" fill="#666">RELGEO: $relgeoVersionText</text>',
    );
    buf.writeln(
      '    <text x="${4 * mm}" y="${20 * mm}" font-size="${3.5 * mm}px" font-family="sans-serif" fill="#666">DATE: $dateText</text>',
    );
    buf.writeln(
      '    <text x="${49 * mm}" y="${14 * mm}" font-size="${3.5 * mm}px" font-family="sans-serif" fill="#666">SIZE: $sheetSizeText</text>',
    );
    buf.writeln(
      '    <text x="${49 * mm}" y="${20 * mm}" font-size="${3.5 * mm}px" font-family="sans-serif" fill="#666">DOC VER: $documentVersionText</text>',
    );
    buf.writeln('  </g>');
    buf.writeln('</svg>');
    return buf.toString();
  }

  static void _writeSVGSegments(
    StringBuffer buf,
    List<PathResolvedSegment> segments,
    bool closed,
    String styleStr, {
    String attrs = '',
    String indent = '  ',
  }) {
    if (segments.isEmpty) return;
    final pd = StringBuffer();
    bool first = true;
    for (final seg in segments) {
      switch (seg) {
        case LineSegment(:final x1, :final y1, :final x2, :final y2):
          if (first) {
            pd.write('M $x1 $y1 ');
            first = false;
          }
          pd.write('L $x2 $y2 ');
        case ArcSegment(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final radius,
          :final largeArc,
          :final sweep,
        ):
          if (first) {
            pd.write('M $x1 $y1 ');
            first = false;
          }
          pd.write('A $radius $radius 0 $largeArc $sweep $x2 $y2 ');
        case QuadraticSegment(
          :final x1,
          :final y1,
          :final cpx,
          :final cpy,
          :final x2,
          :final y2,
        ):
          if (first) {
            pd.write('M $x1 $y1 ');
            first = false;
          }
          pd.write('Q $cpx $cpy $x2 $y2 ');
        case CubicSegment(
          :final x1,
          :final y1,
          :final cp1x,
          :final cp1y,
          :final cp2x,
          :final cp2y,
          :final x2,
          :final y2,
        ):
          if (first) {
            pd.write('M $x1 $y1 ');
            first = false;
          }
          pd.write('C $cp1x $cp1y $cp2x $cp2y $x2 $y2 ');
      }
    }
    if (closed) pd.write('Z');
    final attrPrefix = attrs.isEmpty ? '' : '$attrs ';
    buf.writeln('$indent<path ${attrPrefix}d="${pd.toString()}" $styleStr />');
  }
}
