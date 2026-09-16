import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

Map<String, dynamic> projectScene(ResolvedScene scene) {
  return {
    'unit': _unitName(scene.unit),
    'autoSize': scene.autoSize,
    'padding': scene.padding,
    'objects': {
      for (final entry in scene.objects.entries)
        entry.key: _projectObject(entry.value),
    },
    'bbox': _projectBBox(scene.bbox),
    'violations': [
      for (final violation in scene.violations) _projectViolation(violation),
    ],
  };
}

void expectSemanticEqual(
  dynamic expected,
  dynamic actual, {
  String path = r'$',
  double tolerance = 1e-6,
}) {
  if (expected is num && actual is num) {
    expect(
      actual.toDouble(),
      closeTo(expected.toDouble(), tolerance),
      reason: path,
    );
    return;
  }

  if (expected is Map && actual is Map) {
    expect(actual.keys.toSet(), expected.keys.toSet(), reason: path);
    for (final key in expected.keys) {
      expectSemanticEqual(
        expected[key],
        actual[key],
        path: '$path.$key',
        tolerance: tolerance,
      );
    }
    return;
  }

  if (expected is List && actual is List) {
    expect(actual, hasLength(expected.length), reason: path);
    for (var index = 0; index < expected.length; index++) {
      expectSemanticEqual(
        expected[index],
        actual[index],
        path: '$path[$index]',
        tolerance: tolerance,
      );
    }
    return;
  }

  expect(actual, expected, reason: path);
}

/// Compares the contract projection after normalizing harmless engine-level
/// representation differences such as closed-ring duplication and rotation.
void expectCanonicalSemanticEqual(
  Map<String, dynamic> expected,
  Map<String, dynamic> actual,
) {
  expectSemanticEqual(
    _canonicalizeGeometry(expected),
    _canonicalizeGeometry(actual),
  );
}

String _unitName(LengthUnit unit) {
  return switch (unit) {
    LengthUnit.ip => 'in',
    _ => unit.name,
  };
}

Map<String, dynamic> _projectBBox(BoundingBox bbox) {
  return {'x': bbox.x, 'y': bbox.y, 'width': bbox.width, 'height': bbox.height};
}

Map<String, dynamic> _projectObject(ResolvedObject object) {
  final meta = _projectMeta(object.meta);
  return switch (object) {
    ResolvedPoint(:final id, :final x, :final y) => {
      'id': id,
      'type': 'point',
      'x': x,
      'y': y,
      'meta': meta,
    },
    ResolvedLine(:final id, :final x1, :final y1, :final x2, :final y2) => {
      'id': id,
      'type': 'line',
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'meta': meta,
    },
    ResolvedRect(:final id, :final x, :final y, :final width, :final height) =>
      {
        'id': id,
        'type': 'rect',
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'meta': meta,
      },
    ResolvedCircle(:final id, :final cx, :final cy, :final radius) => {
      'id': id,
      'type': 'circle',
      'cx': cx,
      'cy': cy,
      'radius': radius,
      'meta': meta,
    },
    ResolvedPolygon(:final id, :final points) => {
      'id': id,
      'type': 'polygon',
      'points': [
        for (final point in points) {'x': point.x, 'y': point.y},
      ],
      'meta': meta,
    },
    ResolvedBoolean(
      :final id,
      :final operation,
      :final points,
      :final segments,
      :final holes,
    ) =>
      {
        'id': id,
        'type': 'boolean',
        'operation': operation,
        'points': [
          for (final point in points) {'x': point.x, 'y': point.y},
        ],
        'segments': [for (final segment in segments) _projectSegment(segment)],
        'holes': [
          for (final hole in holes)
            {
              'segments': [
                for (final segment in hole.segments) _projectSegment(segment),
              ],
            },
        ],
        'meta': meta,
      },
    ResolvedText(
      :final id,
      :final x,
      :final y,
      :final width,
      :final height,
      :final content,
      :final anchor,
    ) =>
      {
        'id': id,
        'type': 'text',
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'content': content,
        'anchor': anchor,
        'meta': meta,
      },
    _ => throw UnsupportedError(
      'Semantic projection does not yet cover ${object.runtimeType}.',
    ),
  };
}

Map<String, dynamic> _projectMeta(Meta meta) {
  final result = <String, dynamic>{};
  if (!meta.visible) result['visible'] = false;
  if (meta.stroke != null) result['stroke'] = meta.stroke;
  if (meta.fill != null) result['fill'] = meta.fill;
  if (meta.strokeWidth != null) result['strokeWidth'] = meta.strokeWidth;
  if (meta.opacity != null) result['opacity'] = meta.opacity;
  if (meta.label != null) result['label'] = meta.label;
  if (meta.role != 'final') result['role'] = meta.role;
  if (meta.layer != null) result['layer'] = meta.layer;
  if (meta.dash != null) result['dash'] = meta.dash;
  if (meta.material != null) result['material'] = meta.material;
  if (meta.thickness != null) result['thickness'] = meta.thickness;
  if (meta.process != null) result['process'] = meta.process;
  if (meta.partNo != null) result['partNo'] = meta.partNo;
  if (meta.quantity != null) result['quantity'] = meta.quantity;
  if (meta.finish != null) result['finish'] = meta.finish;
  if (meta.tolerance != null) result['tolerance'] = meta.tolerance;
  result.addAll(meta.extra);
  return result;
}

Map<String, dynamic> _projectViolation(ConstraintViolation violation) {
  final result = <String, dynamic>{
    'type': violation.type,
    'message': violation.message,
    'deviation': violation.deviation,
    'path': violation.path,
    'involvedObjects': violation.involvedObjects,
  };
  final helper = violation.visualHelper;
  if (helper != null) {
    result['visualHelper'] = {
      'x1': helper.x1,
      'y1': helper.y1,
      'x2': helper.x2,
      'y2': helper.y2,
    };
  }
  return result;
}

Map<String, dynamic> _projectSegment(PathResolvedSegment segment) {
  return switch (segment) {
    LineSegment(:final x1, :final y1, :final x2, :final y2) => {
      'type': 'line',
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
    },
    ArcSegment(
      :final x1,
      :final y1,
      :final x2,
      :final y2,
      :final cx,
      :final cy,
      :final radius,
      :final sweep,
      :final largeArc,
    ) =>
      {
        'type': 'arc',
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        'cx': cx,
        'cy': cy,
        'radius': radius,
        'sweep': sweep,
        'largeArc': largeArc,
      },
    QuadraticSegment(
      :final x1,
      :final y1,
      :final cpx,
      :final cpy,
      :final x2,
      :final y2,
    ) =>
      {
        'type': 'quadratic',
        'x1': x1,
        'y1': y1,
        'cpx': cpx,
        'cpy': cpy,
        'x2': x2,
        'y2': y2,
      },
    CubicSegment(
      :final x1,
      :final y1,
      :final cp1x,
      :final cp1y,
      :final cp2x,
      :final cp2y,
      :final x2,
      :final y2,
    ) =>
      {
        'type': 'cubic',
        'x1': x1,
        'y1': y1,
        'cp1x': cp1x,
        'cp1y': cp1y,
        'cp2x': cp2x,
        'cp2y': cp2y,
        'x2': x2,
        'y2': y2,
      },
  };
}

dynamic _canonicalizeGeometry(dynamic value) {
  if (value is List) {
    return [for (final item in value) _canonicalizeGeometry(item)];
  }

  if (value is Map) {
    final result = <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _canonicalizeGeometry(entry.value),
    };

    if (result['meta'] is Map && (result['meta'] as Map).isEmpty) {
      result.remove('meta');
    }
    if (result['points'] is List) {
      result['points'] = _canonicalizeRing(result['points'] as List);
    }
    if (result['segments'] is List) {
      result['segments'] = _canonicalizeSegments(result['segments'] as List);
    }
    return result;
  }

  return value;
}

List<dynamic> _canonicalizeRing(List<dynamic> points) {
  final normalized = [...points];
  if (normalized.length > 1 && _samePoint(normalized.first, normalized.last)) {
    normalized.removeLast();
  }
  if (normalized.length < 2) return normalized;

  var start = 0;
  for (var index = 1; index < normalized.length; index++) {
    if (_comparePointLists(normalized[index], normalized[start]) < 0) {
      start = index;
    }
  }
  return [
    for (var offset = 0; offset < normalized.length; offset++)
      normalized[(start + offset) % normalized.length],
  ];
}

List<dynamic> _canonicalizeSegments(List<dynamic> segments) {
  final normalized = [
    for (final segment in segments)
      if (!_isDegenerateLineSegment(segment)) segment,
  ];
  if (normalized.length < 2) return normalized;

  var start = 0;
  for (var index = 1; index < normalized.length; index++) {
    if (_compareSegmentLists(normalized[index], normalized[start]) < 0) {
      start = index;
    }
  }
  return [
    for (var offset = 0; offset < normalized.length; offset++)
      normalized[(start + offset) % normalized.length],
  ];
}

bool _samePoint(dynamic left, dynamic right) {
  return left is Map &&
      right is Map &&
      _compareNumbers(left['x'], right['x']) == 0 &&
      _compareNumbers(left['y'], right['y']) == 0;
}

bool _isDegenerateLineSegment(dynamic segment) {
  return segment is Map &&
      segment['type'] == 'line' &&
      _compareNumbers(segment['x1'], segment['x2']) == 0 &&
      _compareNumbers(segment['y1'], segment['y2']) == 0;
}

int _comparePointLists(dynamic left, dynamic right) {
  final x = _compareNumbers(left['x'], right['x']);
  if (x != 0) return x;
  return _compareNumbers(left['y'], right['y']);
}

int _compareSegmentLists(dynamic left, dynamic right) {
  final x1 = _compareNumbers(left['x1'], right['x1']);
  if (x1 != 0) return x1;
  final y1 = _compareNumbers(left['y1'], right['y1']);
  if (y1 != 0) return y1;
  final x2 = _compareNumbers(left['x2'], right['x2']);
  if (x2 != 0) return x2;
  return _compareNumbers(left['y2'], right['y2']);
}

int _compareNumbers(dynamic left, dynamic right) {
  final leftNumber = (left as num).toDouble();
  final rightNumber = (right as num).toDouble();
  return leftNumber.compareTo(rightNumber);
}
