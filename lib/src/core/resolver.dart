import 'dart:math' as math;
import '../geometry/types.dart';
import '../geometry/transforms.dart';
import '../geometry/utils.dart' as geom;
import '../geometry/clipper_boolean.dart';
import '../geometry/path_modifiers.dart' as pm;
import 'units.dart';
import 'evaluator.dart';
import 'graph.dart';
import 'constraints.dart' as cst;

/// Compiler Geometri dan Resolusi Scene RelGeo.
///
/// Modul ini mengambil input spesifikasi YAML yang telah diparsing, menyusun urutan dependensi
/// topologis terpadu antara variabel derived dan objek geometri, lalu melakukan kalkulasi analitis,
/// penempatan (placement), transformasi, resolusi anchor kustom, serta kalkulasi viewport sheet.

class TextMetrics {
  final double width;
  final double height;
  TextMetrics({required this.width, required this.height});
}

class TextMetricsProvider {
  TextMetrics measure({
    required String content,
    required double fontSize,
    String? fontFamily,
    dynamic fontWeight,
    String? fontStyle,
    required double lineHeight,
  }) {
    final lines = content.split('\n');
    double maxWidth = 0.0;
    for (final line in lines) {
      final w = line.length * fontSize * 0.6;
      if (w > maxWidth) maxWidth = w;
    }
    final totalHeight = lines.length * fontSize * lineHeight;
    return TextMetrics(width: maxWidth, height: totalHeight);
  }
}

double _parseTypographicScalar(dynamic raw, double defaultValue) {
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

class ResolveOptions {
  final LengthUnit? targetUnit;
  final String? profile;
  final Map<String, dynamic>? overrides;
  final TextMetricsProvider? textMetrics;
  final String mode; // 'compile' | 'validate' | 'editor'

  ResolveOptions({
    this.targetUnit,
    this.profile,
    this.overrides,
    this.textMetrics,
    this.mode = 'compile',
  });
}

class ResolveContext {
  final Map<String, dynamic> scalars;
  final Map<String, ResolvedObject> objects;
  final LengthUnit targetUnit;
  final Map<String, String> parentMap;
  final String mode;
  final TextMetricsProvider textMetrics;
  final Map<dynamic, dynamic> doc;
  String? currentObjectId;

  ResolveContext({
    required this.scalars,
    required this.objects,
    required this.targetUnit,
    required this.parentMap,
    required this.mode,
    required this.textMetrics,
    required this.doc,
    this.currentObjectId,
  });
}

/// Implementasi EvalContext yang menghubungkan Evaluator matematika ke resolusi anchor geometri.
class ResolverEvalContext implements EvalContext {
  @override
  final Map<String, dynamic> scalars;
  @override
  final LengthUnit targetUnit;
  @override
  final Map<String, ResolvedObject> objects;
  @override
  final Map<String, String> parentMap;
  final ResolveContext ctx;

  ResolverEvalContext(this.ctx)
    : scalars = ctx.scalars,
      targetUnit = ctx.targetUnit,
      objects = ctx.objects,
      parentMap = ctx.parentMap;

  @override
  TypedValue? get(String name) {
    if (scalars.containsKey(name)) {
      return wrap(scalars[name]);
    }
    if (objects.containsKey(name)) {
      return TypedValue(type: 'object', value: objects[name]);
    }
    return null;
  }

  @override
  TypedValue? getMember(TypedValue value, String key) {
    final val = value.value;
    if (value.type == 'frame2d') {
      if (val is Map && val.containsKey(key)) {
        return wrap(val[key]);
      }
      return null;
    }

    if (val is ResolvedObject) {
      if (key == 'holes' && val is ResolvedRect) {
        return wrap(val.holes);
      }
      if (key == 'holes' && val is ResolvedCircle) {
        return wrap(val.holes);
      }
      if (key == 'holes' && val is ResolvedEllipse) {
        return wrap(val.holes);
      }
      if (key == 'holes' && val is ResolvedPolygon) {
        return wrap(val.holes);
      }
      if (key == 'holes' && val is ResolvedPath) {
        return wrap(val.holes);
      }
      if (key == 'holes' && val is ResolvedBoolean) {
        return wrap(val.holes);
      }

      if (val is ResolvedComponent) {
        if (val.anchors.containsKey(key)) {
          return wrap(val.anchors[key]);
        }
        final childId = '${val.id}.$key';
        if (objects.containsKey(childId)) {
          return wrap(objects[childId]);
        }
        return null;
      }

      try {
        final anchorVal = getAnchorValue(val, key, ctx);
        if (anchorVal != null) {
          return wrap(anchorVal);
        }
      } catch (e) {
        // Fallback ke check field generic
      }
    }

    if (val is Map && val.containsKey(key)) {
      return wrap(val[key]);
    }

    return null;
  }

  @override
  TypedValue? getIndex(TypedValue value, dynamic index) {
    final val = value.value;
    if (value.type == 'object' && val is ResolvedCollection) {
      if (index is List && index.length == 2) {
        final childId = '${val.id}[${index[0]},${index[1]}]';
        final childObj = objects[childId];
        if (childObj != null) {
          return wrap(childObj);
        }
      } else {
        final idx = index is num ? index.toInt() : int.parse(index.toString());
        if (idx >= 0 && idx < val.children.length) {
          final childId = val.children[idx];
          final childObj = objects[childId];
          if (childObj != null) {
            return wrap(childObj);
          }
        }
      }
    }

    if (val is List) {
      final idx = index is num ? index.toInt() : int.parse(index.toString());
      if (idx >= 0 && idx < val.length) {
        return wrap(val[idx]);
      }
    }

    return null;
  }

  @override
  TypedValue? callFunction(String name, List<TypedValue> args) {
    if (name == 'count') {
      if (args.isEmpty) {
        throw Exception('count() requires exactly one argument');
      }
      final arg = args[0];
      if (arg.type == 'array' && arg.value is List) {
        return wrap((arg.value as List).length);
      }
      final val = arg.value;
      if (val is ResolvedCollection) {
        return wrap(val.children.length);
      }
      if (val is List) {
        return wrap(val.length);
      }
      throw Exception('count() argument must be a list or collection');
    }

    if (name == 'first') {
      if (args.isEmpty) {
        throw Exception('first() requires exactly one argument');
      }
      final arg = args[0];
      if (arg.type == 'array' && arg.value is List) {
        final list = arg.value as List;
        if (list.isEmpty) throw Exception('first() called on empty list');
        return wrap(list.first);
      }
      final val = arg.value;
      if (val is ResolvedCollection) {
        if (val.children.isEmpty) {
          throw Exception('first() called on empty collection');
        }
        final childObj = objects[val.children.first];
        if (childObj != null) return wrap(childObj);
      }
      if (val is List) {
        if (val.isEmpty) throw Exception('first() called on empty list');
        return wrap(val.first);
      }
      throw Exception('first() argument must be a list or collection');
    }

    if (name == 'last') {
      if (args.isEmpty) throw Exception('last() requires exactly one argument');
      final arg = args[0];
      if (arg.type == 'array' && arg.value is List) {
        final list = arg.value as List;
        if (list.isEmpty) throw Exception('last() called on empty list');
        return wrap(list.last);
      }
      final val = arg.value;
      if (val is ResolvedCollection) {
        if (val.children.isEmpty) {
          throw Exception('last() called on empty collection');
        }
        final childObj = objects[val.children.last];
        if (childObj != null) return wrap(childObj);
      }
      if (val is List) {
        if (val.isEmpty) throw Exception('last() called on empty list');
        return wrap(val.last);
      }
      throw Exception('last() argument must be a list or collection');
    }

    return null;
  }

  @override
  dynamic resolveIdentifier(String name) {
    if (scalars.containsKey(name)) {
      return scalars[name];
    }
    return null;
  }
}

/// Helper untuk membuat EvalContext dari ResolveContext.
ResolverEvalContext createEvalContext(ResolveContext ctx) {
  return ResolverEvalContext(ctx);
}

// ─────────────────────────────────────────────
// Resolusi Anchor (anchors.dart setara)
// ─────────────────────────────────────────────

Point2D? getAnchorPoint(Point2D val) => val;

Point2D? toPoint2D(dynamic val) {
  if (val is Point2D) return val;
  if (val is ResolvedPoint) {
    return (x: val.x, y: val.y);
  }
  if (val is ResolvedRect) {
    return (x: val.x + val.width / 2.0, y: val.y + val.height / 2.0);
  }
  if (val is ResolvedCircle) {
    return (x: val.cx, y: val.cy);
  }
  if (val is ResolvedEllipse) {
    return (x: val.cx, y: val.cy);
  }
  if (val is ResolvedLine) {
    return (x: (val.x1 + val.x2) / 2.0, y: (val.y1 + val.y2) / 2.0);
  }
  if (val is Map) {
    final xVal = val['x'];
    final yVal = val['y'];
    if (xVal is num && yVal is num) {
      return (x: xVal.toDouble(), y: yVal.toDouble());
    }
  }
  return null;
}

bool isClosedPathLikeObject(ResolvedObject obj) {
  return obj is ResolvedCircle ||
      obj is ResolvedEllipse ||
      obj is ResolvedRect ||
      obj is ResolvedPolygon ||
      (obj is ResolvedPath && obj.closed);
}

bool hasExplicitRepeatPosition(Map<dynamic, dynamic> item) {
  return item.containsKey('place') ||
      item.containsKey('on') ||
      item.containsKey('at') ||
      item.containsKey('center') ||
      item.containsKey('from') ||
      item.containsKey('to') ||
      item.containsKey('through') ||
      item.containsKey('points') ||
      item.containsKey('segments');
}

bool isPointLike(dynamic val) {
  return val is Map && val.containsKey('x') && val.containsKey('y');
}

/// Menghitung/mengambil nilai anchor geometri.
dynamic resolveAnchorValue(dynamic ref, ResolveContext ctx) {
  if (ref is num) return ref.toDouble();
  if (ref is List && ref.length == 2) {
    final evalCtx = createEvalContext(ctx);
    final Evaluator evaluator = Evaluator(evalCtx);
    return (
      x: normalizeUnit(evaluator.evaluate(ref[0]), ctx.targetUnit),
      y: normalizeUnit(evaluator.evaluate(ref[1]), ctx.targetUnit),
    );
  }
  if (ref is! String) return ref;

  final evalCtx = createEvalContext(ctx);
  final Evaluator evaluator = Evaluator(evalCtx);

  // Jika identifier murni melambangkan object ID, default ke anchor 'center'
  if (!RegExp(r'[+\-*/()\[\.]').hasMatch(ref)) {
    final target = ctx.objects[ref];
    if (target != null) {
      return getAnchorValue(target, 'center', ctx);
    }
  }

  try {
    final result = evaluator.evaluate(ref);
    return result;
  } catch (e) {
    throw Exception('Error resolving expression: $ref: $e');
  }
}

dynamic getAnchorValue(ResolvedObject obj, String anchor, ResolveContext ctx) {
  dynamic val = getRawAnchorValue(obj, anchor, ctx);

  // Aturan Koordinat Ruang Lokal (Local Coordinate Space)
  if (ctx.currentObjectId != null && obj.id.isNotEmpty) {
    if (val is Point2D) {
      val = applyTransformsToPoint(val, obj.id, ctx);
    } else if (val is num) {
      final double numVal = val.toDouble();
      final axis = getAnchorAxis(anchor);
      if (axis == 'x') {
        final refY =
            (getRawAnchorValue(obj, 'centerY', ctx) ??
                    getRawAnchorValue(obj, 'y', ctx) ??
                    0.0)
                as double;
        final p = applyTransformsToPoint((x: numVal, y: refY), obj.id, ctx);
        val = p.x;
      } else if (axis == 'y') {
        final refX =
            (getRawAnchorValue(obj, 'centerX', ctx) ??
                    getRawAnchorValue(obj, 'x', ctx) ??
                    0.0)
                as double;
        final p = applyTransformsToPoint((x: refX, y: numVal), obj.id, ctx);
        val = p.y;
      }
    }
  }

  return val;
}

String? getAnchorAxis(String anchor) {
  if (['left', 'right', 'centerX', 'x', 'cx'].contains(anchor) ||
      anchor.endsWith('.x')) {
    return 'x';
  }
  if (['top', 'bottom', 'centerY', 'y', 'cy'].contains(anchor) ||
      anchor.endsWith('.y')) {
    return 'y';
  }
  return null;
}

List<Point2D> pointsFromSegments(List<PathResolvedSegment> segments) {
  if (segments.isEmpty) return [];
  final List<Point2D> points = [];
  for (int i = 0; i < segments.length; i++) {
    final sampled = geom.sampleSegmentLikePoints(segments[i]);
    if (i == 0) {
      points.addAll(sampled);
    } else {
      points.addAll(sampled.sublist(1));
    }
  }
  return points;
}

dynamic getRawAnchorValue(
  ResolvedObject obj,
  String anchor,
  ResolveContext ctx,
) {
  if (obj.anchors.containsKey(anchor)) {
    return obj.anchors[anchor];
  }

  switch (obj) {
    case ResolvedPoint(:final x, :final y):
      if (anchor == 'x') return x;
      if (anchor == 'y') return y;
      if (anchor == 'center') return (x: x, y: y);

    case ResolvedRect(
      :final x,
      :final y,
      :final width,
      :final height,
      :final holes,
    ):
      if (anchor == 'left' || anchor == 'x') return x;
      if (anchor == 'right') return x + width;
      if (anchor == 'top' || anchor == 'y') return y;
      if (anchor == 'bottom') return y + height;
      if (anchor == 'width') return width;
      if (anchor == 'height') return height;
      if (anchor == 'centerX') return x + width / 2;
      if (anchor == 'centerY') return y + height / 2;
      if (anchor == 'center') return (x: x + width / 2, y: y + height / 2);
      if (anchor == 'topLeft') return (x: x, y: y);
      if (anchor == 'topRight') return (x: x + width, y: y);
      if (anchor == 'bottomLeft') return (x: x, y: y + height);
      if (anchor == 'bottomRight') return (x: x + width, y: y + height);
      if (anchor == 'topCenter') return (x: x + width / 2, y: y);
      if (anchor == 'bottomCenter') return (x: x + width / 2, y: y + height);
      if (anchor == 'centerLeft') return (x: x, y: y + height / 2);
      if (anchor == 'centerRight') return (x: x + width, y: y + height / 2);
      if (anchor == 'area') {
        double a = width * height;
        for (final h in holes) {
          a -= geom.polygonArea(pointsFromSegments(h.segments));
        }
        return math.max(0.0, a);
      }

    case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
      if (anchor == 'start') return (x: x1, y: y1);
      if (anchor == 'end') return (x: x2, y: y2);
      if (anchor == 'center') return (x: (x1 + x2) / 2, y: (y1 + y2) / 2);
      if (anchor == 'length') return geom.hypot(x2 - x1, y2 - y1);

    case ResolvedCircle(:final cx, :final cy, :final radius, :final holes):
      if (anchor == 'cx' || anchor == 'x') return cx;
      if (anchor == 'cy' || anchor == 'y') return cy;
      if (anchor == 'radius' || anchor == 'r') return radius;
      if (anchor == 'left') return cx - radius;
      if (anchor == 'right') return cx + radius;
      if (anchor == 'top') return cy - radius;
      if (anchor == 'bottom') return cy + radius;
      if (anchor == 'centerX') return cx;
      if (anchor == 'centerY') return cy;
      if (anchor == 'width') return radius * 2;
      if (anchor == 'height') return radius * 2;
      if (anchor == 'center') return (x: cx, y: cy);
      if (anchor == 'topLeft') return (x: cx - radius, y: cy - radius);
      if (anchor == 'topCenter') return (x: cx, y: cy - radius);
      if (anchor == 'topRight') return (x: cx + radius, y: cy - radius);
      if (anchor == 'centerLeft') return (x: cx - radius, y: cy);
      if (anchor == 'centerRight') return (x: cx + radius, y: cy);
      if (anchor == 'bottomLeft') return (x: cx - radius, y: cy + radius);
      if (anchor == 'bottomCenter') return (x: cx, y: cy + radius);
      if (anchor == 'bottomRight') return (x: cx + radius, y: cy + radius);
      if (anchor == 'area') {
        double a = math.pi * radius * radius;
        for (final h in holes) {
          a -= geom.polygonArea(pointsFromSegments(h.segments));
        }
        return math.max(0.0, a);
      }

    case ResolvedEllipse(
      :final cx,
      :final cy,
      :final rx,
      :final ry,
      :final rotation,
      :final holes,
    ):
      final cosR = math.cos(rotation);
      final sinR = math.sin(rotation);
      final halfWidth = math.sqrt(
        (rx * cosR) * (rx * cosR) + (ry * sinR) * (ry * sinR),
      );
      final halfHeight = math.sqrt(
        (rx * sinR) * (rx * sinR) + (ry * cosR) * (ry * cosR),
      );
      if (anchor == 'cx' || anchor == 'x') return cx;
      if (anchor == 'cy' || anchor == 'y') return cy;
      if (anchor == 'rx') return rx;
      if (anchor == 'ry') return ry;
      if (anchor == 'rotation') return rotation;
      if (anchor == 'left') return cx - halfWidth;
      if (anchor == 'right') return cx + halfWidth;
      if (anchor == 'top') return cy - halfHeight;
      if (anchor == 'bottom') return cy + halfHeight;
      if (anchor == 'centerX') return cx;
      if (anchor == 'centerY') return cy;
      if (anchor == 'width') return halfWidth * 2;
      if (anchor == 'height') return halfHeight * 2;
      if (anchor == 'center') return (x: cx, y: cy);
      if (anchor == 'topLeft') return (x: cx - halfWidth, y: cy - halfHeight);
      if (anchor == 'topCenter') return (x: cx, y: cy - halfHeight);
      if (anchor == 'topRight') return (x: cx + halfWidth, y: cy - halfHeight);
      if (anchor == 'centerLeft') return (x: cx - halfWidth, y: cy);
      if (anchor == 'centerRight') return (x: cx + halfWidth, y: cy);
      if (anchor == 'bottomLeft') {
        return (x: cx - halfWidth, y: cy + halfHeight);
      }
      if (anchor == 'bottomCenter') return (x: cx, y: cy + halfHeight);
      if (anchor == 'bottomRight') {
        return (x: cx + halfWidth, y: cy + halfHeight);
      }
      if (anchor == 'area') {
        double a = math.pi * rx * ry;
        for (final h in holes) {
          a -= geom.polygonArea(pointsFromSegments(h.segments));
        }
        return math.max(0.0, a);
      }
      if (anchor == 'perimeter') {
        final h = math.pow(rx - ry, 2) / math.pow(rx + ry, 2);
        return math.pi *
            (rx + ry) *
            (1 + (3 * h) / (10 + math.sqrt(4 - 3 * h)));
      }

    case ResolvedArc(
      :final x1,
      :final y1,
      :final x2,
      :final y2,
      :final cx,
      :final cy,
      :final radius,
      :final startAngle,
      :final endAngle,
    ):
      if (anchor == 'start') return (x: x1, y: y1);
      if (anchor == 'end') return (x: x2, y: y2);
      if (anchor == 'center') return (x: cx, y: cy);
      if (anchor == 'cx' || anchor == 'x') return cx;
      if (anchor == 'cy' || anchor == 'y') return cy;
      if (anchor == 'radius' || anchor == 'r') return radius;
      if (anchor == 'length') return radius * (endAngle - startAngle).abs();

    case ResolvedQuadratic(
      :final x1,
      :final y1,
      :final cpx,
      :final cpy,
      :final x2,
      :final y2,
    ):
      if (anchor == 'start') return (x: x1, y: y1);
      if (anchor == 'cp') return (x: cpx, y: cpy);
      if (anchor == 'end') return (x: x2, y: y2);
      if (anchor == 'center') {
        return (x: (x1 + cpx + x2) / 3, y: (y1 + cpy + y2) / 3);
      }
      if (anchor == 'length') {
        return geom.approximateQuadraticLength(
          (x: x1, y: y1),
          (x: cpx, y: cpy),
          (x: x2, y: y2),
        );
      }

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
      if (anchor == 'start') return (x: x1, y: y1);
      if (anchor == 'cp1') return (x: cp1x, y: cp1y);
      if (anchor == 'cp2') return (x: cp2x, y: cp2y);
      if (anchor == 'end') return (x: x2, y: y2);
      if (anchor == 'center') {
        return (x: (x1 + cp1x + cp2x + x2) / 4, y: (y1 + cp1y + cp2y + y2) / 4);
      }
      if (anchor == 'length') {
        return geom.approximateCubicLength(
          (x: x1, y: y1),
          (x: cp1x, y: cp1y),
          (x: cp2x, y: cp2y),
          (x: x2, y: y2),
        );
      }

    case ResolvedPath(
      :final points,
      :final segments,
      :final closed,
      :final holes,
    ):
      final pathPoints = segments.isNotEmpty
          ? pointsFromSegments(segments)
          : points;
      if (pathPoints.isNotEmpty) {
        final bbox = geom.calculateBoundingBox({obj.id: obj});
        if (anchor == 'left' || anchor == 'x') return bbox.x;
        if (anchor == 'right') return bbox.x + bbox.width;
        if (anchor == 'top' || anchor == 'y') return bbox.y;
        if (anchor == 'bottom') return bbox.y + bbox.height;
        if (anchor == 'width') return bbox.width;
        if (anchor == 'height') return bbox.height;
        if (anchor == 'centerX') return bbox.x + bbox.width / 2;
        if (anchor == 'centerY') return bbox.y + bbox.height / 2;
        if (anchor == 'center') {
          return (x: bbox.x + bbox.width / 2, y: bbox.y + bbox.height / 2);
        }
        if (anchor == 'start') return pathPoints.first;
        if (anchor == 'end') return pathPoints.last;
        if (anchor == 'length') return geom.polylineLength(pathPoints, closed);
        if (anchor == 'area') {
          double a = geom.polygonArea(pathPoints);
          for (final h in holes) {
            a -= geom.polygonArea(pointsFromSegments(h.segments));
          }
          return math.max(0.0, a);
        }
      }

    case ResolvedPolygon(:final points, :final segments, :final holes):
      final polyPoints = segments.isNotEmpty
          ? pointsFromSegments(segments)
          : points;
      final bbox = geom.calculateBoundingBox({obj.id: obj});
      if (anchor == 'left' || anchor == 'x') return bbox.x;
      if (anchor == 'right') return bbox.x + bbox.width;
      if (anchor == 'top' || anchor == 'y') return bbox.y;
      if (anchor == 'bottom') return bbox.y + bbox.height;
      if (anchor == 'width') return bbox.width;
      if (anchor == 'height') return bbox.height;
      if (anchor == 'centerX') return bbox.x + bbox.width / 2;
      if (anchor == 'centerY') return bbox.y + bbox.height / 2;
      if (anchor == 'center') {
        return (x: bbox.x + bbox.width / 2, y: bbox.y + bbox.height / 2);
      }
      if (anchor == 'area') {
        double a = geom.polygonArea(polyPoints);
        for (final h in holes) {
          a -= geom.polygonArea(pointsFromSegments(h.segments));
        }
        return math.max(0.0, a);
      }

    case ResolvedBoolean():
      final bbox = geom.calculateBoundingBox({obj.id: obj});
      if (anchor == 'left' || anchor == 'x') return bbox.x;
      if (anchor == 'right') return bbox.x + bbox.width;
      if (anchor == 'top' || anchor == 'y') return bbox.y;
      if (anchor == 'bottom') return bbox.y + bbox.height;
      if (anchor == 'width') return bbox.width;
      if (anchor == 'height') return bbox.height;
      if (anchor == 'centerX') return bbox.x + bbox.width / 2;
      if (anchor == 'centerY') return bbox.y + bbox.height / 2;
      if (anchor == 'center') {
        return (x: bbox.x + bbox.width / 2, y: bbox.y + bbox.height / 2);
      }

    case ResolvedText(:final x, :final y, :final width, :final height):
      if (anchor == 'x' || anchor == 'left') return x;
      if (anchor == 'y' || anchor == 'top') return y;
      if (anchor == 'right') return x + width;
      if (anchor == 'bottom') return y + height;
      if (anchor == 'centerX') return x + width / 2;
      if (anchor == 'centerY') return y + height / 2;
      if (anchor == 'center') return (x: x + width / 2, y: y + height / 2);
      if (anchor == 'topLeft') return (x: x, y: y);
      if (anchor == 'topCenter') return (x: x + width / 2, y: y);
      if (anchor == 'topRight') return (x: x + width, y: y);
      if (anchor == 'centerLeft') return (x: x, y: y + height / 2);
      if (anchor == 'centerRight') return (x: x + width, y: y + height / 2);
      if (anchor == 'bottomLeft') return (x: x, y: y + height);
      if (anchor == 'bottomCenter') return (x: x + width / 2, y: y + height);
      if (anchor == 'bottomRight') return (x: x + width, y: y + height);

    case BaseResolvedGroup():
      final bbox = geom.calculateBoundingBox(
        ctx.objects,
        targetIds: obj.children,
      );
      if (anchor == 'left' || anchor == 'x') return bbox.x;
      if (anchor == 'right') return bbox.x + bbox.width;
      if (anchor == 'top' || anchor == 'y') return bbox.y;
      if (anchor == 'bottom') return bbox.y + bbox.height;
      if (anchor == 'width') return bbox.width;
      if (anchor == 'height') return bbox.height;
      if (anchor == 'centerX') return bbox.x + bbox.width / 2;
      if (anchor == 'centerY') return bbox.y + bbox.height / 2;
      if (anchor == 'center') {
        return (x: bbox.x + bbox.width / 2, y: bbox.y + bbox.height / 2);
      }
      if (anchor == 'topLeft') return (x: bbox.x, y: bbox.y);
      if (anchor == 'topCenter') return (x: bbox.x + bbox.width / 2, y: bbox.y);
      if (anchor == 'topRight') return (x: bbox.x + bbox.width, y: bbox.y);
      if (anchor == 'centerLeft') {
        return (x: bbox.x, y: bbox.y + bbox.height / 2);
      }
      if (anchor == 'centerRight') {
        return (x: bbox.x + bbox.width, y: bbox.y + bbox.height / 2);
      }
      if (anchor == 'bottomLeft') return (x: bbox.x, y: bbox.y + bbox.height);
      if (anchor == 'bottomCenter') {
        return (x: bbox.x + bbox.width / 2, y: bbox.y + bbox.height);
      }
      if (anchor == 'bottomRight') {
        return (x: bbox.x + bbox.width, y: bbox.y + bbox.height);
      }

    default:
      return null;
  }

  return null;
}

Point2D applyTransformsToPoint(
  Point2D point,
  String targetId,
  ResolveContext ctx,
) {
  Point2D p = point;
  final targetPath = getParentChain(targetId, ctx.parentMap);
  final requesterPath = getParentChain(
    ctx.currentObjectId ?? '',
    ctx.parentMap,
  );

  String? commonAncestor;
  for (final id in targetPath) {
    if (requesterPath.contains(id)) {
      commonAncestor = id;
      break;
    }
  }

  String? itId = targetId;
  while (itId != null && itId != commonAncestor) {
    final obj = ctx.objects[itId];
    if (obj != null && obj.transforms.isNotEmpty) {
      p = applyTransformPipeline(p, obj.transforms);
    }
    itId = ctx.parentMap[itId];
  }

  return p;
}

List<String> getParentChain(String id, Map<String, String> parentMap) {
  final List<String> chain = [];
  String? current = id;
  while (current != null) {
    chain.add(current);
    current = parentMap[current];
  }
  return chain;
}

// ─────────────────────────────────────────────
// Resolusi Penempatan & Transformasi (utils.dart setara)
// ─────────────────────────────────────────────

double resolvePlaceX(
  Map<dynamic, dynamic> place,
  double width,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator evaluator = Evaluator(evalCtx);

  double? val;
  if (place.containsKey('left')) {
    val = normalizeUnit(evaluator.evaluate(place['left']), ctx.targetUnit);
  } else if (place.containsKey('right')) {
    val =
        normalizeUnit(evaluator.evaluate(place['right']), ctx.targetUnit) -
        width;
  } else if (place.containsKey('centerX')) {
    val =
        normalizeUnit(evaluator.evaluate(place['centerX']), ctx.targetUnit) -
        width / 2;
  } else if (place.containsKey('center')) {
    final p = resolveAnchorValue(place['center'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).x) - width / 2;
  } else if (place.containsKey('inside')) {
    final insideId = place['inside'].toString();
    final target = ctx.objects[insideId];
    if (target != null) {
      final bbox = geom.calculateBoundingBox(
        ctx.objects,
        targetIds: [insideId],
      );
      if (place.containsKey('margin')) {
        final margin = normalizeUnit(
          evaluator.evaluate(place['margin']),
          ctx.targetUnit,
        );
        val = bbox.x + margin;
      } else {
        val = bbox.x + (bbox.width - width) / 2;
      }
    }
  } else if (place.containsKey('topLeft')) {
    final p = resolveAnchorValue(place['topLeft'], ctx);
    val = p is num ? p.toDouble() : (p as Point2D).x;
  } else if (place.containsKey('topRight')) {
    final p = resolveAnchorValue(place['topRight'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).x) - width;
  } else if (place.containsKey('bottomLeft')) {
    final p = resolveAnchorValue(place['bottomLeft'], ctx);
    val = p is num ? p.toDouble() : (p as Point2D).x;
  } else if (place.containsKey('bottomRight')) {
    final p = resolveAnchorValue(place['bottomRight'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).x) - width;
  } else if (place.containsKey('topCenter')) {
    final p = resolveAnchorValue(place['topCenter'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).x) - width / 2;
  } else if (place.containsKey('bottomCenter')) {
    final p = resolveAnchorValue(place['bottomCenter'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).x) - width / 2;
  } else if (place.containsKey('centerLeft')) {
    final p = resolveAnchorValue(place['centerLeft'], ctx);
    val = p is num ? p.toDouble() : (p as Point2D).x;
  } else if (place.containsKey('centerRight')) {
    final p = resolveAnchorValue(place['centerRight'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).x) - width;
  }

  return val ?? 0.0;
}

double resolvePlaceY(
  Map<dynamic, dynamic> place,
  double height,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator evaluator = Evaluator(evalCtx);

  double? val;
  if (place.containsKey('top')) {
    val = normalizeUnit(evaluator.evaluate(place['top']), ctx.targetUnit);
  } else if (place.containsKey('bottom')) {
    val =
        normalizeUnit(evaluator.evaluate(place['bottom']), ctx.targetUnit) -
        height;
  } else if (place.containsKey('centerY')) {
    val =
        normalizeUnit(evaluator.evaluate(place['centerY']), ctx.targetUnit) -
        height / 2;
  } else if (place.containsKey('center')) {
    final p = resolveAnchorValue(place['center'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).y) - height / 2;
  } else if (place.containsKey('inside')) {
    final insideId = place['inside'].toString();
    final target = ctx.objects[insideId];
    if (target != null) {
      final bbox = geom.calculateBoundingBox(
        ctx.objects,
        targetIds: [insideId],
      );
      if (place.containsKey('margin')) {
        final margin = normalizeUnit(
          evaluator.evaluate(place['margin']),
          ctx.targetUnit,
        );
        val = bbox.y + margin;
      } else {
        val = bbox.y + (bbox.height - height) / 2;
      }
    }
  } else if (place.containsKey('topLeft')) {
    final p = resolveAnchorValue(place['topLeft'], ctx);
    val = p is num ? p.toDouble() : (p as Point2D).y;
  } else if (place.containsKey('topRight')) {
    final p = resolveAnchorValue(place['topRight'], ctx);
    val = p is num ? p.toDouble() : (p as Point2D).y;
  } else if (place.containsKey('bottomLeft')) {
    final p = resolveAnchorValue(place['bottomLeft'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).y) - height;
  } else if (place.containsKey('bottomRight')) {
    final p = resolveAnchorValue(place['bottomRight'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).y) - height;
  } else if (place.containsKey('topCenter')) {
    final p = resolveAnchorValue(place['topCenter'], ctx);
    val = p is num ? p.toDouble() : (p as Point2D).y;
  } else if (place.containsKey('bottomCenter')) {
    final p = resolveAnchorValue(place['bottomCenter'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).y) - height;
  } else if (place.containsKey('centerLeft')) {
    final p = resolveAnchorValue(place['centerLeft'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).y) - height / 2;
  } else if (place.containsKey('centerRight')) {
    final p = resolveAnchorValue(place['centerRight'], ctx);
    val = (p is num ? p.toDouble() : (p as Point2D).y) - height / 2;
  }

  return val ?? 0.0;
}

Map<String, Point2D>? resolveCustomAnchors(
  Map<dynamic, dynamic> obj,
  ResolvedObject resolved,
  ResolveContext ctx, [
  BoundingBox? groupBBox,
]) {
  if (!obj.containsKey('anchors') || obj['anchors'] is! Map) return null;

  final evalCtx = createEvalContext(ctx);
  final Evaluator evaluator = Evaluator(evalCtx);

  final Map<String, Point2D> result = {};
  final bbox = resolved is ResolvedGroup && groupBBox != null
      ? groupBBox
      : geom.calculateBoundingBox({resolved.id: resolved});

  final double baseX = bbox.x;
  final double baseY = bbox.y;
  final double width = bbox.width;
  final double height = bbox.height;

  for (final entry in (obj['anchors'] as Map).entries) {
    final name = entry.key.toString();
    final pos = entry.value;
    if (pos is List && pos.length == 2) {
      double px = 0.0;
      double py = 0.0;

      if (pos[0].toString().endsWith('%')) {
        px =
            baseX +
            (double.parse(pos[0].toString().replaceAll('%', '')) / 100.0) *
                width;
      } else {
        px = baseX + normalizeUnit(evaluator.evaluate(pos[0]), ctx.targetUnit);
      }

      if (pos[1].toString().endsWith('%')) {
        py =
            baseY +
            (double.parse(pos[1].toString().replaceAll('%', '')) / 100.0) *
                height;
      } else {
        py = baseY + normalizeUnit(evaluator.evaluate(pos[1]), ctx.targetUnit);
      }

      result[name] = (x: px, y: py);
    }
  }

  return result.isNotEmpty ? result : null;
}

class PlacementTransformResult {
  final List<ResolvedTransformOp> transforms;
  final double dx;
  final double dy;
  PlacementTransformResult(this.transforms, this.dx, this.dy);
}

PlacementTransformResult applyObjectPlacementAndTransform(
  Map<dynamic, dynamic> obj,
  BoundingBox bbox,
  ResolveContext ctx, [
  Map<String, Point2D>? componentAnchors,
]) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator evaluator = Evaluator(evalCtx);

  List<dynamic> pipeline = [];
  if (obj.containsKey('transform')) {
    final t = obj['transform'];
    if (t is List) {
      pipeline = t;
    } else if (t is Map) {
      final origin = t['origin'];
      for (final entry in t.entries) {
        if (entry.key == 'origin') continue;
        pipeline.add({entry.key: entry.value, 'origin': origin});
      }
    }
  }

  final Point2D defaultOrigin = (
    x: bbox.x + bbox.width / 2,
    y: bbox.y + bbox.height / 2,
  );

  final List<ResolvedTransformOp> resolvedPipeline = [];
  double dx = 0.0;
  double dy = 0.0;

  for (final op in pipeline) {
    if (op is! Map) continue;
    final keys = op.keys.where((k) => k != 'origin').toList();
    if (keys.isEmpty) continue;
    final type = keys[0].toString();
    final val = op[type];
    final localOriginRef = op['origin'];
    Point2D resolvedOrigin = defaultOrigin;

    if (localOriginRef != null) {
      if (localOriginRef is String &&
          componentAnchors != null &&
          componentAnchors.containsKey(localOriginRef)) {
        resolvedOrigin = componentAnchors[localOriginRef]!;
      } else {
        final p = resolveAnchorValue(localOriginRef, ctx);
        resolvedOrigin = p is num
            ? (x: p.toDouble(), y: p.toDouble())
            : p as Point2D;
      }
    }

    if (type == 'translate') {
      if (val is List && val.length >= 2) {
        dx += (normalizeUnit(evaluator.evaluate(val[0]), ctx.targetUnit) as num)
            .toDouble();
        dy += (normalizeUnit(evaluator.evaluate(val[1]), ctx.targetUnit) as num)
            .toDouble();
      }
    } else if (type == 'rotate') {
      dynamic angleExpr = val;
      Point2D origin = resolvedOrigin;
      if (val is Map) {
        angleExpr = val['angle'];
        if (val.containsKey('origin')) {
          final oRef = val['origin'];
          if (oRef is String &&
              componentAnchors != null &&
              componentAnchors.containsKey(oRef)) {
            origin = componentAnchors[oRef]!;
          } else {
            final p = resolveAnchorValue(oRef, ctx);
            origin = p is num
                ? (x: p.toDouble(), y: p.toDouble())
                : p as Point2D;
          }
        }
      }
      resolvedPipeline.add(
        RotateOp(evaluator.evaluate(angleExpr) * (180.0 / math.pi), origin),
      );
    } else if (type == 'scale') {
      dynamic factorExpr = val;
      Point2D origin = resolvedOrigin;
      if (val is Map) {
        factorExpr = val['factor'];
        if (val.containsKey('origin')) {
          final oRef = val['origin'];
          if (oRef is String &&
              componentAnchors != null &&
              componentAnchors.containsKey(oRef)) {
            origin = componentAnchors[oRef]!;
          } else {
            final p = resolveAnchorValue(oRef, ctx);
            origin = p is num
                ? (x: p.toDouble(), y: p.toDouble())
                : p as Point2D;
          }
        }
      }
      double sx = 1.0;
      double sy = 1.0;
      if (factorExpr is List && factorExpr.length >= 2) {
        sx = evaluator.evaluate(factorExpr[0]).toDouble();
        sy = evaluator.evaluate(factorExpr[1]).toDouble();
      } else {
        sx = evaluator.evaluate(factorExpr).toDouble();
        sy = sx;
      }
      resolvedPipeline.add(ScaleOp(sx, sy, origin));
    } else if (type == 'mirror') {
      dynamic axis = val;
      Point2D origin = resolvedOrigin;
      if (val is Map) {
        axis = val['axis'];
        if (val.containsKey('origin')) {
          final oRef = val['origin'];
          if (oRef is String &&
              componentAnchors != null &&
              componentAnchors.containsKey(oRef)) {
            origin = componentAnchors[oRef]!;
          } else {
            final p = resolveAnchorValue(oRef, ctx);
            origin = p is num
                ? (x: p.toDouble(), y: p.toDouble())
                : p as Point2D;
          }
        }
      }
      resolvedPipeline.add(MirrorOp(axis.toString(), origin));
    }
  }

  // Handle penempatan berbasis 'on' (oriented frame)
  ResolvedTransformOp? orientedRotation;
  if (obj.containsKey('on')) {
    final onSpec = obj['on'] as Map;
    double targetX = bbox.x + bbox.width / 2;
    double targetY = bbox.y + bbox.height / 2;
    String anchorVal = 'center';
    bool onResolved = false;

    if (onSpec.containsKey('point')) {
      final pt = onSpec['point'] as Map;
      final ptVal = toPoint2D(evaluator.evaluate(pt['at']));
      if (ptVal != null) {
        targetX = ptVal.x;
        targetY = ptVal.y;
        onResolved = true;
      }
      if (pt.containsKey('anchor')) {
        final anc = pt['anchor'];
        anchorVal = anc is String ? anc : evaluator.evaluate(anc).toString();
      }
    } else if (onSpec.containsKey('path')) {
      final pathSpec = onSpec['path'] as Map;
      final ptVal = toPoint2D(
        evaluator.evaluate('pointAt(${pathSpec['path']}, ${pathSpec['t']})'),
      );
      if (ptVal != null) {
        targetX = ptVal.x;
        targetY = ptVal.y;
        onResolved = true;
      }
      if (pathSpec.containsKey('anchor')) {
        final anc = pathSpec['anchor'];
        anchorVal = anc is String ? anc : evaluator.evaluate(anc).toString();
      }
    } else if (onSpec.containsKey('frame')) {
      final rawFrameSpec = onSpec['frame'];
      dynamic frameVal;
      if (rawFrameSpec is Map &&
          rawFrameSpec.containsKey('path') &&
          rawFrameSpec.containsKey('t')) {
        frameVal = evaluator.evaluate(
          'frameAt(${rawFrameSpec['path']}, ${rawFrameSpec['t']})',
        );
      } else {
        frameVal = evaluator.evaluate(rawFrameSpec);
      }
      if (frameVal is Map &&
          frameVal.containsKey('point') &&
          frameVal.containsKey('angle')) {
        final f = frameVal;
        final pt = f['point'] as Point2D;
        targetX = pt.x;
        targetY = pt.y;
        onResolved = true;

        final double angleVal = (f['angle'] as num).toDouble();
        orientedRotation = RotateOp(angleVal * (180.0 / math.pi), (
          x: targetX,
          y: targetY,
        ));
      }
      if (rawFrameSpec is Map && rawFrameSpec.containsKey('anchor')) {
        final anc = rawFrameSpec['anchor'];
        anchorVal = anc is String ? anc : evaluator.evaluate(anc).toString();
      }
    }
    if (onResolved) {
      double baseX = bbox.x + bbox.width / 2;
      double baseY = bbox.y + bbox.height / 2;

      if (anchorVal != 'center') {
        if (componentAnchors != null &&
            componentAnchors.containsKey(anchorVal)) {
          baseX = componentAnchors[anchorVal]!.x;
          baseY = componentAnchors[anchorVal]!.y;
        } else if (anchorVal == 'topLeft') {
          baseX = bbox.x;
          baseY = bbox.y;
        } else if (anchorVal == 'topRight') {
          baseX = bbox.x + bbox.width;
          baseY = bbox.y;
        } else if (anchorVal == 'bottomLeft') {
          baseX = bbox.x;
          baseY = bbox.y + bbox.height;
        } else if (anchorVal == 'bottomRight') {
          baseX = bbox.x + bbox.width;
          baseY = bbox.y + bbox.height;
        }
      }

      dx = targetX - baseX;
      dy = targetY - baseY;
    }
  } else if (obj.containsKey('place')) {
    final placeSpec = obj['place'] as Map;
    String? customAnchor = componentAnchors != null
        ? placeSpec.keys
              .map((k) => k.toString())
              .firstWhere(
                (k) => componentAnchors.containsKey(k),
                orElse: () => '',
              )
        : '';
    if (customAnchor.isNotEmpty && componentAnchors != null) {
      final p = resolveAnchorValue(placeSpec[customAnchor], ctx);
      final double targetX = p is num ? p.toDouble() : (p as Point2D).x;
      final double targetY = p is num ? p.toDouble() : (p as Point2D).y;
      dx = targetX - componentAnchors[customAnchor]!.x;
      dy = targetY - componentAnchors[customAnchor]!.y;
    } else {
      final double targetX = resolvePlaceX(placeSpec, bbox.width, ctx);
      final double targetY = resolvePlaceY(placeSpec, bbox.height, ctx);
      dx = targetX - bbox.x;
      dy = targetY - bbox.y;
    }
  }

  if (orientedRotation != null) {
    resolvedPipeline.insert(0, orientedRotation);
  }

  return PlacementTransformResult(resolvedPipeline, dx, dy);
}

// ─────────────────────────────────────────────
// Resolusi Holes polimorfik (resolveHolesProperty setara)
// ─────────────────────────────────────────────

List<ResolvedHole>? resolveHolesProperty(
  String id,
  List<dynamic>? holes,
  List<Point2D> resolvedOuterPoints,
  ResolveContext ctx,
) {
  if (holes == null || holes.isEmpty) return null;

  final List<ResolvedHole> resolvedHolesResult = [];
  for (int i = 0; i < holes.length; i++) {
    final hole = holes[i];
    List<PathResolvedSegment> holeSegments = [];

    if (hole is String) {
      final resolvedHole = ctx.objects[hole];
      if (resolvedHole != null) {
        if (resolvedHole is ResolvedCollection) {
          for (final childId in resolvedHole.children) {
            final childObj = ctx.objects[childId];
            if (childObj != null) {
              final normalized = normalizeClosedShape(childObj, ctx.objects);
              final childHoleSegs = polyToSegments(normalized.outer);
              if (childHoleSegs.isNotEmpty) {
                resolvedHolesResult.add(ResolvedHole(childHoleSegs));
              }
            }
          }
          continue;
        } else {
          final normalized = normalizeClosedShape(resolvedHole, ctx.objects);
          holeSegments = polyToSegments(normalized.outer);
        }
      } else {
        throw Exception('Hole reference "$hole" not found or not resolved.');
      }
    } else if (hole is Map) {
      if (hole.containsKey('segments')) {
        // Sample segments
        final List<dynamic> rawSegs = hole['segments'] as List;
        for (final r in rawSegs) {
          if (r is Map && r.containsKey('line')) {
            final l = r['line'] as List;
            final evalCtx = createEvalContext(ctx);
            final Evaluator ev = Evaluator(evalCtx);
            final double x1 = normalizeUnit(ev.evaluate(l[0]), ctx.targetUnit);
            final double y1 = normalizeUnit(ev.evaluate(l[1]), ctx.targetUnit);
            final double x2 = normalizeUnit(ev.evaluate(l[2]), ctx.targetUnit);
            final double y2 = normalizeUnit(ev.evaluate(l[3]), ctx.targetUnit);
            holeSegments.add(LineSegment(x1, y1, x2, y2));
          }
        }
      } else if (hole.containsKey('type')) {
        final tempId = '${id}_hole_$i';
        ResolvedObject? resolvedHole;
        final type = hole['type'].toString();
        if (type == 'rect') {
          resolvedHole = resolveRect(tempId, hole, ctx);
        } else if (type == 'circle') {
          resolvedHole = resolveCircle(tempId, hole, ctx);
        } else if (type == 'ellipse') {
          resolvedHole = resolveEllipse(tempId, hole, ctx);
        } else if (type == 'polygon') {
          resolvedHole = resolvePolygon(tempId, hole, ctx);
        } else if (type == 'path') {
          resolvedHole = resolvePath(tempId, hole, ctx);
        }

        if (resolvedHole != null) {
          final normalized = normalizeClosedShape(resolvedHole, ctx.objects);
          holeSegments = polyToSegments(normalized.outer);
        }
      }
    }

    if (holeSegments.isNotEmpty) {
      resolvedHolesResult.add(ResolvedHole(holeSegments));
    }
  }

  return resolvedHolesResult.isNotEmpty ? resolvedHolesResult : null;
}

// ─────────────────────────────────────────────
// Dispatcher Resolusi Objek Primitif
// ─────────────────────────────────────────────

Map<String, dynamic> evaluateMetaMap(
  Map<dynamic, dynamic> rawMeta,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  final Map<String, dynamic> resolvedMeta = {};
  for (final entry in rawMeta.entries) {
    final key = entry.key.toString();
    final val = entry.value;
    if (val is String) {
      try {
        final result = ev.evaluate(val);
        resolvedMeta[key] = result;
      } catch (_) {
        resolvedMeta[key] = val;
      }
    } else {
      resolvedMeta[key] = val;
    }
  }
  return resolvedMeta;
}

bool _isStructuredMapValue(dynamic value) {
  return value is Map && value.keys.every((key) => key is! int);
}

Map<String, dynamic> _mapWithoutInherit(Map<dynamic, dynamic> source) {
  final result = <String, dynamic>{};
  for (final entry in source.entries) {
    final key = entry.key.toString();
    if (key == 'inherit') continue;
    result[key] = entry.value;
  }
  return result;
}

Map<dynamic, dynamic> _lookupStructuredInheritSource(
  String ref,
  ResolveContext ctx, {
  List<Map<dynamic, dynamic>?>? sources,
}) {
  final sourceMaps = sources ?? [ctx.scalars];
  for (final sourceMap in sourceMaps) {
    if (sourceMap == null) continue;
    final source = sourceMap[ref];
    if (source == null) continue;
    if (!_isStructuredMapValue(source)) {
      throw Exception(
        'INVALID_INHERIT_TARGET: inherit source must be a structured map: $ref',
      );
    }
    return Map<dynamic, dynamic>.from(source as Map);
  }
  throw Exception('INHERIT_TARGET_NOT_FOUND: inherit source not found: $ref');
}

Map<String, dynamic> _resolveStructuredSource(
  String ref,
  ResolveContext ctx,
  Set<String> seen, {
  List<Map<dynamic, dynamic>?>? sources,
}) {
  if (seen.contains(ref)) {
    throw Exception('CIRCULAR_INHERIT: circular inherit detected at: $ref');
  }

  seen.add(ref);
  try {
    final source = _lookupStructuredInheritSource(ref, ctx, sources: sources);
    final inheritSpec = source['inherit'];
    final localEntries = _mapWithoutInherit(source);
    if (inheritSpec == null) {
      return localEntries;
    }

    final inherited = resolveStructuredInherit(
      inheritSpec,
      ctx,
      seen: seen,
      sources: sources,
    );
    return {...inherited, ...localEntries};
  } finally {
    seen.remove(ref);
  }
}

Map<String, dynamic> resolveStructuredInherit(
  dynamic inheritSpec,
  ResolveContext ctx, {
  Set<String>? seen,
  List<Map<dynamic, dynamic>?>? sources,
}) {
  if (inheritSpec == null) return <String, dynamic>{};

  final refs = inheritSpec is List ? inheritSpec : [inheritSpec];
  final merged = <String, dynamic>{};
  final activeSeen = seen ?? <String>{};

  for (final ref in refs) {
    final refName = ref?.toString().trim() ?? '';
    if (refName.isEmpty) {
      throw Exception(
        'INVALID_INHERIT_TARGET: inherit references must be non-empty strings',
      );
    }
    merged.addAll(
      _resolveStructuredSource(refName, ctx, activeSeen, sources: sources),
    );
  }

  return merged;
}

Map<dynamic, dynamic> applyObjectStylePreset(
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final metadataSources = <Map<dynamic, dynamic>?>[
    ctx.doc['metaPresets'] is Map
        ? Map<dynamic, dynamic>.from(ctx.doc['metaPresets'] as Map)
        : null,
    ctx.doc['styles'] is Map
        ? Map<dynamic, dynamic>.from(ctx.doc['styles'] as Map)
        : null,
    ctx.scalars,
  ];

  final presetName = obj['metaPreset'] ?? obj['style'];
  final styleDef = presetName != null
      ? (ctx.doc['metaPresets'] is Map &&
                (ctx.doc['metaPresets'] as Map).containsKey(presetName)
            ? (ctx.doc['metaPresets'] as Map)[presetName]
            : (ctx.doc['styles'] is Map
                  ? (ctx.doc['styles'] as Map)[presetName]
                  : null))
      : null;

  final inheritedMeta =
      obj['meta'] is Map && (obj['meta'] as Map).containsKey('inherit')
      ? resolveStructuredInherit(
          (obj['meta'] as Map)['inherit'],
          ctx,
          sources: metadataSources,
        )
      : <String, dynamic>{};
  final localMeta = obj['meta'] is Map
      ? _mapWithoutInherit(Map<dynamic, dynamic>.from(obj['meta'] as Map))
      : <String, dynamic>{};

  final mergedMeta = <String, dynamic>{};
  if (_isStructuredMapValue(styleDef)) {
    mergedMeta.addAll(Map<String, dynamic>.from(styleDef as Map));
  }
  mergedMeta.addAll(inheritedMeta);
  mergedMeta.addAll(localMeta);

  if (mergedMeta.isEmpty) return obj;
  final next = Map<dynamic, dynamic>.from(obj);
  next['meta'] = mergedMeta;
  return next;
}

ResolvedObject resolveObject(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  Map<dynamic, dynamic> targetObj = applyObjectStylePreset(obj, ctx);
  if (targetObj.containsKey('meta') && targetObj['meta'] is Map) {
    final evaluatedMeta = evaluateMetaMap(targetObj['meta'] as Map, ctx);
    final mutableObj = Map<dynamic, dynamic>.from(targetObj);
    mutableObj['meta'] = evaluatedMeta;
    targetObj = mutableObj;
  }

  final type = targetObj['type']?.toString() ?? '';
  switch (type) {
    case 'point':
      return resolvePoint(id, targetObj, ctx);
    case 'rect':
      return resolveRect(id, targetObj, ctx);
    case 'line':
      return resolveLine(id, targetObj, ctx);
    case 'circle':
      return resolveCircle(id, targetObj, ctx);
    case 'ellipse':
      return resolveEllipse(id, targetObj, ctx);
    case 'arc':
      return resolveArc(id, targetObj, ctx);
    case 'quadratic':
      return resolveQuadratic(id, targetObj, ctx);
    case 'cubic':
      return resolveCubic(id, targetObj, ctx);
    case 'text':
      return resolveText(id, targetObj, ctx);
    case 'path':
      return resolvePath(id, targetObj, ctx);
    case 'polygon':
      return resolvePolygon(id, targetObj, ctx);
    case 'boolean':
      return resolveBoolean(id, targetObj, ctx);
    case 'group':
      return resolveGroup(id, targetObj, ctx);
    case 'clone':
      return resolveClone(id, targetObj, ctx);
    case 'repeat':
      return resolveRepeat(id, targetObj, ctx);
    case 'divide':
      return resolveDivide(id, targetObj, ctx);
    case 'component':
      return resolveComponent(id, targetObj, ctx);
    case 'dimension':
      return resolveDimension(id, targetObj, ctx);
    case 'annotation':
      return resolveAnnotation(id, targetObj, ctx);
    case 'collection':
      return ResolvedCollection(
        id: id,
        meta: Meta.fromJson(Map<String, dynamic>.from(targetObj['meta'] ?? {})),
        children: List<String>.from(targetObj['children'] ?? []),
      );
    default:
      throw Exception('Unknown object type: $type');
  }
}

// ─────────────────────────────────────────────
// Implementasi Spesifik Primitif Resolvers
// ─────────────────────────────────────────────

ResolvedPoint resolvePoint(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  double x = 0.0;
  double y = 0.0;

  if (obj.containsKey('at')) {
    final at = obj['at'];
    if (at == 'origin') {
      x = 0.0;
      y = 0.0;
    } else if (at is List && at.length == 2) {
      x = normalizeUnit(ev.evaluate(at[0]), ctx.targetUnit);
      y = normalizeUnit(ev.evaluate(at[1]), ctx.targetUnit);
    } else {
      final rawVal = ev.evaluate(at);
      final val = toPoint2D(rawVal);
      if (val != null) {
        x = val.x;
        y = val.y;
      } else if (rawVal is num) {
        x = rawVal.toDouble();
        y = rawVal.toDouble();
      }
    }
  } else if (obj.containsKey('on')) {
    final onSpec = obj['on'] as Map;
    if (onSpec.containsKey('point')) {
      final pt = toPoint2D(ev.evaluate(onSpec['point']['at']));
      if (pt != null) {
        x = pt.x;
        y = pt.y;
      }
    } else if (onSpec.containsKey('path')) {
      final pathSpec = onSpec['path'] as Map;
      final ptVal = toPoint2D(
        ev.evaluate('pointAt(${pathSpec['path']}, ${pathSpec['t']})'),
      );
      if (ptVal != null) {
        x = ptVal.x;
        y = ptVal.y;
      }
    }
  }

  if (obj.containsKey('from') || obj.containsKey('move')) {
    double baseX = x;
    double baseY = y;

    if (obj.containsKey('from')) {
      final p = resolveAnchorValue(obj['from'], ctx);
      baseX = p is num ? p.toDouble() : (p as Point2D).x;
      baseY = p is num ? p.toDouble() : (p as Point2D).y;
      x = baseX;
      y = baseY;
    }

    if (obj.containsKey('move')) {
      final move = obj['move'] as Map;
      if (move.containsKey('distance') && move.containsKey('angle')) {
        final dist = normalizeUnit(
          ev.evaluate(move['distance']),
          ctx.targetUnit,
        );
        final rad = ev.evaluate(move['angle']).toDouble();
        x = baseX + dist * math.cos(rad);
        y = baseY + dist * math.sin(rad);
      } else {
        if (move.containsKey('right')) {
          x = baseX + normalizeUnit(ev.evaluate(move['right']), ctx.targetUnit);
        }
        if (move.containsKey('left')) {
          x = baseX - normalizeUnit(ev.evaluate(move['left']), ctx.targetUnit);
        }
        if (move.containsKey('up')) {
          y = baseY - normalizeUnit(ev.evaluate(move['up']), ctx.targetUnit);
        }
        if (move.containsKey('down')) {
          y = baseY + normalizeUnit(ev.evaluate(move['down']), ctx.targetUnit);
        }
        if (move.containsKey('x')) {
          x = baseX + normalizeUnit(ev.evaluate(move['x']), ctx.targetUnit);
        }
        if (move.containsKey('y')) {
          y = baseY + normalizeUnit(ev.evaluate(move['y']), ctx.targetUnit);
        }
      }
    }
  }

  final bbox = BoundingBox(x: x, y: y, width: 0.0, height: 0.0);
  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final resolved = ResolvedPoint(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    x: x + plRes.dx,
    y: y + plRes.dy,
    transforms: plRes.transforms,
  );
  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedRect resolveRect(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  double width = 0.0;
  double height = 0.0;
  final size = obj['size'] as List;
  width = normalizeUnit(ev.evaluate(size[0]), ctx.targetUnit);
  height = normalizeUnit(ev.evaluate(size[1]), ctx.targetUnit);

  final bbox = BoundingBox(x: 0, y: 0, width: width, height: height);
  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final resolved = ResolvedRect(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    x: plRes.dx,
    y: plRes.dy,
    width: width,
    height: height,
    transforms: plRes.transforms,
  );

  final outerPoints = [
    (x: plRes.dx, y: plRes.dy),
    (x: plRes.dx + width, y: plRes.dy),
    (x: plRes.dx + width, y: plRes.dy + height),
    (x: plRes.dx, y: plRes.dy + height),
  ];
  if (obj.containsKey('holes')) {
    final holes = resolveHolesProperty(
      id,
      obj['holes'] as List,
      outerPoints,
      ctx,
    );
    if (holes != null) resolved.holes.addAll(holes);
  }

  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedLine resolveLine(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  double x1 = 0.0;
  double y1 = 0.0;
  double x2 = 0.0;
  double y2 = 0.0;

  final p1 = resolveAnchorValue(obj['from'] ?? [0, 0], ctx);
  x1 = p1 is num ? p1.toDouble() : (p1 as Point2D).x;
  y1 = p1 is num ? p1.toDouble() : (p1 as Point2D).y;

  if (obj.containsKey('to')) {
    final p2 = resolveAnchorValue(obj['to'], ctx);
    x2 = p2 is num ? p2.toDouble() : (p2 as Point2D).x;
    y2 = p2 is num ? p2.toDouble() : (p2 as Point2D).y;
  } else if (obj.containsKey('length') && obj.containsKey('direction')) {
    final len = normalizeUnit(ev.evaluate(obj['length']), ctx.targetUnit);
    final dir = obj['direction'].toString();
    if (dir == 'right') {
      x2 = x1 + len;
      y2 = y1;
    } else if (dir == 'left') {
      x2 = x1 - len;
      y2 = y1;
    } else if (dir == 'down') {
      x2 = x1;
      y2 = y1 + len;
    } else if (dir == 'up') {
      x2 = x1;
      y2 = y1 - len;
    }
  }

  final bbox = BoundingBox(
    x: math.min(x1, x2),
    y: math.min(y1, y2),
    width: (x2 - x1).abs(),
    height: (y2 - y1).abs(),
  );
  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final resolved = ResolvedLine(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    x1: x1 + plRes.dx,
    y1: y1 + plRes.dy,
    x2: x2 + plRes.dx,
    y2: y2 + plRes.dy,
    transforms: plRes.transforms,
  );

  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedCircle resolveCircle(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  double cx = 0.0;
  double cy = 0.0;
  double radius = 0.0;

  if (obj.containsKey('center')) {
    final p = resolveAnchorValue(obj['center'], ctx);
    cx = p is num ? p.toDouble() : (p as Point2D).x;
    cy = p is num ? p.toDouble() : (p as Point2D).y;
  }

  if (obj.containsKey('radius')) {
    radius = normalizeUnit(ev.evaluate(obj['radius']), ctx.targetUnit);
  } else if (obj.containsKey('through')) {
    final tp = resolveAnchorValue(obj['through'], ctx);
    final double tx = tp is num ? tp.toDouble() : (tp as Point2D).x;
    final double ty = tp is num ? tp.toDouble() : (tp as Point2D).y;
    radius = geom.hypot(tx - cx, ty - cy);
  }

  final bbox = BoundingBox(
    x: cx - radius,
    y: cy - radius,
    width: radius * 2,
    height: radius * 2,
  );
  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final resolved = ResolvedCircle(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    cx: cx + plRes.dx,
    cy: cy + plRes.dy,
    radius: radius,
    transforms: plRes.transforms,
  );

  final List<Point2D> outerPoints = [];
  const int segmentsCount = 64;
  for (int i = 0; i < segmentsCount; i++) {
    final angle = (i * 2 * math.pi) / segmentsCount;
    outerPoints.add((
      x: cx + plRes.dx + radius * math.cos(angle),
      y: cy + plRes.dy + radius * math.sin(angle),
    ));
  }
  if (obj.containsKey('holes')) {
    final holes = resolveHolesProperty(
      id,
      obj['holes'] as List,
      outerPoints,
      ctx,
    );
    if (holes != null) resolved.holes.addAll(holes);
  }

  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedEllipse resolveEllipse(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  double cx = 0.0;
  double cy = 0.0;
  if (obj.containsKey('center')) {
    final p = resolveAnchorValue(obj['center'], ctx);
    cx = p is num ? p.toDouble() : (p as Point2D).x;
    cy = p is num ? p.toDouble() : (p as Point2D).y;
  }

  if (obj.containsKey('size') &&
      (obj.containsKey('rx') || obj.containsKey('ry'))) {
    throw Exception(
      'ELLIPSE_SIZE_CONFLICT: ellipse cannot define size together with rx/ry',
    );
  }

  double rx = 0.0;
  double ry = 0.0;
  if (obj.containsKey('size')) {
    final size = obj['size'];
    if (size is! List || size.length < 2) {
      throw Exception('ELLIPSE_INVALID_SIZE: size must be a 2-item list');
    }
    rx = normalizeUnit(ev.evaluate(size[0]), ctx.targetUnit) / 2.0;
    ry = normalizeUnit(ev.evaluate(size[1]), ctx.targetUnit) / 2.0;
  } else {
    if (obj.containsKey('rx')) {
      rx = normalizeUnit(ev.evaluate(obj['rx']), ctx.targetUnit);
    }
    if (obj.containsKey('ry')) {
      ry = normalizeUnit(ev.evaluate(obj['ry']), ctx.targetUnit);
    }
  }

  if (rx <= 0 || ry <= 0) {
    throw Exception(
      'ELLIPSE_INVALID_RADIUS: ellipse requires rx > 0 and ry > 0',
    );
  }

  final rotation = obj.containsKey('rotation')
      ? (ev.evaluate(obj['rotation']) as num).toDouble()
      : 0.0;
  final cosR = math.cos(rotation);
  final sinR = math.sin(rotation);
  final halfWidth = math.sqrt(
    (rx * cosR) * (rx * cosR) + (ry * sinR) * (ry * sinR),
  );
  final halfHeight = math.sqrt(
    (rx * sinR) * (rx * sinR) + (ry * cosR) * (ry * cosR),
  );
  final bbox = BoundingBox(
    x: cx - halfWidth,
    y: cy - halfHeight,
    width: halfWidth * 2,
    height: halfHeight * 2,
  );
  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final resolved = ResolvedEllipse(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    cx: cx + plRes.dx,
    cy: cy + plRes.dy,
    rx: rx,
    ry: ry,
    rotation: rotation,
    transforms: plRes.transforms,
  );

  final List<Point2D> outerPoints = [];
  const int segmentsCount = 64;
  for (int i = 0; i < segmentsCount; i++) {
    final angle = (i * 2 * math.pi) / segmentsCount;
    final localX = rx * math.cos(angle);
    final localY = ry * math.sin(angle);
    outerPoints.add((
      x: cx + plRes.dx + (localX * cosR - localY * sinR),
      y: cy + plRes.dy + (localX * sinR + localY * cosR),
    ));
  }
  if (obj.containsKey('holes')) {
    final holes = resolveHolesProperty(
      id,
      obj['holes'] as List,
      outerPoints,
      ctx,
    );
    if (holes != null) resolved.holes.addAll(holes);
  }

  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedArc resolveArc(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  double x1 = 0.0, y1 = 0.0;
  double x2 = 0.0, y2 = 0.0;
  double cx = 0.0, cy = 0.0;
  double radius = 0.0;
  double startAngle = 0.0, endAngle = 0.0;
  int sweep = 1, largeArc = 0;

  if (obj.containsKey('center') &&
      obj.containsKey('radius') &&
      obj.containsKey('startAngle') &&
      obj.containsKey('endAngle')) {
    final center = resolveAnchorValue(obj['center'], ctx);
    cx = center is num ? center.toDouble() : (center as Point2D).x;
    cy = center is num ? center.toDouble() : (center as Point2D).y;
    radius = normalizeUnit(ev.evaluate(obj['radius']), ctx.targetUnit);
    startAngle = ev.evaluate(obj['startAngle']).toDouble();
    endAngle = ev.evaluate(obj['endAngle']).toDouble();
    x1 = cx + radius * math.cos(startAngle);
    y1 = cy + radius * math.sin(startAngle);
    x2 = cx + radius * math.cos(endAngle);
    y2 = cy + radius * math.sin(endAngle);
    final delta = endAngle - startAngle;
    sweep = delta >= 0.0 ? 1 : 0;
    largeArc = delta.abs() > math.pi ? 1 : 0;
  }

  final resolved = ResolvedArc(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    x1: x1,
    y1: y1,
    x2: x2,
    y2: y2,
    cx: cx,
    cy: cy,
    radius: radius,
    startAngle: startAngle,
    endAngle: endAngle,
    sweep: sweep,
    largeArc: largeArc,
  );
  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedQuadratic resolveQuadratic(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final p1 = resolveAnchorValue(obj['from'], ctx) as Point2D;
  final cp = resolveAnchorValue(obj['cp'], ctx) as Point2D;
  final p2 = resolveAnchorValue(obj['to'], ctx) as Point2D;

  final resolved = ResolvedQuadratic(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    x1: p1.x,
    y1: p1.y,
    cpx: cp.x,
    cpy: cp.y,
    x2: p2.x,
    y2: p2.y,
  );
  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedCubic resolveCubic(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final p1 = resolveAnchorValue(obj['from'], ctx) as Point2D;
  final cp1 = resolveAnchorValue(obj['cp1'], ctx) as Point2D;
  final cp2 = resolveAnchorValue(obj['cp2'], ctx) as Point2D;
  final p2 = resolveAnchorValue(obj['to'], ctx) as Point2D;

  final resolved = ResolvedCubic(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    x1: p1.x,
    y1: p1.y,
    cp1x: cp1.x,
    cp1y: cp1.y,
    cp2x: cp2.x,
    cp2y: cp2.y,
    x2: p2.x,
    y2: p2.y,
  );
  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedText resolveText(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  final p = resolveAnchorValue(obj['at'] ?? [0, 0], ctx) as Point2D;
  String content = obj['content']?.toString() ?? '';
  content = content.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (m) {
    return ev.evaluate(m.group(1)!.trim()).toString();
  });

  final double fontSize = _parseTypographicScalar(
    obj['meta']?['fontSize'],
    12.0,
  );
  final metrics = ctx.textMetrics.measure(
    content: content,
    fontSize: fontSize,
    lineHeight: _parseTypographicScalar(obj['meta']?['lineHeight'], 1.0),
  );

  final anchor = obj['anchor']?.toString() ?? 'topLeft';
  double x = p.x;
  double y = p.y;

  if (anchor == 'topCenter') {
    x -= metrics.width / 2;
  } else if (anchor == 'topRight') {
    x -= metrics.width;
  } else if (anchor == 'centerLeft') {
    y -= metrics.height / 2;
  } else if (anchor == 'center') {
    x -= metrics.width / 2;
    y -= metrics.height / 2;
  } else if (anchor == 'centerRight') {
    x -= metrics.width;
    y -= metrics.height / 2;
  } else if (anchor == 'bottomLeft') {
    y -= metrics.height;
  } else if (anchor == 'bottomCenter') {
    x -= metrics.width / 2;
    y -= metrics.height;
  } else if (anchor == 'bottomRight') {
    x -= metrics.width;
    y -= metrics.height;
  }

  final bbox = BoundingBox(
    x: x,
    y: y,
    width: metrics.width,
    height: metrics.height,
  );
  final plRes = applyObjectPlacementAndTransform(
    obj.containsKey('place') ? {...obj, 'at': null} : obj,
    bbox,
    ctx,
  );

  final resolved = ResolvedText(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    x: x + plRes.dx,
    y: y + plRes.dy,
    width: metrics.width,
    height: metrics.height,
    content: content,
    anchor: anchor,
    transforms: plRes.transforms,
  );
  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

/// Mem-parsing raw segments YAML menjadi `List&lt;PathResolvedSegment&gt;`.
/// Menangani semua tipe: line, arc (3-point), quadratic, cubic.
List<PathResolvedSegment> parsePathSegments(
  List<dynamic> rawSegs,
  ResolveContext ctx, {
  Point2D? initialPoint,
}) {
  final segments = <PathResolvedSegment>[];
  Point2D lastPt = initialPoint ?? (x: 0.0, y: 0.0);

  for (final r in rawSegs) {
    if (r is! Map) continue;

    if (r.containsKey('line')) {
      final lineSpec = r['line'];
      Point2D? fromPt;
      Point2D toPt;

      if (lineSpec is Map) {
        if (lineSpec.containsKey('from')) {
          fromPt = resolveAnchorValue(lineSpec['from'], ctx) as Point2D;
        }
        toPt = resolveAnchorValue(lineSpec['to'], ctx) as Point2D;
      } else {
        // shorthand: - line: [x1, y1, x2, y2]
        final l = lineSpec as List;
        final evalCtx = createEvalContext(ctx);
        final ev = Evaluator(evalCtx);
        fromPt = (
          x: normalizeUnit(ev.evaluate(l[0]), ctx.targetUnit),
          y: normalizeUnit(ev.evaluate(l[1]), ctx.targetUnit),
        );
        toPt = (
          x: normalizeUnit(ev.evaluate(l[2]), ctx.targetUnit),
          y: normalizeUnit(ev.evaluate(l[3]), ctx.targetUnit),
        );
      }

      final start = fromPt ?? lastPt;
      segments.add(LineSegment(start.x, start.y, toPt.x, toPt.y));
      lastPt = toPt;
    } else if (r.containsKey('arc')) {
      final arcSpec = r['arc'] as Map;
      final throughPt = resolveAnchorValue(arcSpec['through'], ctx) as Point2D;
      final toPt = resolveAnchorValue(arcSpec['to'], ctx) as Point2D;
      // 3-point arc dari lastPt → throughPt → toPt
      final arcSeg = _computeArcSegmentFrom3Points(lastPt, throughPt, toPt);
      if (arcSeg != null) segments.add(arcSeg);
      lastPt = toPt;
    } else if (r.containsKey('quadratic')) {
      final qSpec = r['quadratic'] as Map;
      final cpPt = resolveAnchorValue(qSpec['cp'], ctx) as Point2D;
      final toPt = resolveAnchorValue(qSpec['to'], ctx) as Point2D;
      segments.add(
        QuadraticSegment(lastPt.x, lastPt.y, cpPt.x, cpPt.y, toPt.x, toPt.y),
      );
      lastPt = toPt;
    } else if (r.containsKey('cubic')) {
      final cSpec = r['cubic'] as Map;
      final cp1Pt = resolveAnchorValue(cSpec['cp1'], ctx) as Point2D;
      final cp2Pt = resolveAnchorValue(cSpec['cp2'], ctx) as Point2D;
      final toPt = resolveAnchorValue(cSpec['to'], ctx) as Point2D;
      segments.add(
        CubicSegment(
          lastPt.x,
          lastPt.y,
          cp1Pt.x,
          cp1Pt.y,
          cp2Pt.x,
          cp2Pt.y,
          toPt.x,
          toPt.y,
        ),
      );
      lastPt = toPt;
    }
  }

  return segments;
}

/// Helper: hitung ArcSegment dari 3 titik.
ArcSegment? _computeArcSegmentFrom3Points(Point2D p1, Point2D mid, Point2D p2) {
  // Cari pusat lingkaran dari 3 titik
  final ax = p1.x;
  final ay = p1.y;
  final bx = mid.x;
  final by = mid.y;
  final cx = p2.x;
  final cy = p2.y;

  final d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
  if (d.abs() < 1e-9) return null; // kolinear

  final ux =
      ((ax * ax + ay * ay) * (by - cy) +
          (bx * bx + by * by) * (cy - ay) +
          (cx * cx + cy * cy) * (ay - by)) /
      d;
  final uy =
      ((ax * ax + ay * ay) * (cx - bx) +
          (bx * bx + by * by) * (ax - cx) +
          (cx * cx + cy * cy) * (bx - ax)) /
      d;

  final radius = math.sqrt((ax - ux) * (ax - ux) + (ay - uy) * (ay - uy));

  // Tentukan sweep direction menggunakan cross product
  final cross = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
  final sweep = cross > 0 ? 0 : 1;

  // Large arc: hitung sudut dari center ke p1 dan p2
  final a1 = math.atan2(ay - uy, ax - ux);
  double a2 = math.atan2(cy - uy, cx - ux);
  double deltaAngle = a2 - a1;
  if (sweep == 1 && deltaAngle > 0) deltaAngle -= 2 * math.pi;
  if (sweep == 0 && deltaAngle < 0) deltaAngle += 2 * math.pi;
  final largeArc = deltaAngle.abs() > math.pi ? 1 : 0;

  return ArcSegment(
    x1: ax,
    y1: ay,
    x2: cx,
    y2: cy,
    cx: ux,
    cy: uy,
    radius: radius,
    sweep: sweep,
    largeArc: largeArc,
  );
}

ResolvedPath resolvePath(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final ev = Evaluator(evalCtx);
  final closed = obj['closed'] == true;

  List<Point2D> points = [];
  if (obj.containsKey('points')) {
    final List<dynamic> rawPts = obj['points'] as List;
    for (final pt in rawPts) {
      final p = resolveAnchorValue(pt, ctx) as Point2D;
      points.add(p);
    }
  }

  List<PathResolvedSegment> segments = [];
  if (obj.containsKey('segments')) {
    final List<dynamic> rawSegs = obj['segments'] as List;
    segments = parsePathSegments(
      rawSegs,
      ctx,
      initialPoint: points.isNotEmpty ? points.first : null,
    );
  }

  // ─── Path Offset (spec v0.3 §12) ───
  if (obj.containsKey('offset') && obj['offset'] is Map) {
    final offsetSpec = obj['offset'] as Map;
    final fromId = offsetSpec['from']?.toString();
    final distExpr = offsetSpec['distance'];
    final side = offsetSpec['side']?.toString() ?? 'outside';

    if (fromId != null) {
      final sourceObj = ctx.objects[fromId];
      if (sourceObj != null) {
        List<Point2D> sourcePts = [];
        bool sourceClosed = false;
        if (sourceObj is ResolvedPath) {
          sourcePts = sourceObj.segments.isNotEmpty
              ? pointsFromSegments(sourceObj.segments)
              : sourceObj.points;
          sourceClosed = sourceObj.closed;
        } else if (sourceObj is ResolvedPolygon) {
          sourcePts = sourceObj.points;
          sourceClosed = true;
        }

        if (sourcePts.isNotEmpty) {
          final dist = normalizeUnit(ev.evaluate(distExpr), ctx.targetUnit);
          final offsetPoints = pm.offsetPolyline(
            sourcePts,
            dist,
            side,
            sourceClosed,
          );
          points = offsetPoints;
          segments = [];
        }
      }
    }
  }

  // ─── Corner Modifiers: fillet/chamfer (spec v0.3 §11) ───
  if (segments.isEmpty && points.isNotEmpty) {
    // Konversi points ke segments dulu
    final tempSegs = <PathResolvedSegment>[];
    for (int i = 0; i < points.length - 1; i++) {
      tempSegs.add(
        LineSegment(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y),
      );
    }
    if (closed && points.length > 1) {
      tempSegs.add(
        LineSegment(
          points.last.x,
          points.last.y,
          points.first.x,
          points.first.y,
        ),
      );
    }
    segments = tempSegs;
    points = [];
  }

  // Apply corner modifiers dari `corners` (granular) atau `corner.all` (global)
  Map<String, dynamic>? cornersMap;
  if (obj.containsKey('corners') && obj['corners'] is Map) {
    cornersMap = Map<String, dynamic>.from(obj['corners'] as Map);
  } else if (obj.containsKey('corner') && obj['corner'] is Map) {
    final cornerSpec = obj['corner'] as Map;
    if (cornerSpec.containsKey('all')) {
      cornersMap = {'all': cornerSpec['all']};
    }
  }

  if (cornersMap != null && segments.isNotEmpty) {
    // Normalisasi nilai corner (bisa berupa ekspresi)
    final normalizedCorners = <String, dynamic>{};
    for (final entry in cornersMap.entries) {
      final spec = entry.value;
      if (spec is Map) {
        final normalized = <String, dynamic>{};
        if (spec.containsKey('fillet')) {
          normalized['fillet'] = normalizeUnit(
            ev.evaluate(spec['fillet']),
            ctx.targetUnit,
          );
        }
        if (spec.containsKey('chamfer')) {
          normalized['chamfer'] = normalizeUnit(
            ev.evaluate(spec['chamfer']),
            ctx.targetUnit,
          );
        }
        normalizedCorners[entry.key.toString()] = normalized;
      } else {
        normalizedCorners[entry.key.toString()] = spec;
      }
    }
    try {
      segments = pm.applyCornerModifiers(segments, normalizedCorners, closed);
    } catch (e) {
      throw Exception('INVALID_CORNER_OPERATION on "$id": $e');
    }
  }

  final bbox = segments.isNotEmpty
      ? geom.calculateBoundingBox({
          id: ResolvedPath(id: id, meta: Meta(), segments: segments),
        })
      : geom.calculateBoundingBox({
          id: ResolvedPath(id: id, meta: Meta(), points: points),
        });

  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final resolved = ResolvedPath(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    points: points.map((p) => (x: p.x + plRes.dx, y: p.y + plRes.dy)).toList(),
    segments: segments
        .map((s) => translateSegment(s, plRes.dx, plRes.dy))
        .toList(),
    closed: closed,
    transforms: plRes.transforms,
  );

  if (obj.containsKey('holes')) {
    final outerPoints = segments.isNotEmpty
        ? pointsFromSegments(segments)
        : points;
    final holes = resolveHolesProperty(
      id,
      obj['holes'] as List,
      outerPoints,
      ctx,
    );
    if (holes != null) resolved.holes.addAll(holes);
  }

  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedPolygon resolvePolygon(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final ev = Evaluator(evalCtx);

  List<Point2D> points = [];
  final List<dynamic> rawPts = obj['points'] as List;
  for (final pt in rawPts) {
    final p = resolveAnchorValue(pt, ctx) as Point2D;
    points.add(p);
  }

  // Bangun segments awal
  List<PathResolvedSegment> segments = [];
  for (int i = 0; i < points.length - 1; i++) {
    segments.add(
      LineSegment(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y),
    );
  }
  if (points.length > 1) {
    segments.add(
      LineSegment(points.last.x, points.last.y, points.first.x, points.first.y),
    );
  }

  // ─── Corner Modifiers (spec v0.3 §11) ───
  Map<String, dynamic>? cornersMap;
  if (obj.containsKey('corners') && obj['corners'] is Map) {
    cornersMap = Map<String, dynamic>.from(obj['corners'] as Map);
  } else if (obj.containsKey('corner') && obj['corner'] is Map) {
    final cornerSpec = obj['corner'] as Map;
    if (cornerSpec.containsKey('all')) {
      cornersMap = {'all': cornerSpec['all']};
    }
  }

  if (cornersMap != null && segments.isNotEmpty) {
    final normalizedCorners = <String, dynamic>{};
    for (final entry in cornersMap.entries) {
      final spec = entry.value;
      if (spec is Map) {
        final normalized = <String, dynamic>{};
        if (spec.containsKey('fillet')) {
          normalized['fillet'] = normalizeUnit(
            ev.evaluate(spec['fillet']),
            ctx.targetUnit,
          );
        }
        if (spec.containsKey('chamfer')) {
          normalized['chamfer'] = normalizeUnit(
            ev.evaluate(spec['chamfer']),
            ctx.targetUnit,
          );
        }
        normalizedCorners[entry.key.toString()] = normalized;
      } else {
        normalizedCorners[entry.key.toString()] = spec;
      }
    }
    try {
      segments = pm.applyCornerModifiers(segments, normalizedCorners, true);
      points = []; // pakai segments sekarang
    } catch (e) {
      throw Exception('INVALID_CORNER_OPERATION on "$id": $e');
    }
  }

  final bbox = segments.isNotEmpty
      ? geom.calculateBoundingBox({
          id: ResolvedPolygon(
            id: id,
            meta: Meta(),
            points: const [],
            segments: segments,
          ),
        })
      : geom.calculateBoundingBox({
          id: ResolvedPolygon(id: id, meta: Meta(), points: points),
        });
  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final resolved = ResolvedPolygon(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    points: points.map((p) => (x: p.x + plRes.dx, y: p.y + plRes.dy)).toList(),
    segments: segments
        .map((s) => translateSegment(s, plRes.dx, plRes.dy))
        .toList(),
    transforms: plRes.transforms,
  );

  if (obj.containsKey('holes')) {
    final holes = resolveHolesProperty(id, obj['holes'] as List, points, ctx);
    if (holes != null) resolved.holes.addAll(holes);
  }

  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedBoolean resolveBoolean(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final operation = obj['operation']?.toString() ?? 'union';
  final List<ClosedShapeInput> normalizedShapes = [];

  if (obj.containsKey('shapes')) {
    final List<dynamic> shapesRefs = obj['shapes'] as List;
    for (final ref in shapesRefs) {
      final resolvedRef = ctx.objects[ref.toString()];
      if (resolvedRef != null) {
        normalizedShapes.add(normalizeClosedShape(resolvedRef, ctx.objects));
      }
    }
  } else if (obj.containsKey('base') && obj.containsKey('tools')) {
    final baseRef = ctx.objects[obj['base'].toString()];
    if (baseRef != null) {
      normalizedShapes.add(normalizeClosedShape(baseRef, ctx.objects));
    }
    final List<dynamic> toolsRefs = obj['tools'] as List;
    for (final ref in toolsRefs) {
      final resolvedRef = ctx.objects[ref.toString()];
      if (resolvedRef != null) {
        normalizedShapes.add(normalizeClosedShape(resolvedRef, ctx.objects));
      }
    }
  }

  final engine = ClipperBooleanEngine();
  List<ClosedShapeInput> booleanResult = [];

  if (operation == 'union') {
    booleanResult = engine.union(normalizedShapes);
  } else if (operation == 'subtract' && normalizedShapes.isNotEmpty) {
    booleanResult = engine.subtract(
      normalizedShapes[0],
      normalizedShapes.sublist(1),
    );
  } else if (operation == 'intersect') {
    booleanResult = engine.intersect(normalizedShapes);
  } else if (operation == 'xor') {
    booleanResult = engine.xor(normalizedShapes);
  }

  final List<Point2D> finalPoints = [];
  final List<PathResolvedSegment> finalSegments = [];
  final List<ResolvedHole> finalHoles = [];

  for (final island in booleanResult) {
    finalPoints.addAll(island.outer);
    finalSegments.addAll(polyToSegments(island.outer));
    if (island.holes != null) {
      for (final h in island.holes!) {
        finalHoles.add(ResolvedHole(polyToSegments(h)));
      }
    }
  }

  // Calculate bbox of finalPoints to apply placement and transform
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = -double.infinity;
  double maxY = -double.infinity;

  if (finalPoints.isNotEmpty) {
    for (final p in finalPoints) {
      if (p.x.isFinite && p.y.isFinite) {
        minX = math.min(minX, p.x);
        minY = math.min(minY, p.y);
        maxX = math.max(maxX, p.x);
        maxY = math.max(maxY, p.y);
      }
    }
  }

  final bbox = BoundingBox(
    x: finalPoints.isEmpty ? 0.0 : minX,
    y: finalPoints.isEmpty ? 0.0 : minY,
    width: finalPoints.isEmpty ? 0.0 : (maxX - minX),
    height: finalPoints.isEmpty ? 0.0 : (maxY - minY),
  );

  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  // Apply placement translation to points, segments, and holes
  final translatedPoints = finalPoints
      .map((p) => (x: p.x + plRes.dx, y: p.y + plRes.dy))
      .toList();
  final translatedSegments = finalSegments
      .map((s) => translateSegment(s, plRes.dx, plRes.dy))
      .toList();
  final translatedHoles = finalHoles
      .map(
        (h) => ResolvedHole(
          h.segments
              .map((s) => translateSegment(s, plRes.dx, plRes.dy))
              .toList(),
        ),
      )
      .toList();

  final resolved = ResolvedBoolean(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    operation: operation,
    points: translatedPoints,
    segments: translatedSegments,
    holes: translatedHoles,
    transforms: plRes.transforms,
  );
  final anchors = resolveCustomAnchors(obj, resolved, ctx);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedGroup resolveGroup(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final List<dynamic> rawChildren = obj['children'] as List;
  final List<String> children = rawChildren.map((c) => c.toString()).toList();

  final bbox = geom.calculateBoundingBox(ctx.objects, targetIds: children);
  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final List<ResolvedTransformOp> finalTransform = [...plRes.transforms];
  if (plRes.dx != 0.0 || plRes.dy != 0.0) {
    finalTransform.insert(0, TranslateOp(plRes.dx, plRes.dy));
  }

  final resolved = ResolvedGroup(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    children: children,
    transforms: finalTransform,
  );
  final anchors = resolveCustomAnchors(obj, resolved, ctx, bbox);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedClone resolveClone(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final targetId = obj['of'].toString();
  final target = ctx.objects[targetId];
  if (target == null) {
    throw Exception('Clone target "$targetId" not found.');
  }
  // TIDAK memasukkan targetId ke parentMap — objek asli harus tetap di posisinya.
  // Clone hanya menyimpan referensi dan transform-nya sendiri.
  // Rendering clone dilakukan secara aktif di canvas_painter.

  final bbox = geom.calculateBoundingBox(ctx.objects, targetIds: [targetId]);
  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final List<ResolvedTransformOp> finalTransform = [...plRes.transforms];
  if (plRes.dx != 0.0 || plRes.dy != 0.0) {
    finalTransform.insert(0, TranslateOp(plRes.dx, plRes.dy));
  }

  final resolved = ResolvedClone(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    children: [targetId],
    of: targetId,
    transforms: finalTransform,
  );
  final anchors = resolveCustomAnchors(obj, resolved, ctx, bbox);
  if (anchors != null) resolved.anchors.addAll(anchors);

  return resolved;
}

ResolvedCollection resolveRepeat(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  final item = obj['item'] as Map;
  final List<String> childrenIds = [];

  if (obj.containsKey('along')) {
    final along = obj['along'] as Map;
    final targetId = along['target'].toString();
    final targetObj = ctx.objects[targetId];
    if (targetObj == null) {
      throw Exception(
        'INVALID_REPEAT_ALONG_TARGET: repeat.along target not found: $targetId',
      );
    }

    final totalLength = (ev.evaluate('length($targetId)') as num).toDouble();
    if (!totalLength.isFinite || totalLength <= 0) {
      throw Exception(
        'INVALID_REPEAT_ALONG_TARGET: target "$targetId" does not expose usable path length',
      );
    }

    final startOffset = along.containsKey('startOffset')
        ? normalizeUnit(ev.evaluate(along['startOffset']), ctx.targetUnit)
        : 0.0;
    final endOffset = along.containsKey('endOffset')
        ? normalizeUnit(ev.evaluate(along['endOffset']), ctx.targetUnit)
        : 0.0;

    final usableLength = totalLength - startOffset - endOffset;
    if (!startOffset.isFinite || !endOffset.isFinite || usableLength < 0) {
      throw Exception(
        'INVALID_REPEAT_ALONG_SPACING: invalid repeat.along offsets for "$id"',
      );
    }

    final spacing = along['spacing']?.toString();
    final isClosed = isClosedPathLikeObject(targetObj);
    final hasExplicitPosition = hasExplicitRepeatPosition(item);

    int count = 0;
    double distanceStep = 0.0;

    if (spacing == 'fixed-distance') {
      if (along.containsKey('count')) {
        throw Exception(
          'INVALID_REPEAT_ALONG_SPACING: fixed-distance does not allow explicit count in v0.5',
        );
      }
      distanceStep = normalizeUnit(
        ev.evaluate(along['distance']),
        ctx.targetUnit,
      );
      if (!distanceStep.isFinite || distanceStep <= 0) {
        throw Exception(
          'INVALID_FIXED_DISTANCE: repeat.along distance must be a positive length, got ${along['distance']}',
        );
      }
      count = (usableLength / distanceStep).floor() + 1;
    } else {
      count = (ev.evaluate(along['count']) as num).toInt();
      if (count <= 0) {
        throw Exception(
          'INVALID_REPEAT_COUNT: repeat.along count must be a positive integer, got ${along['count']}',
        );
      }
    }

    for (int i = 0; i < count; i++) {
      double distance = startOffset;
      double t = 0.0;

      if (spacing == 'uniform-length') {
        if (count == 1) {
          distance = startOffset;
        } else if (isClosed) {
          distance = startOffset + (usableLength * i) / count;
        } else {
          distance = startOffset + (usableLength * i) / (count - 1);
        }
        t = (ev.evaluate('tAtLength($targetId, $distance)') as num).toDouble();
      } else if (spacing == 'uniform-t') {
        t = count == 1 ? 0.0 : i / (count - 1);
        distance = startOffset + usableLength * t;
      } else if (spacing == 'fixed-distance') {
        distance = startOffset + i * distanceStep;
        t = (ev.evaluate('tAtLength($targetId, $distance)') as num).toDouble();
      } else {
        throw Exception(
          'INVALID_REPEAT_ALONG_SPACING: unsupported repeat.along spacing "$spacing"',
        );
      }

      final point = toPoint2D(ev.evaluate('pointAt($targetId, $t)'));
      final tangent = toPoint2D(ev.evaluate('tangentAt($targetId, $t)'));
      final normal = toPoint2D(ev.evaluate('normalAt($targetId, $t)'));
      final frameValue = ev.evaluate('frameAt($targetId, $t)');
      final frame = frameValue is Map
          ? Map<String, dynamic>.from(frameValue)
          : <String, dynamic>{};
      final angle = frame['angle'] is num
          ? (frame['angle'] as num).toDouble()
          : 0.0;

      if (point == null || tangent == null || normal == null) {
        throw Exception(
          'INVALID_REPEAT_ALONG_TARGET: failed to sample frame along "$targetId"',
        );
      }

      final childId = '$id[$i]';
      final childScalars = Map<String, dynamic>.from(ctx.scalars);
      childScalars['index'] = i.toDouble();
      childScalars['count'] = count.toDouble();
      childScalars['row'] = 0.0;
      childScalars['col'] = i.toDouble();
      childScalars['item'] = {
        'x': point.x,
        'y': point.y,
        't': t,
        'point': point,
        'position': point,
        'tangent': tangent,
        'normal': normal,
        'frame': {
          ...frame,
          'point': frame['point'] ?? point,
          'tangent': frame['tangent'] ?? tangent,
          'normal': frame['normal'] ?? normal,
          'angle': angle,
        },
        'angle': angle,
        'distance': distance,
      };

      final childObjects = Map<String, ResolvedObject>.from(ctx.objects);
      final childCtx = ResolveContext(
        scalars: childScalars,
        objects: childObjects,
        targetUnit: ctx.targetUnit,
        parentMap: ctx.parentMap,
        mode: ctx.mode,
        textMetrics: ctx.textMetrics,
        doc: ctx.doc,
        currentObjectId: childId,
      );

      final resolvedChild = resolveObject(childId, item, childCtx);
      if (!hasExplicitPosition) {
        resolvedChild.transforms.insert(0, TranslateOp(point.x, point.y));
      }

      ctx.objects[childId] = resolvedChild;
      ctx.parentMap[childId] = id;
      childrenIds.add(childId);

      for (final entry in childCtx.objects.entries) {
        if (entry.key.startsWith('$childId.') ||
            entry.key.startsWith('$childId[')) {
          ctx.objects[entry.key] = entry.value;
        }
      }
    }
  } else if (obj.containsKey('grid')) {
    final grid = obj['grid'] as Map;
    final int rows = ev.evaluate(grid['rows']).toInt();
    final int cols = ev.evaluate(grid['cols']).toInt();

    double gapX = 0.0;
    double gapY = 0.0;
    bool hasGap = false;
    if (grid.containsKey('gap')) {
      gapX = normalizeUnit(ev.evaluate(grid['gap']), ctx.targetUnit);
      gapY = gapX;
      hasGap = true;
    }
    if (grid.containsKey('gapX')) {
      gapX = normalizeUnit(ev.evaluate(grid['gapX']), ctx.targetUnit);
      hasGap = true;
    }
    if (grid.containsKey('gapY')) {
      gapY = normalizeUnit(ev.evaluate(grid['gapY']), ctx.targetUnit);
      hasGap = true;
    }

    if (hasGap &&
        (obj.containsKey('place') || obj.containsKey('on')) &&
        (item.containsKey('place') || item.containsKey('on'))) {
      throw Exception(
        'OVER_CONSTRAINED: Repeat object and its item both define placement while using gap. This is over-constrained.',
      );
    }

    // Jika item punya place/on, gap harus diabaikan (penempatan manual)
    if (item.containsKey('place') || item.containsKey('on')) {
      hasGap = false;
    }

    double currentY = 0.0;

    for (int r = 0; r < rows; r++) {
      double currentX = 0.0;
      double maxRowHeight = 0.0;

      for (int c = 0; c < cols; c++) {
        final childId = '$id[$r,$c]';

        final childScalars = Map<String, dynamic>.from(ctx.scalars);
        childScalars['row'] = r.toDouble();
        childScalars['col'] = c.toDouble();
        childScalars['rows'] = rows.toDouble();
        childScalars['cols'] = cols.toDouble();

        final childObjects = Map<String, ResolvedObject>.from(ctx.objects);

        final childCtx = ResolveContext(
          scalars: childScalars,
          objects: childObjects,
          targetUnit: ctx.targetUnit,
          parentMap: ctx.parentMap,
          mode: ctx.mode,
          textMetrics: ctx.textMetrics,
          doc: ctx.doc,
          currentObjectId: childId,
        );

        final resolvedChild = resolveObject(childId, item, childCtx);

        if (hasGap) {
          final tempObjects = {childId: resolvedChild, ...childCtx.objects};
          final childBbox = geom.calculateBoundingBox(
            tempObjects,
            targetIds: [childId],
          );
          final dx = currentX - childBbox.x;
          final dy = currentY - childBbox.y;
          if (dx != 0.0 || dy != 0.0) {
            resolvedChild.transforms.insert(0, TranslateOp(dx, dy));
          }
          currentX += childBbox.width + gapX;
          if (childBbox.height > maxRowHeight) {
            maxRowHeight = childBbox.height;
          }
        }

        ctx.objects[childId] = resolvedChild;
        ctx.parentMap[childId] = id;
        childrenIds.add(childId);

        for (final entry in childCtx.objects.entries) {
          if (entry.key.startsWith('$childId.') ||
              entry.key.startsWith('$childId[')) {
            ctx.objects[entry.key] = entry.value;
          }
        }
      }
      if (hasGap) {
        currentY += maxRowHeight + gapY;
      }
    }
  } else if (obj.containsKey('each')) {
    final eachId = obj['each'].toString();
    final eachObj = ctx.objects[eachId];
    if (eachObj is ResolvedCollection) {
      for (int i = 0; i < eachObj.children.length; i++) {
        final childId = eachObj.children[i];
        final repeatChildId = '$id[$i]';

        final childScalars = Map<String, dynamic>.from(ctx.scalars);
        childScalars['index'] = i.toDouble();

        final childObjects = Map<String, ResolvedObject>.from(ctx.objects);
        final targetObj = ctx.objects[childId];
        if (targetObj != null) {
          childObjects['item'] = targetObj;
        }

        final childCtx = ResolveContext(
          scalars: childScalars,
          objects: childObjects,
          targetUnit: ctx.targetUnit,
          parentMap: ctx.parentMap,
          mode: ctx.mode,
          textMetrics: ctx.textMetrics,
          doc: ctx.doc,
          currentObjectId: repeatChildId,
        );

        final resolvedChild = resolveObject(repeatChildId, item, childCtx);

        ctx.objects[repeatChildId] = resolvedChild;
        ctx.parentMap[repeatChildId] = id;
        childrenIds.add(repeatChildId);

        // Hanya salin entri dengan prefix repeatChildId ke ctx parent.
        // Entri pendek (e.g. 'head', 'shaft') adalah namespace lokal komponen
        // dan tidak boleh bocor ke parent scope — ini yang menyebabkan double-transform.
        for (final entry in childCtx.objects.entries) {
          if (entry.key.startsWith('$repeatChildId.') ||
              entry.key.startsWith('$repeatChildId[')) {
            ctx.objects[entry.key] = entry.value;
          }
        }
      }
    }
  } else if (obj.containsKey('count')) {
    final int count = ev.evaluate(obj['count']).toInt();
    for (int i = 0; i < count; i++) {
      final childId = '$id[$i]';

      final childScalars = Map<String, dynamic>.from(ctx.scalars);
      childScalars['index'] = i.toDouble();
      childScalars['count'] = count.toDouble();

      final childObjects = Map<String, ResolvedObject>.from(ctx.objects);

      final childCtx = ResolveContext(
        scalars: childScalars,
        objects: childObjects,
        targetUnit: ctx.targetUnit,
        parentMap: ctx.parentMap,
        mode: ctx.mode,
        textMetrics: ctx.textMetrics,
        doc: ctx.doc,
        currentObjectId: childId,
      );

      final resolvedChild = resolveObject(childId, item, childCtx);

      ctx.objects[childId] = resolvedChild;
      ctx.parentMap[childId] = id;
      childrenIds.add(childId);

      for (final entry in childCtx.objects.entries) {
        if (entry.key.startsWith('$childId.') ||
            entry.key.startsWith('$childId[')) {
          ctx.objects[entry.key] = entry.value;
        }
      }
    }
  }

  final bbox = geom.calculateBoundingBox(ctx.objects, targetIds: childrenIds);
  final plRes = applyObjectPlacementAndTransform(obj, bbox, ctx);

  final List<ResolvedTransformOp> finalTransform = [...plRes.transforms];
  if (plRes.dx != 0.0 || plRes.dy != 0.0) {
    finalTransform.insert(0, TranslateOp(plRes.dx, plRes.dy));
  }

  final collection = ResolvedCollection(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    children: childrenIds,
    transforms: finalTransform,
  );

  final anchors = resolveCustomAnchors(obj, collection, ctx, bbox);
  if (anchors != null) collection.anchors.addAll(anchors);

  return collection;
}

ResolvedCollection resolveDivide(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  final int count = ev.evaluate(obj['count']).toInt();
  final targetId = obj['target'].toString();
  final targetObj = ctx.objects[targetId];
  if (targetObj == null) {
    throw Exception('Target object not found for divide: $targetId');
  }

  final bool isClosed =
      targetObj is ResolvedCircle ||
      targetObj is ResolvedEllipse ||
      targetObj is ResolvedRect ||
      targetObj is ResolvedPolygon;
  final List<Point2D> points = [];

  if (isClosed) {
    for (int i = 0; i < count; i++) {
      final double t = i / count;
      final pt = toPoint2D(ev.evaluate('pointAt($targetId, $t)'));
      if (pt != null) {
        points.add(pt);
      }
    }
  } else {
    final int denom = count > 1 ? count - 1 : 1;
    for (int i = 0; i < count; i++) {
      final double t = i / denom;
      final pt = toPoint2D(ev.evaluate('pointAt($targetId, $t)'));
      if (pt != null) {
        points.add(pt);
      }
    }
  }

  final List<String> childrenIds = [];
  for (int i = 0; i < points.length; i++) {
    final childId = '$id[$i]';
    ctx.objects[childId] = ResolvedPoint(
      id: childId,
      meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
      x: points[i].x,
      y: points[i].y,
    );
    ctx.parentMap[childId] = id;
    childrenIds.add(childId);
  }

  return ResolvedCollection(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    children: childrenIds,
  );
}

ResolvedComponent resolveComponent(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final compName = obj['use'].toString();
  final compDef = ctx.doc['components'][compName] as Map;

  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  final Map<String, dynamic> localScalars = {};

  // Muat parameter default
  if (compDef.containsKey('parameters')) {
    for (final entry in (compDef['parameters'] as Map).entries) {
      final pName = entry.key.toString();
      final pDef = entry.value;
      dynamic defaultVal = pDef;
      if (pDef is Map && pDef.containsKey('default')) {
        defaultVal = pDef['default'];
      }
      localScalars[pName] = defaultVal is String
          ? ev.evaluate(defaultVal)
          : defaultVal;
    }
  }

  // Override parameter
  if (obj.containsKey('params')) {
    final inheritedParams = (obj['params'] as Map).containsKey('inherit')
        ? resolveStructuredInherit((obj['params'] as Map)['inherit'], ctx)
        : <String, dynamic>{};

    for (final entry in inheritedParams.entries) {
      final pName = entry.key.toString();
      final pVal = entry.value;
      localScalars[pName] = pVal is String ? ev.evaluate(pVal) : pVal;
    }

    for (final entry in (obj['params'] as Map).entries) {
      final pName = entry.key.toString();
      if (pName == 'inherit') continue;
      final pVal = entry.value;
      localScalars[pName] = pVal is String ? ev.evaluate(pVal) : pVal;
    }
  }

  final nestedCtx = ResolveContext(
    scalars: {...ctx.scalars, ...localScalars},
    objects: {...ctx.objects},
    targetUnit: ctx.targetUnit,
    parentMap: ctx.parentMap,
    mode: ctx.mode,
    textMetrics: ctx.textMetrics,
    doc: ctx.doc,
  );

  final innerObjects = compDef['objects'] as Map;
  final unifiedOrder = sortUnified(
    Map<String, dynamic>.from(innerObjects),
    Map<String, dynamic>.from(compDef['derived'] ?? {}),
  );

  final List<String> children = [];
  for (final node in unifiedOrder) {
    if (node.kind == 'object') {
      final innerObj = innerObjects[node.id] as Map;
      final prefixedId = '$id.${node.id}';
      nestedCtx.currentObjectId = prefixedId;
      final resolvedInner = resolveObject(prefixedId, innerObj, nestedCtx);
      nestedCtx.objects[node.id] = resolvedInner;
      ctx.objects[prefixedId] = resolvedInner;
      ctx.parentMap[prefixedId] = id;
      children.add(prefixedId);
    } else {
      // derived node
      final derivedDef = compDef['derived'][node.id];
      final expr = derivedDef is Map && derivedDef.containsKey('value')
          ? derivedDef['value']
          : derivedDef;
      final result = Evaluator(createEvalContext(nestedCtx)).evaluate(expr);
      nestedCtx.scalars[node.id] = result;
    }
  }

  // Exports
  final Map<String, Point2D> resolvedAnchors = {};
  if (compDef.containsKey('exports')) {
    for (final entry in (compDef['exports'] as Map).entries) {
      final expName = entry.key.toString();
      final expExpr = entry.value.toString();
      final expVal = toPoint2D(
        Evaluator(createEvalContext(nestedCtx)).evaluate(expExpr),
      );
      if (expVal != null) {
        resolvedAnchors[expName] = expVal;
      }
    }
  }

  final bbox = geom.calculateBoundingBox({
    for (final cid in children) cid: ctx.objects[cid]!,
  });
  final plRes = applyObjectPlacementAndTransform(
    obj,
    bbox,
    ctx,
    resolvedAnchors,
  );
  final finalTransform = [...plRes.transforms];
  if (plRes.dx != 0.0 || plRes.dy != 0.0) {
    finalTransform.insert(0, TranslateOp(plRes.dx, plRes.dy));
  }

  return ResolvedComponent(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    children: children,
    hasExports: resolvedAnchors.isNotEmpty,
    transforms: finalTransform,
  )..anchors.addAll(resolvedAnchors);
}

ResolvedDimension resolveDimension(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final evalCtx = createEvalContext(ctx);
  final Evaluator ev = Evaluator(evalCtx);

  final kind = obj['kind']?.toString() ?? 'linear';
  final target = obj['target']?.toString();
  final between =
      (obj['between'] as List?)?.map((entry) => entry.toString()).toList() ??
      const <String>[];
  Point2D? fromPt;
  Point2D? toPt;
  double? distance;
  double? angle;
  double offset = kind == 'linear' ? 15.0 : 0.0;
  String distanceLabel = '';
  String radiusLabel = '';
  String diameterLabel = '';
  String angleLabel = '';

  if (kind == 'linear') {
    final p1 = resolveAnchorValue(obj['from'], ctx);
    final p2 = resolveAnchorValue(obj['to'], ctx);
    fromPt = toPoint2D(p1);
    toPt = toPoint2D(p2);
    if (obj.containsKey('offset')) {
      offset = normalizeUnit(ev.evaluate(obj['offset']), ctx.targetUnit);
    }
    if (fromPt != null && toPt != null) {
      distance = geom.hypot(toPt.x - fromPt.x, toPt.y - fromPt.y);
      distanceLabel = '${(distance * 100).round() / 100}${ctx.targetUnit.name}';
    }
  } else if (kind == 'radius' || kind == 'diameter') {
    final targetObj = target != null ? ctx.objects[target] : null;
    double radius = 0.0;
    if (targetObj is ResolvedCircle) {
      radius = targetObj.radius;
    } else if (targetObj is ResolvedEllipse) {
      radius = math.max(targetObj.rx, targetObj.ry);
    } else if (targetObj is ResolvedArc) {
      radius = targetObj.radius;
    }
    radiusLabel = '${(radius * 100).round() / 100}${ctx.targetUnit.name}';
    diameterLabel =
        '${((radius * 2) * 100).round() / 100}${ctx.targetUnit.name}';
    if (kind == 'radius') {
      distance = radius;
      distanceLabel = radiusLabel;
    } else {
      distance = radius * 2;
      distanceLabel = diameterLabel;
    }
  } else if (kind == 'angle' && between.length == 2) {
    final line1 = ctx.objects[between[0]];
    final line2 = ctx.objects[between[1]];
    if (line1 is ResolvedLine && line2 is ResolvedLine) {
      final a1 = math.atan2(line1.y2 - line1.y1, line1.x2 - line1.x1);
      final a2 = math.atan2(line2.y2 - line2.y1, line2.x2 - line2.x1);
      var diffDeg = (a2 - a1).abs() * 180 / math.pi;
      while (diffDeg > 360) {
        diffDeg -= 360;
      }
      if (diffDeg > 180) {
        diffDeg = 360 - diffDeg;
      }
      angle = diffDeg;
      angleLabel = '${(diffDeg * 100).round() / 100}°';
      distanceLabel = angleLabel;
    }
  }

  String text = obj['text']?.toString() ?? '{distance}';
  text = text
      .replaceAll('{distance}', distanceLabel)
      .replaceAll('{radius}', radiusLabel)
      .replaceAll('{diameter}', diameterLabel)
      .replaceAll('{angle}', angleLabel);

  return ResolvedDimension(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    kind: kind,
    text: text,
    fromPoint: fromPt,
    toPoint: toPt,
    offset: offset,
    target: target,
    between: between,
    distance: distance,
    angle: angle,
  );
}

ResolvedAnnotation resolveAnnotation(
  String id,
  Map<dynamic, dynamic> obj,
  ResolveContext ctx,
) {
  final text = obj['text']?.toString() ?? '';
  Point2D? pFrom;
  Point2D? pTo;

  if (obj.containsKey('leader')) {
    final leader = obj['leader'] as Map;
    pFrom = resolveAnchorValue(leader['from'], ctx) as Point2D;
    pTo = resolveAnchorValue(leader['to'], ctx) as Point2D;
  }

  return ResolvedAnnotation(
    id: id,
    meta: Meta.fromJson(Map<String, dynamic>.from(obj['meta'] ?? {})),
    text: text,
    target: obj['target']?.toString(),
    leader: pFrom != null && pTo != null
        ? (fromPoint: pFrom, toPoint: pTo)
        : null,
  );
}

// ─────────────────────────────────────────────
// Resolusi Nilai & Parameter (values.ts setara)
// ─────────────────────────────────────────────

Map<String, dynamic> resolveValues(
  Map<dynamic, dynamic> doc,
  ResolveOptions options,
) {
  final targetUnit =
      options.targetUnit ??
      (doc['scene']?['unit'] != null
          ? LengthUnit.values.byName(doc['scene']['unit'].toString())
          : LengthUnit.px);
  final Map<String, dynamic> scalars = {};

  // 1. Parameter
  if (doc.containsKey('parameters')) {
    for (final entry in (doc['parameters'] as Map).entries) {
      final id = entry.key.toString();
      final param = entry.value;
      dynamic val = param is Map && param.containsKey('default')
          ? param['default']
          : param;

      // Profile override
      if (options.profile != null &&
          doc.containsKey('profiles') &&
          doc['profiles'].containsKey(options.profile)) {
        final prof = doc['profiles'][options.profile] as Map;
        if (prof.containsKey(id)) {
          val = prof[id];
        }
      }

      // Overrides
      if (options.overrides != null && options.overrides!.containsKey(id)) {
        scalars[id] = options.overrides![id];
      } else {
        scalars[id] = val is String ? normalizeUnit(val, targetUnit) : val;
      }
    }
  }

  // 2. Constants
  if (doc.containsKey('constants')) {
    for (final entry in (doc['constants'] as Map).entries) {
      final id = entry.key.toString();
      final val = entry.value;
      scalars[id] = val is String ? normalizeUnit(val, targetUnit) : val;
    }
  }

  // 3. Derived (Scalar-only loop)
  if (doc.containsKey('derived')) {
    final derived = doc['derived'] as Map;
    final derivedIds = derived.keys.map((k) => k.toString()).toSet();
    final sortedDerivedIds = sortNodes(derivedIds.toList(), (id) {
      final expr = derived[id] is Map && derived[id].containsKey('value')
          ? derived[id]['value']
          : derived[id];
      return getExpressionIdentifiers(
        expr.toString(),
      ).where((dep) => derivedIds.contains(dep) && dep != id).toList();
    });

    for (final id in sortedDerivedIds) {
      final def = derived[id];
      final expr = def is Map && def.containsKey('value') ? def['value'] : def;
      try {
        final mockCtx = SimpleEvalContext(
          scalars: scalars,
          targetUnit: targetUnit,
        );
        scalars[id] = Evaluator(mockCtx).evaluate(expr);
      } catch (e) {
        // Lewati karena mungkin mereferensikan geometri (akan diselesaikan di unified loop)
      }
    }
  }

  return scalars;
}

// ─────────────────────────────────────────────
// Orkes Utama Kompilator (resolveGeometry setara)
// ─────────────────────────────────────────────

Orientation _parseOrientation(dynamic raw) {
  switch (raw?.toString()) {
    case 'y-up':
      return Orientation.yUp;
    case 'y-down':
    default:
      return Orientation.yDown;
  }
}

Origin _parseOrigin(dynamic raw) {
  switch (raw?.toString()) {
    case 'bottom-left':
      return Origin.bottomLeft;
    case 'center':
      return Origin.center;
    case 'top-left':
    default:
      return Origin.topLeft;
  }
}

Meta? _metaFromDynamic(dynamic raw) {
  if (raw is! Map) return null;
  return Meta.fromJson(Map<String, dynamic>.from(raw));
}

double _parseScale(dynamic scale) {
  if (scale == null) return 1.0;
  if (scale is num) return scale.toDouble();
  final str = scale.toString().trim();
  final parts = str.split(':');
  if (parts.length == 2) {
    final numVal = double.tryParse(parts[0]);
    final denVal = double.tryParse(parts[1]);
    if (numVal != null && denVal != null && denVal != 0) {
      return numVal / denVal;
    }
  }
  return double.tryParse(str) ?? 1.0;
}

Map<String, ResolvedView> _resolveViews(
  Map? rawViews,
  Map<String, ResolvedObject> objects,
) {
  final resolvedViews = <String, ResolvedView>{};
  if (rawViews == null) return resolvedViews;

  void collectSubtree(
    String id,
    Map<String, ResolvedObject> bucket,
    List<String>? allowedRoles,
  ) {
    final obj = objects[id];
    if (obj == null) return;

    if (allowedRoles == null || allowedRoles.contains(obj.meta.role)) {
      bucket[id] = obj;
    }

    if (obj is BaseResolvedGroup) {
      for (final childId in obj.children) {
        collectSubtree(childId, bucket, allowedRoles);
      }
    }
  }

  for (final entry in rawViews.entries) {
    final viewId = entry.key.toString();
    if (entry.value is! Map) continue;
    final viewDef = entry.value as Map;
    final targetId = viewDef['target']?.toString();
    if (targetId == null || !objects.containsKey(targetId)) continue;

    List<String>? allowedRoles;
    final filter = viewDef['filter'];
    if (filter is Map && filter['roles'] is List) {
      allowedRoles = (filter['roles'] as List)
          .map((r) => r.toString())
          .toList();
    }

    final viewObjects = <String, ResolvedObject>{};
    collectSubtree(targetId, viewObjects, allowedRoles);

    final scaleFactor = _parseScale(viewDef['scale']);
    final bbox = geom.calculateBoundingBox(
      viewObjects,
      ignoreRoles: const ['construction', 'guide', 'centerline', 'hidden'],
    );

    resolvedViews[viewId] = ResolvedView(
      id: viewId,
      target: targetId,
      scale: viewDef['scale'] ?? '1:1',
      scaleFactor: scaleFactor,
      objects: viewObjects,
      bbox: BoundingBox(
        x: bbox.x * scaleFactor,
        y: bbox.y * scaleFactor,
        width: bbox.width * scaleFactor,
        height: bbox.height * scaleFactor,
      ),
      meta: _metaFromDynamic(viewDef['meta']),
    );
  }

  return resolvedViews;
}

Map<String, ResolvedSheet> _resolveSheets(
  Map? rawSheets,
  Map<String, ResolvedView> resolvedViews,
  Map<String, dynamic> scalars,
  LengthUnit targetUnit,
) {
  final resolvedSheets = <String, ResolvedSheet>{};
  if (rawSheets == null) return resolvedSheets;

  final evaluator = Evaluator(
    SimpleEvalContext(scalars: scalars, targetUnit: targetUnit),
  );

  double evalLength(dynamic expr) {
    final evaluated = expr is String ? evaluator.evaluate(expr) : expr;
    return normalizeUnit(evaluated, targetUnit) as double;
  }

  for (final entry in rawSheets.entries) {
    final sheetId = entry.key.toString();
    if (entry.value is! Map) continue;
    final sheetDef = entry.value as Map;
    final size = sheetDef['size'];

    double width = convertFromPx(convertToPx('297mm'), targetUnit);
    double height = convertFromPx(convertToPx('210mm'), targetUnit);

    if (size is String) {
      switch (size.toUpperCase()) {
        case 'A0':
          width = convertFromPx(convertToPx('1189mm'), targetUnit);
          height = convertFromPx(convertToPx('841mm'), targetUnit);
        case 'A1':
          width = convertFromPx(convertToPx('841mm'), targetUnit);
          height = convertFromPx(convertToPx('594mm'), targetUnit);
        case 'A2':
          width = convertFromPx(convertToPx('594mm'), targetUnit);
          height = convertFromPx(convertToPx('420mm'), targetUnit);
        case 'A3':
          width = convertFromPx(convertToPx('420mm'), targetUnit);
          height = convertFromPx(convertToPx('297mm'), targetUnit);
        case 'A4':
          width = convertFromPx(convertToPx('297mm'), targetUnit);
          height = convertFromPx(convertToPx('210mm'), targetUnit);
      }
    } else if (size is List && size.length == 2) {
      width = evalLength(size[0]);
      height = evalLength(size[1]);
    }

    if (sheetDef['orientation']?.toString() == 'portrait') {
      final temp = width;
      width = height;
      height = temp;
    }

    final placements = <ResolvedSheetView>[];
    final rawPlacements = sheetDef['views'];
    if (rawPlacements is List) {
      for (final rawPlacement in rawPlacements) {
        if (rawPlacement is! Map) continue;
        final use = rawPlacement['use']?.toString();
        final view = use != null ? resolvedViews[use] : null;
        if (use == null || view == null) continue;

        double x = 0;
        double y = 0;
        final place = rawPlacement['place'];
        if (place is Map) {
          if (place['topLeft'] is List &&
              (place['topLeft'] as List).length == 2) {
            final topLeft = place['topLeft'] as List;
            x = evalLength(topLeft[0]);
            y = evalLength(topLeft[1]);
          } else if (place['center'] is List &&
              (place['center'] as List).length == 2) {
            final center = place['center'] as List;
            final cx = evalLength(center[0]);
            final cy = evalLength(center[1]);
            x = cx - view.bbox.width / 2;
            y = cy - view.bbox.height / 2;
          }
        }

        placements.add(
          ResolvedSheetView(
            use: use,
            x: x,
            y: y,
            width: view.bbox.width,
            height: view.bbox.height,
          ),
        );
      }
    }

    resolvedSheets[sheetId] = ResolvedSheet(
      id: sheetId,
      size: size ?? 'A4',
      width: width,
      height: height,
      views: placements,
      meta: _metaFromDynamic(sheetDef['meta']),
    );
  }

  return resolvedSheets;
}

ResolvedScene resolveGeometry(
  Map<dynamic, dynamic> doc, [
  ResolveOptions? options,
]) {
  final opt = options ?? ResolveOptions();
  final sceneBlock = doc['scene'] as Map?;
  final targetUnit =
      opt.targetUnit ??
      (sceneBlock?['unit'] != null
          ? LengthUnit.values.byName(sceneBlock!['unit'].toString())
          : LengthUnit.px);
  final textMetrics = opt.textMetrics ?? TextMetricsProvider();

  final scalars = resolveValues(doc, opt);
  final Map<String, ResolvedObject> objects = {};
  final Map<String, String> parentMap = {};

  // Membangun parent map untuk group & clone
  final rawObjects = doc['objects'] as Map;
  for (final entry in rawObjects.entries) {
    final id = entry.key.toString();
    final obj = entry.value as Map;
    if (obj['type'] == 'group' && obj.containsKey('children')) {
      for (final childId in (obj['children'] as List)) {
        parentMap[childId.toString()] = id;
      }
    }
  }

  final ctx = ResolveContext(
    scalars: scalars,
    objects: objects,
    targetUnit: targetUnit,
    parentMap: parentMap,
    mode: opt.mode,
    textMetrics: textMetrics,
    doc: doc,
  );

  // Toposort terpadu (derived + objects)
  final derived = doc['derived'] as Map? ?? {};
  final unifiedOrder = sortUnified(
    Map<String, dynamic>.from(rawObjects),
    Map<String, dynamic>.from(derived),
  );

  for (final node in unifiedOrder) {
    if (node.kind == 'object') {
      final innerObj = rawObjects[node.id] as Map;
      ctx.currentObjectId = node.id;
      final resolved = resolveObject(node.id, innerObj, ctx);
      objects[node.id] = resolved;
    } else {
      // Derived node - pastikan tidak ada currentObjectId aktif agar transforms tidak teraplikasi secara tidak sengaja
      ctx.currentObjectId = null;
      final derivedDef = derived[node.id];
      final expr = derivedDef is Map && derivedDef.containsKey('value')
          ? derivedDef['value']
          : derivedDef;
      final evalCtx = createEvalContext(ctx);
      final result = Evaluator(evalCtx).evaluate(expr);
      scalars[node.id] = result;
    }
  }

  // Urutkan ulang objects berdasarkan deklarasi deklaratif asli agar Z-order konsisten
  final Map<String, ResolvedObject> sortedObjects = {};
  for (final entry in rawObjects.entries) {
    final id = entry.key.toString();
    if (objects.containsKey(id)) {
      sortedObjects[id] = objects[id]!;
    }
  }
  // Masukkan sub-objek yang di-generate asinkron (repeat, divide)
  for (final entry in objects.entries) {
    if (!sortedObjects.containsKey(entry.key)) {
      sortedObjects[entry.key] = entry.value;
    }
  }

  // Hitung bbox global SEBELUM kita me-mutasi (flattening) transforms.
  // Karena calculateBoundingBox akan melakukan traversals yang juga menggabungkan
  // transforms parent secara rekursif. Jika sudah diflatten, transforms akan teraplikasi ganda.
  final bbox = geom.calculateBoundingBox(
    sortedObjects,
    parentMap: parentMap,
    ignoreRoles: const ['construction', 'guide', 'centerline', 'hidden'],
  );

  // Post-processing pass to propagate parent transforms and meta styles
  final Set<String> processedIds = {};
  for (final obj in sortedObjects.values) {
    if (processedIds.contains(obj.id)) continue;
    processedIds.add(obj.id);

    final List<ResolvedTransformOp> parentTransforms = [];
    Meta currentMeta = obj.meta;

    String? curr = parentMap[obj.id];
    while (curr != null) {
      final parentObj = sortedObjects[curr];
      if (parentObj != null) {
        if (parentObj.transforms.isNotEmpty) {
          parentTransforms.insertAll(0, parentObj.transforms);
        }
        currentMeta = Meta(
          visible: currentMeta.visible && parentObj.meta.visible,
          stroke: parentObj.meta.stroke ?? currentMeta.stroke,
          fill: parentObj.meta.fill ?? currentMeta.fill,
          strokeWidth: parentObj.meta.strokeWidth ?? currentMeta.strokeWidth,
          opacity:
              (parentObj.meta.opacity != null && currentMeta.opacity != null)
              ? parentObj.meta.opacity! * currentMeta.opacity!
              : (parentObj.meta.opacity ?? currentMeta.opacity),
          role: parentObj.meta.role != 'final'
              ? parentObj.meta.role
              : currentMeta.role,
          dash: parentObj.meta.dash ?? currentMeta.dash,
        );
      }
      curr = parentMap[curr];
    }

    if (parentTransforms.isNotEmpty) {
      obj.transforms = [...parentTransforms, ...obj.transforms];
    }
    obj.meta = currentMeta;
  }

  // Proses constraints setelah semua objek di-resolve
  final rawConstraints = doc['constraints'];
  final List<ConstraintViolation> violations = rawConstraints is List
      ? cst.processConstraints(rawConstraints, sortedObjects)
      : [];

  final resolvedViews = _resolveViews(doc['views'] as Map?, sortedObjects);
  final resolvedSheets = _resolveSheets(
    doc['sheets'] as Map?,
    resolvedViews,
    scalars,
    targetUnit,
  );

  return ResolvedScene(
    unit: targetUnit,
    orientation: _parseOrientation(sceneBlock?['orientation']),
    origin: _parseOrigin(sceneBlock?['origin']),
    autoSize: sceneBlock?['autoSize'] as bool? ?? true,
    padding: sceneBlock?['padding'] != null
        ? normalizeUnit(sceneBlock!['padding'], targetUnit) as double
        : normalizeUnit('20px', targetUnit) as double,
    objects: sortedObjects,
    parameters: Map<String, dynamic>.from(doc['parameters'] ?? {}),
    values: {
      for (final entry in scalars.entries)
        entry.key: entry.value is num
            ? (entry.value as num).toDouble()
            : entry.value,
    },
    bbox: bbox,
    meta: _metaFromDynamic(doc['meta']),
    violations: violations,
    sheets: resolvedSheets,
    views: resolvedViews,
  );
}

PathResolvedSegment translateSegment(
  PathResolvedSegment s,
  double dx,
  double dy,
) {
  if (s is LineSegment) {
    return LineSegment(s.x1 + dx, s.y1 + dy, s.x2 + dx, s.y2 + dy);
  } else if (s is ArcSegment) {
    return ArcSegment(
      x1: s.x1 + dx,
      y1: s.y1 + dy,
      x2: s.x2 + dx,
      y2: s.y2 + dy,
      cx: s.cx + dx,
      cy: s.cy + dy,
      radius: s.radius,
      sweep: s.sweep,
      largeArc: s.largeArc,
    );
  } else if (s is QuadraticSegment) {
    return QuadraticSegment(
      s.x1 + dx,
      s.y1 + dy,
      s.cpx + dx,
      s.cpy + dy,
      s.x2 + dx,
      s.y2 + dy,
    );
  } else if (s is CubicSegment) {
    return CubicSegment(
      s.x1 + dx,
      s.y1 + dy,
      s.cp1x + dx,
      s.cp1y + dy,
      s.cp2x + dx,
      s.cp2y + dy,
      s.x2 + dx,
      s.y2 + dy,
    );
  }
  return s;
}
