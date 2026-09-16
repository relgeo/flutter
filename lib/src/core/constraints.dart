/// Implementasi Constraint Processing untuk RelGeo.
///
/// Sesuai spec v0.1 §7 (`align`) dan v0.2 §5 (`equal`, `parallel`, `perpendicular`, `tangent`).
/// Constraints bersifat non-modifying: tidak mengubah geometri, hanya menghasilkan
/// daftar [ConstraintViolation] yang dapat ditampilkan di UI dan digunakan untuk validasi.

import 'dart:math' as math;
import '../geometry/types.dart';

const double _kTolerance =
    1e-4; // Toleransi floating point untuk perbandingan geometri

/// Memproses seluruh blok `constraints` dan mengembalikan daftar pelanggaran.
List<ConstraintViolation> processConstraints(
  List<dynamic> rawConstraints,
  Map<String, ResolvedObject> objects,
) {
  final violations = <ConstraintViolation>[];

  for (var index = 0; index < rawConstraints.length; index++) {
    final raw = rawConstraints[index];
    if (raw is! Map) continue;

    for (final entry in raw.entries) {
      final type = entry.key.toString();
      final spec = entry.value;

      try {
        switch (type) {
          case 'align':
            final v = _processAlign(spec, objects, path: 'constraints[$index]');
            if (v != null) violations.add(v);

          case 'equal':
            final v = _processEqual(spec, objects);
            if (v != null) violations.add(v);

          case 'parallel':
            final v = _processParallel(spec, objects);
            if (v != null) violations.add(v);

          case 'perpendicular':
            final v = _processPerpendicular(spec, objects);
            if (v != null) violations.add(v);

          case 'tangent':
            final v = _processTangent(spec, objects);
            if (v != null) violations.add(v);

          case 'coincident':
            final v = _processCoincident(spec, objects);
            if (v != null) violations.add(v);
        }
      } catch (e) {
        // Constraint evaluation error — catat sebagai violation
        violations.add(
          ConstraintViolation(
            type: type,
            message: 'Constraint evaluation error: $e',
            deviation: double.infinity,
            path: 'constraints.$type',
            involvedObjects: [],
          ),
        );
      }
    }
  }

  return violations;
}

// ─────────────────────────────────────────────────────────────────────────────
// align: memvalidasi bahwa dua anchor/edge memiliki koordinat yang sama
// ─────────────────────────────────────────────────────────────────────────────
ConstraintViolation? _processAlign(
  dynamic spec,
  Map<String, ResolvedObject> objects, {
  required String path,
}) {
  if (spec is! Map) return null;

  final targetSpec = spec['target'];
  final withSpec = spec['with'];
  final axis = spec['axis']?.toString() ?? 'both'; // x, y, both

  if (targetSpec == null || withSpec == null) return null;

  final targetPt = _resolveAnchorPoint(targetSpec, objects);
  final withPt = _resolveAnchorPoint(withSpec, objects);

  if (targetPt == null || withPt == null) return null;

  final dx = (targetPt.x - withPt.x).abs();
  final dy = (targetPt.y - withPt.y).abs();

  // The default point alignment contract follows the TypeScript resolver:
  // compare Euclidean distance and expose an indexed constraint path.
  if (axis == 'both') {
    final deviation = math.sqrt(dx * dx + dy * dy);
    if (deviation <= 1e-3) return null;

    return ConstraintViolation(
      type: 'align',
      message:
          'Points are not aligned. Distance: ${deviation.toStringAsFixed(4)}',
      deviation: deviation,
      path: path,
      involvedObjects: const [],
      visualHelper: (
        x1: targetPt.x,
        y1: targetPt.y,
        x2: withPt.x,
        y2: withPt.y,
      ),
    );
  }

  double deviation = 0.0;
  String message = '';

  if (axis == 'x') {
    if (dx > _kTolerance) {
      deviation = math.max(deviation, dx);
      message += 'X misalignment: ${dx.toStringAsFixed(3)}. ';
    }
  }
  if (axis == 'y') {
    if (dy > _kTolerance) {
      deviation = math.max(deviation, dy);
      message += 'Y misalignment: ${dy.toStringAsFixed(3)}. ';
    }
  }

  if (deviation < _kTolerance) return null;

  return ConstraintViolation(
    type: 'align',
    message: message.trim(),
    deviation: deviation,
    path: path,
    involvedObjects: _extractObjectIds([targetSpec, withSpec]),
    visualHelper: targetPt != null && withPt != null
        ? (x1: targetPt.x, y1: targetPt.y, x2: withPt.x, y2: withPt.y)
        : null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// equal: memvalidasi kesamaan nilai antara dua ekspresi geometri
// ─────────────────────────────────────────────────────────────────────────────
ConstraintViolation? _processEqual(
  dynamic spec,
  Map<String, ResolvedObject> objects,
) {
  if (spec is! List || spec.length < 2) return null;

  final val1 = _resolveScalar(spec[0], objects);
  final val2 = _resolveScalar(spec[1], objects);

  if (val1 == null || val2 == null) return null;

  final deviation = (val1 - val2).abs();
  if (deviation < _kTolerance) return null;

  return ConstraintViolation(
    type: 'equal',
    message:
        'Values not equal: $val1 ≠ $val2 (deviation: ${deviation.toStringAsFixed(3)})',
    deviation: deviation,
    path: 'constraints.equal',
    involvedObjects: _extractObjectIds(spec),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// parallel: memvalidasi bahwa dua garis sejajar
// ─────────────────────────────────────────────────────────────────────────────
ConstraintViolation? _processParallel(
  dynamic spec,
  Map<String, ResolvedObject> objects,
) {
  if (spec is! List || spec.length < 2) return null;

  final dir1 = _getLineDirection(spec[0].toString(), objects);
  final dir2 = _getLineDirection(spec[1].toString(), objects);

  if (dir1 == null || dir2 == null) return null;

  // Cross product = sin(angle) antara dua unit vector
  // Paralel jika cross ≈ 0
  final cross = dir1.x * dir2.y - dir1.y * dir2.x;
  final deviation = cross.abs();

  if (deviation < _kTolerance) return null;

  final angleDeg = math.asin(deviation.clamp(0.0, 1.0)) * 180.0 / math.pi;

  return ConstraintViolation(
    type: 'parallel',
    message: 'Lines not parallel: angle = ${angleDeg.toStringAsFixed(2)}°',
    deviation: angleDeg,
    path: 'constraints.parallel',
    involvedObjects: spec.map((e) => e.toString()).toList(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// perpendicular: memvalidasi bahwa dua garis tegak lurus (dot product ≈ 0)
// ─────────────────────────────────────────────────────────────────────────────
ConstraintViolation? _processPerpendicular(
  dynamic spec,
  Map<String, ResolvedObject> objects,
) {
  if (spec is! List || spec.length < 2) return null;

  final dir1 = _getLineDirection(spec[0].toString(), objects);
  final dir2 = _getLineDirection(spec[1].toString(), objects);

  if (dir1 == null || dir2 == null) return null;

  // Dot product = cos(angle) — perpendicular jika dot ≈ 0
  final dot = dir1.x * dir2.x + dir1.y * dir2.y;
  final deviation = dot.abs();

  if (deviation < _kTolerance) return null;

  final angleDeg = math.acos(deviation.clamp(0.0, 1.0)) * 180.0 / math.pi;
  final angleTo90 = (90.0 - angleDeg).abs();

  return ConstraintViolation(
    type: 'perpendicular',
    message:
        'Lines not perpendicular: deviation from 90° = ${angleTo90.toStringAsFixed(2)}°',
    deviation: angleTo90,
    path: 'constraints.perpendicular',
    involvedObjects: spec.map((e) => e.toString()).toList(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// tangent: memvalidasi bahwa garis bersinggungan dengan circle
// ─────────────────────────────────────────────────────────────────────────────
ConstraintViolation? _processTangent(
  dynamic spec,
  Map<String, ResolvedObject> objects,
) {
  if (spec is! List || spec.length < 2) return null;

  final lineId = spec[0].toString();
  final circleId = spec[1].toString();

  final lineObj = objects[lineId];
  final circleObj = objects[circleId];

  if (lineObj is! ResolvedLine || circleObj is! ResolvedCircle) return null;

  // Jarak dari pusat circle ke garis
  // Garis: ax + by + c = 0
  final dx = lineObj.x2 - lineObj.x1;
  final dy = lineObj.y2 - lineObj.y1;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1e-9) return null;

  final a = dy / len; // normal x
  final b = -dx / len; // normal y
  final c = -(a * lineObj.x1 + b * lineObj.y1);

  final distToCenter = (a * circleObj.cx + b * circleObj.cy + c).abs();
  final deviation = (distToCenter - circleObj.radius).abs();

  if (deviation < _kTolerance) return null;

  return ConstraintViolation(
    type: 'tangent',
    message:
        'Not tangent: distance to center = ${distToCenter.toStringAsFixed(3)}, radius = ${circleObj.radius.toStringAsFixed(3)}, deviation = ${deviation.toStringAsFixed(3)}',
    deviation: deviation,
    path: 'constraints.tangent',
    involvedObjects: [lineId, circleId],
    visualHelper: (
      x1: circleObj.cx,
      y1: circleObj.cy,
      x2: lineObj.x1 + (lineObj.x2 - lineObj.x1) / 2,
      y2: lineObj.y1 + (lineObj.y2 - lineObj.y1) / 2,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// coincident: memvalidasi bahwa dua titik sama posisinya
// ─────────────────────────────────────────────────────────────────────────────
ConstraintViolation? _processCoincident(
  dynamic spec,
  Map<String, ResolvedObject> objects,
) {
  if (spec is! List || spec.length < 2) return null;

  final pt1 = _resolveAnchorPoint(spec[0], objects);
  final pt2 = _resolveAnchorPoint(spec[1], objects);
  if (pt1 == null || pt2 == null) return null;

  final dx = pt1.x - pt2.x;
  final dy = pt1.y - pt2.y;
  final deviation = math.sqrt(dx * dx + dy * dy);

  if (deviation < _kTolerance) return null;

  return ConstraintViolation(
    type: 'coincident',
    message:
        'Points not coincident: distance = ${deviation.toStringAsFixed(3)}',
    deviation: deviation,
    path: 'constraints.coincident',
    involvedObjects: _extractObjectIds(spec),
    visualHelper: (x1: pt1.x, y1: pt1.y, x2: pt2.x, y2: pt2.y),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Menyelesaikan anchor spec menjadi Point2D.
/// Spec bisa berupa String (object ID) atau Map (object.anchor).
Point2D? _resolveAnchorPoint(
  dynamic spec,
  Map<String, ResolvedObject> objects,
) {
  if (spec is String) {
    // Langsung referensi object atau anchor (format: 'objectId.anchor')
    final parts = spec.split('.');
    final obj = objects[parts[0]];
    if (obj == null) return null;

    if (parts.length == 1) {
      return _getCenterPoint(obj);
    } else {
      return _getAnchorPoint(obj, parts[1]);
    }
  }

  if (spec is Map) {
    final objId = spec['object']?.toString() ?? spec['id']?.toString();
    final anchor = spec['anchor']?.toString() ?? 'center';
    if (objId == null) return null;
    final obj = objects[objId];
    if (obj == null) return null;
    return _getAnchorPoint(obj, anchor);
  }

  if (spec is List && spec.length >= 2) {
    final x = (spec[0] as num).toDouble();
    final y = (spec[1] as num).toDouble();
    return (x: x, y: y);
  }

  return null;
}

/// Mendapatkan titik pusat dari suatu resolved object.
Point2D? _getCenterPoint(ResolvedObject obj) {
  return switch (obj) {
    ResolvedPoint(:final x, :final y) => (x: x, y: y),
    ResolvedCircle(:final cx, :final cy) => (x: cx, y: cy),
    ResolvedRect(:final x, :final y, :final width, :final height) => (
      x: x + width / 2,
      y: y + height / 2,
    ),
    ResolvedLine(:final x1, :final y1, :final x2, :final y2) => (
      x: (x1 + x2) / 2,
      y: (y1 + y2) / 2,
    ),
    _ => null,
  };
}

/// Mendapatkan anchor point dari suatu resolved object berdasarkan nama anchor.
Point2D? _getAnchorPoint(ResolvedObject obj, String anchor) {
  // Cek custom anchors dulu
  if (obj.anchors.containsKey(anchor)) return obj.anchors[anchor];

  // Anchor standar berdasarkan tipe
  return switch (obj) {
    ResolvedRect(:final x, :final y, :final width, :final height) =>
      switch (anchor) {
        'center' => (x: x + width / 2, y: y + height / 2),
        'topLeft' => (x: x, y: y),
        'topRight' => (x: x + width, y: y),
        'bottomLeft' => (x: x, y: y + height),
        'bottomRight' => (x: x + width, y: y + height),
        'topCenter' => (x: x + width / 2, y: y),
        'bottomCenter' => (x: x + width / 2, y: y + height),
        'centerLeft' => (x: x, y: y + height / 2),
        'centerRight' => (x: x + width, y: y + height / 2),
        'left' ||
        'right' ||
        'top' ||
        'bottom' ||
        'centerX' ||
        'centerY' => _getCenterPoint(obj),
        _ => null,
      },
    ResolvedCircle(:final cx, :final cy) => switch (anchor) {
      'center' => (x: cx, y: cy),
      _ => null,
    },
    ResolvedLine(:final x1, :final y1, :final x2, :final y2) =>
      switch (anchor) {
        'start' => (x: x1, y: y1),
        'end' => (x: x2, y: y2),
        'center' => (x: (x1 + x2) / 2, y: (y1 + y2) / 2),
        _ => null,
      },
    ResolvedPoint(:final x, :final y) => (x: x, y: y),
    _ => null,
  };
}

/// Menyelesaikan nilai scalar dari referensi object/property.
double? _resolveScalar(dynamic spec, Map<String, ResolvedObject> objects) {
  if (spec is num) return spec.toDouble();

  if (spec is String) {
    final parts = spec.split('.');
    if (parts.length < 2) return null;
    final obj = objects[parts[0]];
    if (obj == null) return null;

    return switch (parts[1]) {
      'width' when obj is ResolvedRect => obj.width,
      'height' when obj is ResolvedRect => obj.height,
      'radius' when obj is ResolvedCircle => obj.radius,
      'x' when obj is ResolvedPoint => obj.x,
      'y' when obj is ResolvedPoint => obj.y,
      'length' when obj is ResolvedLine => () {
        final dx = obj.x2 - obj.x1;
        final dy = obj.y2 - obj.y1;
        return math.sqrt(dx * dx + dy * dy);
      }(),
      _ => null,
    };
  }

  return null;
}

/// Mendapatkan unit direction vector dari sebuah garis.
({double x, double y})? _getLineDirection(
  String id,
  Map<String, ResolvedObject> objects,
) {
  final obj = objects[id];
  if (obj is! ResolvedLine) return null;

  final dx = obj.x2 - obj.x1;
  final dy = obj.y2 - obj.y1;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1e-9) return null;

  return (x: dx / len, y: dy / len);
}

/// Mengekstrak daftar object ID dari spec list.
List<String> _extractObjectIds(dynamic spec) {
  if (spec is List) {
    return spec.map((e) {
      final s = e.toString();
      return s.split('.').first; // ambil object ID saja, bukan anchor
    }).toList();
  }
  if (spec is String) return [spec.split('.').first];
  return [];
}
