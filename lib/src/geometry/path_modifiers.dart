/// Implementasi Path Modifiers untuk RelGeo: Fillet, Chamfer, dan Polyline Offset.
///
/// Sesuai spec RelGeo v0.3 §11 (Fillet & Chamfer) dan §12 (Path Offset).
/// Digunakan oleh resolver saat memproses field `corners`, `corner.all`, dan `offset` pada `path`/`polygon`.
library;

import 'dart:math' as math;
import 'types.dart';

// ────────────────────────────────────────────────────
// Fillet (Busur Tangent pada Sudut)
// ────────────────────────────────────────────────────

/// Menghitung ArcSegment fillet pada titik sudut [corner] yang dibentuk oleh
/// vektor dari [prev] ke [corner] dan dari [corner] ke [next].
/// Mengembalikan [null] jika radius tidak valid atau tiga titik hampir kolinear.
/// Mengembalikan map berisi:
///   - `arcSeg`: ArcSegment yang membentuk busur fillet
///   - `start`: titik awal busur (titrim pada segmen incoming)
///   - `end`: titik akhir busur (titrim pada segmen outgoing)
Map<String, dynamic>? computeFillet(
  Point2D prev,
  Point2D corner,
  Point2D next,
  double radius,
) {
  if (radius <= 0) return null;

  // Vektor dari corner ke prev dan next
  final dx1 = prev.x - corner.x;
  final dy1 = prev.y - corner.y;
  final dx2 = next.x - corner.x;
  final dy2 = next.y - corner.y;

  final len1 = math.sqrt(dx1 * dx1 + dy1 * dy1);
  final len2 = math.sqrt(dx2 * dx2 + dy2 * dy2);
  if (len1 < 1e-9 || len2 < 1e-9) return null;

  // Unit vectors
  final ux1 = dx1 / len1;
  final uy1 = dy1 / len1;
  final ux2 = dx2 / len2;
  final uy2 = dy2 / len2;

  // Half-angle antara dua segmen
  final dot = ux1 * ux2 + uy1 * uy2;
  final cosHalf = math.sqrt((1 + dot) / 2);
  if (cosHalf < 1e-9) return null; // hampir 180°, tidak ada sudut

  final tanHalf = math.sqrt(1 - cosHalf * cosHalf) / cosHalf;
  if (tanHalf < 1e-9) return null;

  // Jarak dari corner ke titik sentuh busur
  final dist = radius / tanHalf;
  if (dist > len1 || dist > len2) return null; // radius terlalu besar

  // Titik tangent (start dan end busur)
  final startX = corner.x + ux1 * dist;
  final startY = corner.y + uy1 * dist;
  final endX = corner.x + ux2 * dist;
  final endY = corner.y + uy2 * dist;

  // Titik tengah antara dua unit vector (untuk mencari pusat busur)
  final bisX = ux1 + ux2;
  final bisY = uy1 + uy2;
  final bisLen = math.sqrt(bisX * bisX + bisY * bisY);
  if (bisLen < 1e-9) return null;

  final centerDist = radius / math.sin(math.acos(dot.clamp(-1.0, 1.0)) / 2);
  final cx = corner.x + (bisX / bisLen) * centerDist;
  final cy = corner.y + (bisY / bisLen) * centerDist;

  // Tentukan arah sweep (CCW atau CW) menggunakan cross product
  // cross > 0 → CCW (sweep=0 di SVG/Dart convention yDown), < 0 → CW (sweep=1)
  final cross = dx1 * dy2 - dy1 * dx2;
  final sweep = cross > 0 ? 0 : 1;
  
  // largeArc selalu 0 untuk fillet normal
  final arcSeg = ArcSegment(
    x1: startX,
    y1: startY,
    x2: endX,
    y2: endY,
    cx: cx,
    cy: cy,
    radius: radius,
    sweep: sweep,
    largeArc: 0,
  );

  return {
    'arcSeg': arcSeg,
    'start': (x: startX, y: startY),
    'end': (x: endX, y: endY),
  };
}

// ────────────────────────────────────────────────────
// Chamfer (Potongan Diagonal pada Sudut)
// ────────────────────────────────────────────────────

/// Menghitung segmen garis chamfer pada titik sudut [corner].
/// Mengembalikan map:
///   - `lineSeg`: LineSegment diagonal
///   - `start`: titik chamfer pada segmen incoming
///   - `end`: titik chamfer pada segmen outgoing
Map<String, dynamic>? computeChamfer(
  Point2D prev,
  Point2D corner,
  Point2D next,
  double distance,
) {
  if (distance <= 0) return null;

  final dx1 = prev.x - corner.x;
  final dy1 = prev.y - corner.y;
  final dx2 = next.x - corner.x;
  final dy2 = next.y - corner.y;

  final len1 = math.sqrt(dx1 * dx1 + dy1 * dy1);
  final len2 = math.sqrt(dx2 * dx2 + dy2 * dy2);
  if (len1 < 1e-9 || len2 < 1e-9) return null;
  if (distance > len1 || distance > len2) return null; // jarak terlalu besar

  final startX = corner.x + (dx1 / len1) * distance;
  final startY = corner.y + (dy1 / len1) * distance;
  final endX = corner.x + (dx2 / len2) * distance;
  final endY = corner.y + (dy2 / len2) * distance;

  final lineSeg = LineSegment(startX, startY, endX, endY);

  return {
    'lineSeg': lineSeg,
    'start': (x: startX, y: startY),
    'end': (x: endX, y: endY),
  };
}

// ────────────────────────────────────────────────────
// Apply Corner Modifiers (gabung fillet/chamfer ke segments)
// ────────────────────────────────────────────────────

/// Mengaplikasikan fillet/chamfer ke tiap corner pada list segmen.
/// [segments]: list segmen path (harus semua LineSegment untuk corner modifier).
/// [corners]: map dari label corner ke { fillet?: radius, chamfer?: dist }.
///   Jika key adalah 'all', berlaku ke semua corner.
/// [closed]: apakah path tertutup.
List<PathResolvedSegment> applyCornerModifiers(
  List<PathResolvedSegment> segments,
  Map<String, dynamic> cornersMap,
  bool closed,
) {
  if (segments.isEmpty) return segments;

  // Ekstrak titik-titik corner dan segment mapping
  // Corner i berada di antara segments[i-1].end dan segments[i].start
  final points = <Point2D>[];
  for (int i = 0; i < segments.length; i++) {
    final seg = segments[i];
    if (seg is LineSegment) {
      if (i == 0) points.add((x: seg.x1, y: seg.y1));
      points.add((x: seg.x2, y: seg.y2));
    } else {
      // Segmen non-line: tidak dimodifikasi, kembalikan apa adanya
      return segments;
    }
  }

  // Untuk path tertutup, titik terakhir === titik pertama (redundant)
  if (closed && points.length > 1) {
    points.removeLast(); // hapus duplikat
  }

  final n = points.length;
  if (n < 3) return segments;

  // Helper: ambil corner modifier untuk indeks i
  Map<String, dynamic>? getCornerSpec(int i) {
    // Penamaan corner: A, B, C, ... (berdasarkan index 0=A, 1=B, dst.)
    // Tapi juga mendukung 'all'
    if (cornersMap.containsKey('all')) {
      return cornersMap['all'] as Map<String, dynamic>?;
    }
    // Label berdasarkan letter: A=0, B=1, ...
    final label = String.fromCharCode('A'.codeUnitAt(0) + i);
    if (cornersMap.containsKey(label)) {
      return cornersMap[label] as Map<String, dynamic>?;
    }
    return null;
  }

  // Bangun ulang segmen dengan corner modifier
  final result = <PathResolvedSegment>[];

  for (int i = 0; i < n; i++) {
    final prev = points[(i - 1 + n) % n];
    final corner = points[i];
    final next = points[(i + 1) % n];

    // Corner pertama dan terakhir pada path terbuka tidak ada modifier
    if (!closed && (i == 0 || i == n - 1)) {
      // Tambahkan segmen langsung ke next
      if (i < n - 1) {
        result.add(LineSegment(corner.x, corner.y, next.x, next.y));
      }
      continue;
    }

    final spec = getCornerSpec(i);

    if (spec == null) {
      // Tidak ada modifier — tambahkan segmen langsung ke next
      if (closed || i < n - 1) {
        final nextPt = points[(i + 1) % n];
        if (result.isNotEmpty) {
          // Update end point of last segment
          final last = result.last;
          if (last is LineSegment) {
            result[result.length - 1] = LineSegment(last.x1, last.y1, corner.x, corner.y);
          }
        }
        result.add(LineSegment(corner.x, corner.y, nextPt.x, nextPt.y));
      }
      continue;
    }

    final filletRadius = (spec['fillet'] as num?)?.toDouble();
    final chamferDist = (spec['chamfer'] as num?)?.toDouble();

    if (filletRadius != null && filletRadius > 0) {
      final f = computeFillet(prev, corner, next, filletRadius);
      if (f != null) {
        final startPt = f['start'] as Point2D;
        final endPt = f['end'] as Point2D;
        final arcSeg = f['arcSeg'] as ArcSegment;

        // Ganti titik akhir segmen sebelumnya ke startPt
        if (result.isNotEmpty && result.last is LineSegment) {
          final last = result.last as LineSegment;
          result[result.length - 1] = LineSegment(last.x1, last.y1, startPt.x, startPt.y);
        } else {
          result.add(LineSegment(prev.x, prev.y, startPt.x, startPt.y));
        }
        result.add(arcSeg);
        // Segmen selanjutnya dimulai dari endPt
        if (closed || i < n - 1) {
          final nextPt = points[(i + 1) % n];
          result.add(LineSegment(endPt.x, endPt.y, nextPt.x, nextPt.y));
        }
        continue;
      }
    }

    if (chamferDist != null && chamferDist > 0) {
      final c = computeChamfer(prev, corner, next, chamferDist);
      if (c != null) {
        final startPt = c['start'] as Point2D;
        final endPt = c['end'] as Point2D;
        final lineSeg = c['lineSeg'] as LineSegment;

        if (result.isNotEmpty && result.last is LineSegment) {
          final last = result.last as LineSegment;
          result[result.length - 1] = LineSegment(last.x1, last.y1, startPt.x, startPt.y);
        } else {
          result.add(LineSegment(prev.x, prev.y, startPt.x, startPt.y));
        }
        result.add(lineSeg);
        if (closed || i < n - 1) {
          final nextPt = points[(i + 1) % n];
          result.add(LineSegment(endPt.x, endPt.y, nextPt.x, nextPt.y));
        }
        continue;
      }
    }

    // Fallback: tidak ada modifier yang applicable
    if (closed || i < n - 1) {
      final nextPt = points[(i + 1) % n];
      result.add(LineSegment(corner.x, corner.y, nextPt.x, nextPt.y));
    }
  }

  return result;
}

// ────────────────────────────────────────────────────
// Polyline Offset
// ────────────────────────────────────────────────────

/// Mengoffset polyline sejajar berjarak [distance] ke [side].
/// [side]: 'left', 'right', 'inside', 'outside' (inside=right untuk CW, outside=left)
/// Mengembalikan list titik offset.
List<Point2D> offsetPolyline(
  List<Point2D> points,
  double distance,
  String side,
  bool closed,
) {
  if (points.length < 2) return points;

  // Normalisasi side ke left/right menggunakan winding detection untuk inside/outside
  double sign = 1.0;
  if (side == 'right') {
    sign = -1.0;
  } else if (side == 'inside' || side == 'outside') {
    // Hitung signed area untuk menentukan winding
    double area = 0.0;
    final n = points.length;
    for (int i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];
      area += (p1.x * p2.y - p2.x * p1.y);
    }
    // area > 0 → CCW, area < 0 → CW
    final isCW = area < 0;
    if (side == 'outside') {
      sign = isCW ? -1.0 : 1.0;
    } else {
      // inside
      sign = isCW ? 1.0 : -1.0;
    }
  }

  final n = points.length;
  final offsetPts = <Point2D>[];

  for (int i = 0; i < n; i++) {
    if (!closed && (i == 0 || i == n - 1)) {
      // Titik ujung pada open path: gunakan normal segmen terdekat
      final seg = i == 0
          ? _segmentNormal(points[0], points[1])
          : _segmentNormal(points[n - 2], points[n - 1]);
      offsetPts.add((
        x: points[i].x + seg.x * distance * sign,
        y: points[i].y + seg.y * distance * sign,
      ));
    } else {
      final prev = points[(i - 1 + n) % n];
      final curr = points[i];
      final next = points[(i + 1) % n];

      final n1 = _segmentNormal(prev, curr);
      final n2 = _segmentNormal(curr, next);

      // Rata-rata normal (miter join sederhana)
      double mx = n1.x + n2.x;
      double my = n1.y + n2.y;
      final mLen = math.sqrt(mx * mx + my * my);
      if (mLen < 1e-9) {
        mx = n1.x;
        my = n1.y;
      } else {
        // Koreksi miter agar jarak ke edge tetap [distance]
        final dot = n1.x * mx / mLen + n1.y * my / mLen;
        final scale = dot > 1e-9 ? 1.0 / dot : 1.0;
        mx = (mx / mLen) * scale;
        my = (my / mLen) * scale;
      }

      offsetPts.add((
        x: curr.x + mx * distance * sign,
        y: curr.y + my * distance * sign,
      ));
    }
  }

  return offsetPts;
}

/// Normal kiri (perpendicular CCW) dari segmen [p1]→[p2], sudah dinormalisasi.
({double x, double y}) _segmentNormal(Point2D p1, Point2D p2) {
  final dx = p2.x - p1.x;
  final dy = p2.y - p1.y;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1e-9) return (x: 0.0, y: -1.0);
  return (x: -dy / len, y: dx / len);
}
