import 'dart:math' as math;

import 'package:relgeo_flutter/relgeo_flutter.dart';

import 'render_typography.dart';

class ArrowheadLayout {
  final Point2D tip;
  final Point2D wing1;
  final Point2D wing2;

  const ArrowheadLayout({
    required this.tip,
    required this.wing1,
    required this.wing2,
  });
}

class AnnotationLeaderLayout {
  final Point2D from;
  final Point2D to;
  final ArrowheadLayout? arrowhead;
  final bool isLeft;
  final double anchorLineEndX;
  final double textX;
  final double textY;

  const AnnotationLeaderLayout({
    required this.from,
    required this.to,
    required this.arrowhead,
    required this.isLeft,
    required this.anchorLineEndX,
    required this.textX,
    required this.textY,
  });
}

class AnnotationPlacementLayout {
  final double textX;
  final double textY;

  const AnnotationPlacementLayout({required this.textX, required this.textY});
}

class RenderLineSegment {
  final Point2D from;
  final Point2D to;

  const RenderLineSegment({required this.from, required this.to});
}

class LinearDimensionLayout {
  final RenderLineSegment extension1;
  final RenderLineSegment extension2;
  final RenderLineSegment dimensionLine;
  final ArrowheadLayout arrowStart;
  final ArrowheadLayout arrowEnd;
  final double labelX;
  final double labelY;
  final double labelRotationDeg;
  final double labelOffset;

  const LinearDimensionLayout({
    required this.extension1,
    required this.extension2,
    required this.dimensionLine,
    required this.arrowStart,
    required this.arrowEnd,
    required this.labelX,
    required this.labelY,
    required this.labelRotationDeg,
    required this.labelOffset,
  });
}

class RadialDimensionLayout {
  final RenderLineSegment baseLine;
  final ArrowheadLayout arrowPrimary;
  final ArrowheadLayout? arrowSecondary;
  final RenderLineSegment leader1;
  final RenderLineSegment leader2;
  final double textX;
  final double textY;

  const RadialDimensionLayout({
    required this.baseLine,
    required this.arrowPrimary,
    required this.arrowSecondary,
    required this.leader1,
    required this.leader2,
    required this.textX,
    required this.textY,
  });
}

class AngleDimensionLayout {
  final Point2D center;
  final double radius;
  final double startAngle;
  final double sweepAngle;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double textX;
  final double textY;

  const AngleDimensionLayout({
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.sweepAngle,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.textX,
    required this.textY,
  });
}

class RenderPresentational {
  static const double annotationArrowLength = 7.0;
  static const double annotationArrowWidth = 2.5;
  static const double annotationGap = 4.0;

  static ArrowheadLayout? arrowheadFromSegment(
    Point2D tip,
    Point2D toward, {
    required double length,
    required double width,
  }) {
    final dx = toward.x - tip.x;
    final dy = toward.y - tip.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len <= 0) return null;

    final ux = dx / len;
    final uy = dy / len;
    final vx = -uy;
    final vy = ux;

    return ArrowheadLayout(
      tip: tip,
      wing1: (
        x: tip.x + length * ux + width * vx,
        y: tip.y + length * uy + width * vy,
      ),
      wing2: (
        x: tip.x + length * ux - width * vx,
        y: tip.y + length * uy - width * vy,
      ),
    );
  }

  static AnnotationLeaderLayout annotationLeaderLayout({
    required Point2D from,
    required Point2D to,
    required String text,
    required double fontSize,
    double arrowLength = annotationArrowLength,
    double arrowWidth = annotationArrowWidth,
    double gap = annotationGap,
  }) {
    final arrowhead = arrowheadFromSegment(
      from,
      to,
      length: arrowLength,
      width: arrowWidth,
    );
    final isLeft = to.x < from.x;
    final approxTextWidth = RenderTypography.approxTextWidth(text, fontSize);
    final anchorLineEndX = isLeft
        ? to.x - approxTextWidth - gap
        : to.x + approxTextWidth + gap;
    final textX = isLeft ? to.x - approxTextWidth - gap : to.x + gap;

    return AnnotationLeaderLayout(
      from: from,
      to: to,
      arrowhead: arrowhead,
      isLeft: isLeft,
      anchorLineEndX: anchorLineEndX,
      textX: textX,
      textY: to.y,
    );
  }

  static AnnotationPlacementLayout annotationTargetFallbackLayout({
    required BoundingBox targetBBox,
    required String text,
    required double fontSize,
    double gap = annotationGap,
  }) {
    final textWidth = RenderTypography.approxTextWidth(text, fontSize);
    final textX = targetBBox.x + targetBBox.width + gap;
    final textY = targetBBox.y + (targetBBox.height - fontSize) / 2;
    return AnnotationPlacementLayout(
      textX: textWidth.isFinite ? textX : targetBBox.x + targetBBox.width + gap,
      textY: textY.isFinite ? textY : targetBBox.y,
    );
  }

  static LinearDimensionLayout? linearDimensionLayout({
    required Point2D from,
    required Point2D to,
    required double offset,
    required double arrowLength,
    required double arrowWidth,
  }) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len <= 0) return null;

    final ux = dx / len;
    final uy = dy / len;
    final vx = -uy;
    final vy = ux;

    final d1 = (x: from.x + offset * vx, y: from.y + offset * vy);
    final d2 = (x: to.x + offset * vx, y: to.y + offset * vy);

    final gapMag = math.min(arrowLength * 0.3, offset.abs() * 0.5);
    final signedUnit = offset == 0 ? 1.0 : offset.sign;
    final gap = gapMag * signedUnit;
    final extLen = offset + arrowLength * 0.5 * signedUnit;
    final e1s = (x: from.x + gap * vx, y: from.y + gap * vy);
    final e1e = (x: from.x + extLen * vx, y: from.y + extLen * vy);
    final e2s = (x: to.x + gap * vx, y: to.y + gap * vy);
    final e2e = (x: to.x + extLen * vx, y: to.y + extLen * vy);

    final arrowStart = arrowheadFromSegment(
      d1,
      d2,
      length: arrowLength,
      width: arrowWidth,
    );
    final rawArrowEnd = arrowheadFromSegment(
      d2,
      d1,
      length: arrowLength,
      width: arrowWidth,
    );
    if (arrowStart == null || rawArrowEnd == null) return null;
    final arrowEnd = ArrowheadLayout(
      tip: rawArrowEnd.tip,
      wing1: rawArrowEnd.wing2,
      wing2: rawArrowEnd.wing1,
    );

    var labelRotationDeg = math.atan2(dy, dx) * 180 / math.pi;
    if (labelRotationDeg > 90 || labelRotationDeg < -90) {
      labelRotationDeg += 180;
    }

    return LinearDimensionLayout(
      extension1: RenderLineSegment(from: e1s, to: e1e),
      extension2: RenderLineSegment(from: e2s, to: e2e),
      dimensionLine: RenderLineSegment(from: d1, to: d2),
      arrowStart: arrowStart,
      arrowEnd: arrowEnd,
      labelX: (d1.x + d2.x) / 2,
      labelY: (d1.y + d2.y) / 2,
      labelRotationDeg: labelRotationDeg,
      labelOffset: arrowLength,
    );
  }

  static RadialDimensionLayout? radialDimensionLayout({
    required Point2D center,
    required double radius,
    required double arrowLength,
    required double arrowWidth,
    required bool diameter,
  }) {
    const angleRad = math.pi / 4;
    final ux = math.cos(angleRad);
    final uy = math.sin(angleRad);
    final vx = -uy;
    final vy = ux;

    final point = (x: center.x + radius * ux, y: center.y + radius * uy);
    final farPoint = (x: center.x - radius * ux, y: center.y - radius * uy);

    final arrowPrimary = arrowheadFromSegment(
      point,
      center,
      length: arrowLength,
      width: arrowWidth,
    );
    if (arrowPrimary == null) return null;

    final arrowSecondary = diameter
        ? arrowheadFromSegment(
            farPoint,
            center,
            length: arrowLength,
            width: arrowWidth,
          )
        : null;
    if (diameter && arrowSecondary == null) return null;

    final elbow = (
      x: point.x + arrowLength * 1.5 * ux,
      y: point.y + arrowLength * 1.5 * uy,
    );
    final leaderEnd = (x: elbow.x + arrowLength * 2.5, y: elbow.y);

    return RadialDimensionLayout(
      baseLine: RenderLineSegment(
        from: diameter ? farPoint : center,
        to: point,
      ),
      arrowPrimary: arrowPrimary,
      arrowSecondary: arrowSecondary,
      leader1: RenderLineSegment(from: point, to: elbow),
      leader2: RenderLineSegment(from: elbow, to: leaderEnd),
      textX: leaderEnd.x + arrowLength * 0.3,
      textY: leaderEnd.y,
    );
  }

  static AngleDimensionLayout? angleDimensionLayout({
    required ResolvedLine line1,
    required ResolvedLine line2,
    required double scaleRef,
    required double arrowLength,
    double presentationalScale = 1.0,
  }) {
    final a1 = math.atan2(line1.y2 - line1.y1, line1.x2 - line1.x1);
    final a2 = math.atan2(line2.y2 - line2.y1, line2.x2 - line2.x1);
    final center = (x: line1.x1, y: line1.y1);
    final safeScale = presentationalScale > 0 ? presentationalScale : 1.0;
    final radius = math.max(scaleRef * 0.1, 20.0) / safeScale;
    final sweep = normalizeAngleSweep(a1, a2);
    final midA = a1 + sweep / 2;

    return AngleDimensionLayout(
      center: center,
      radius: radius,
      startAngle: a1,
      sweepAngle: sweep,
      startX: center.x + radius * math.cos(a1),
      startY: center.y + radius * math.sin(a1),
      endX: center.x + radius * math.cos(a2),
      endY: center.y + radius * math.sin(a2),
      textX: center.x + (radius + arrowLength * 1.5) * math.cos(midA),
      textY: center.y + (radius + arrowLength * 1.5) * math.sin(midA),
    );
  }

  static double normalizeAngleSweep(double start, double end) {
    var sweep = end - start;
    while (sweep <= -math.pi) {
      sweep += 2 * math.pi;
    }
    while (sweep > math.pi) {
      sweep -= 2 * math.pi;
    }
    return sweep;
  }
}
