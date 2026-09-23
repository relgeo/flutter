import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../geometry/types.dart';
import '../geometry/utils.dart' as geom;
import 'render_hierarchy.dart';
import 'render_presentational.dart';
import 'render_style.dart';
import 'render_typography.dart';
import 'workbench_visual_profile.dart';

const _activeRelGeoVersion = 'v0.5';

/// CanvasPainter untuk merender ResolvedScene dari RelGeo secara visual pada Canvas Flutter.
///
/// Mengimplementasikan rendering berkinerja tinggi (>60 FPS) dengan gaya grafis CAD premium
/// neon-terang di atas latar belakang Slate-900 gelap, lengkap dengan penanganan garis putus-putus,
/// anotasi dimensi dengan rotasi teks sejajar garis, dan anotasi petunjuk (leader lines).
/// Konfigurasi overlay diagnostik yang ditampilkan di atas scene.
class OverlayOptions {
  final bool showAnchors;
  final bool showLabels;
  final bool showBoundingBoxes;

  const OverlayOptions({
    this.showAnchors = false,
    this.showLabels = false,
    this.showBoundingBoxes = false,
  });

  @override
  bool operator ==(Object other) =>
      other is OverlayOptions &&
      other.showAnchors == showAnchors &&
      other.showLabels == showLabels &&
      other.showBoundingBoxes == showBoundingBoxes;

  @override
  int get hashCode => Object.hash(showAnchors, showLabels, showBoundingBoxes);
}

class CanvasPainter extends CustomPainter {
  final ResolvedScene scene;
  final Color backgroundColor;
  final OverlayOptions overlay;
  final double zoomScale;
  final bool showConstruction;
  final String? sheetId;
  final Set<String> hiddenRoles;
  final WorkbenchVisualProfile visualProfile;
  double _activeSheetPresentationalScale = 1.0;

  CanvasPainter({
    required this.scene,
    this.backgroundColor = const Color(0xFF0F172A), // Slate 900
    this.overlay = const OverlayOptions(),
    this.zoomScale = 1.0,
    this.showConstruction = false,
    this.sheetId,
    Set<String>? hiddenRoles,
    WorkbenchVisualProfile? visualProfile,
  }) : hiddenRoles = hiddenRoles ?? const {'construction'},
       visualProfile = visualProfile ?? WorkbenchVisualProfile.cadDark;

  bool _shouldRenderRole(String role) {
    if (role == 'construction' && showConstruction) return true;
    if (hiddenRoles.contains(role)) return false;
    return true;
  }

  BoundingBox get _displayBounds {
    final sheet = sheetId != null ? scene.sheets[sheetId] : null;
    if (sheet != null) {
      return BoundingBox(x: 0, y: 0, width: sheet.width, height: sheet.height);
    }
    return scene.bbox;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final activeSheet = sheetId != null ? scene.sheets[sheetId] : null;
    if (activeSheet != null) {
      _paintSheet(canvas, size, activeSheet);
      return;
    }

    final bounds = _displayBounds;
    canvas.save();
    canvas.translate(-bounds.x, -bounds.y);
    _paintObjectMap(canvas, scene.objects, scene.objects);
    canvas.restore();

    // ─── Constraint Violations overlay ───────

    if (scene.violations.isNotEmpty) {
      _paintViolations(canvas);
    }

    // ─── Overlay layer (anchor, labels, bounding boxes) ───────
    if (overlay.showAnchors ||
        overlay.showLabels ||
        overlay.showBoundingBoxes) {
      _paintOverlay(canvas, size);
    }
  }

  void _paintSheet(Canvas canvas, Size size, ResolvedSheet sheet) {
    final pagePaint = Paint()..color = const Color(0xFFF3F4F6);
    final borderPaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 0.8 / zoomScale
      ..style = PaintingStyle.stroke;
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
    final marginSize = scene.padding * mm;

    canvas.save();
    canvas.drawRect(
      Rect.fromLTWH(-10, -10, sheet.width + 20, sheet.height + 20),
      pagePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        marginSize,
        marginSize,
        sheet.width - 2 * marginSize,
        sheet.height - 2 * marginSize,
      ),
      borderPaint,
    );

    for (final placement in sheet.views) {
      final view = scene.views[placement.use];
      if (view == null) continue;
      final previousPresentationalScale = _activeSheetPresentationalScale;
      _activeSheetPresentationalScale =
          view.scaleFactor.isFinite && view.scaleFactor > 0
          ? view.scaleFactor
          : 1.0;

      final viewOriginX = view.scaleFactor != 0
          ? view.bbox.x / view.scaleFactor
          : view.bbox.x;
      final viewOriginY = view.scaleFactor != 0
          ? view.bbox.y / view.scaleFactor
          : view.bbox.y;

      canvas.save();
      canvas.translate(placement.x, placement.y);
      canvas.scale(view.scaleFactor);
      canvas.translate(-viewOriginX, -viewOriginY);
      RenderHierarchy.renderRootedObjects(
        objects: view.objects,
        objectLookup: view.objects,
        shouldRenderRole: _shouldRenderRole,
        renderPrimitive: (obj, meta) =>
            _paintPrimitiveObject(canvas, obj, meta),
        withTransformScope: (transforms, renderChild) {
          canvas.save();
          for (final op in transforms) {
            applyTransformOp(canvas, op);
          }
          renderChild();
          canvas.restore();
        },
      );
      canvas.restore();
      _activeSheetPresentationalScale = previousPresentationalScale;

      final viewportFramePaint = Paint()
        ..color = const Color(0xFF666666)
        ..strokeWidth = 0.5 * mm / zoomScale
        ..style = PaintingStyle.stroke;
      final viewportFramePath = Path()
        ..addRect(
          Rect.fromLTWH(
            placement.x,
            placement.y,
            placement.width,
            placement.height,
          ),
        );
      drawDashedPath(canvas, viewportFramePath, viewportFramePaint, [
        2 * mm / zoomScale,
        2 * mm / zoomScale,
      ]);
      _paintSheetLabel(
        canvas,
        '${placement.use} (Scale ${view.scale})',
        placement.x,
        placement.y + placement.height + 8 * mm,
        const Color(0xFF666666),
        6 * mm / zoomScale,
      );
    }

    _paintTitleBlock(canvas, sheet, marginSize, mm);
    canvas.restore();
  }

  void _paintObjectMap(
    Canvas canvas,
    Map<String, ResolvedObject> objects,
    Map<String, ResolvedObject> objectLookup,
  ) {
    for (final obj in objects.values) {
      if (!obj.meta.visible) continue;
      if (!_shouldRenderRole(obj.meta.role)) continue;
      _paintResolvedObject(canvas, obj, objectLookup);
    }
  }

  void _paintPrimitiveObject(Canvas canvas, ResolvedObject obj, Meta meta) {
    canvas.save();
    if (obj.transforms.isNotEmpty) {
      for (final op in obj.transforms) {
        applyTransformOp(canvas, op);
      }
    }

    final strokePaint = getPaintForMeta(meta, isFill: false);
    final fillPaint = getPaintForMeta(meta, isFill: true);
    final dashPattern = getDashPatternForMeta(meta);

    switch (obj) {
      case ResolvedPoint():
        drawPoint(canvas, obj, strokePaint);
      case ResolvedLine():
        drawLine(canvas, obj, strokePaint, dashPattern);
      case ResolvedRect():
        drawRect(canvas, obj, strokePaint, fillPaint, dashPattern);
      case ResolvedCircle():
        drawCircle(canvas, obj, strokePaint, fillPaint, dashPattern);
      case ResolvedEllipse():
        drawEllipse(canvas, obj, strokePaint, fillPaint, dashPattern);
      case ResolvedArc():
        drawArc(canvas, obj, strokePaint, dashPattern);
      case ResolvedQuadratic():
        drawQuadratic(canvas, obj, strokePaint, dashPattern);
      case ResolvedCubic():
        drawCubic(canvas, obj, strokePaint, dashPattern);
      case ResolvedPath():
        drawSegments(
          canvas,
          obj.segments,
          obj.holes,
          obj.closed,
          strokePaint,
          fillPaint,
          dashPattern,
        );
      case ResolvedPolygon():
        drawSegments(
          canvas,
          obj.segments,
          obj.holes,
          true,
          strokePaint,
          fillPaint,
          dashPattern,
        );
      case ResolvedBoolean():
        drawSegments(
          canvas,
          obj.segments,
          obj.holes,
          true,
          strokePaint,
          fillPaint,
          dashPattern,
        );
      case ResolvedText():
        drawText(canvas, obj, strokePaint.color);
      case ResolvedDimension():
        drawDimension(canvas, obj, strokePaint.color);
      case ResolvedAnnotation():
        drawAnnotation(canvas, obj, strokePaint.color);
      default:
        break;
    }

    canvas.restore();
  }

  void _paintResolvedObject(
    Canvas canvas,
    ResolvedObject obj,
    Map<String, ResolvedObject> objectLookup,
  ) {
    canvas.save();
    if (obj.transforms.isNotEmpty) {
      for (final op in obj.transforms) {
        applyTransformOp(canvas, op);
      }
    }

    final strokePaint = getPaintForMeta(obj.meta, isFill: false);
    final fillPaint = getPaintForMeta(obj.meta, isFill: true);
    final dashPattern = getDashPatternForMeta(obj.meta);

    switch (obj) {
      case ResolvedPoint():
        drawPoint(canvas, obj, strokePaint);
      case ResolvedLine():
        drawLine(canvas, obj, strokePaint, dashPattern);
      case ResolvedRect():
        drawRect(canvas, obj, strokePaint, fillPaint, dashPattern);
      case ResolvedCircle():
        drawCircle(canvas, obj, strokePaint, fillPaint, dashPattern);
      case ResolvedEllipse():
        drawEllipse(canvas, obj, strokePaint, fillPaint, dashPattern);
      case ResolvedArc():
        drawArc(canvas, obj, strokePaint, dashPattern);
      case ResolvedQuadratic():
        drawQuadratic(canvas, obj, strokePaint, dashPattern);
      case ResolvedCubic():
        drawCubic(canvas, obj, strokePaint, dashPattern);
      case ResolvedPath():
        drawSegments(
          canvas,
          obj.segments,
          obj.holes,
          obj.closed,
          strokePaint,
          fillPaint,
          dashPattern,
        );
      case ResolvedPolygon():
        drawSegments(
          canvas,
          obj.segments,
          obj.holes,
          true,
          strokePaint,
          fillPaint,
          dashPattern,
        );
      case ResolvedBoolean():
        drawSegments(
          canvas,
          obj.segments,
          obj.holes,
          true,
          strokePaint,
          fillPaint,
          dashPattern,
        );
      case ResolvedText():
        drawText(canvas, obj, strokePaint.color);
      case ResolvedDimension():
        drawDimension(canvas, obj, strokePaint.color);
      case ResolvedAnnotation():
        drawAnnotation(canvas, obj, strokePaint.color);
      case ResolvedClone():
        final targetObj = objectLookup[obj.of];
        if (targetObj != null && targetObj.meta.visible) {
          final mergedMeta = Meta(
            visible: obj.meta.visible && targetObj.meta.visible,
            stroke: obj.meta.stroke ?? targetObj.meta.stroke,
            fill: obj.meta.fill ?? targetObj.meta.fill,
            strokeWidth: obj.meta.strokeWidth ?? targetObj.meta.strokeWidth,
            opacity:
                (obj.meta.opacity != null && targetObj.meta.opacity != null)
                ? obj.meta.opacity! * targetObj.meta.opacity!
                : (obj.meta.opacity ?? targetObj.meta.opacity),
            role: obj.meta.role != 'final'
                ? obj.meta.role
                : targetObj.meta.role,
            dash: obj.meta.dash ?? targetObj.meta.dash,
          );
          _drawObjectGeometry(
            canvas,
            targetObj,
            getPaintForMeta(mergedMeta, isFill: false),
            getPaintForMeta(mergedMeta, isFill: true),
            getDashPatternForMeta(mergedMeta),
          );
        }
      default:
        break;
    }

    canvas.restore();
  }

  void _paintSheetLabel(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color,
    double fontSize,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: fontSize,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y - tp.height));
  }

  void _paintTitleBlock(
    Canvas canvas,
    ResolvedSheet sheet,
    double marginSize,
    double mm,
  ) {
    final titleMeta = <String, dynamic>{
      ...?scene.meta?.extra,
      ...?sheet.meta?.extra,
    };
    final sheetNameText = (titleMeta['title'] ?? sheet.id).toString();
    final relgeoVersionText = _activeRelGeoVersion;
    final documentVersionText = (titleMeta['version'] ?? '-').toString();
    final dateText = (titleMeta['date'] ?? '-').toString();
    final sheetSizeText =
        (titleMeta['sheetSize'] ??
                (sheet.size is String ? sheet.size : 'Custom'))
            .toString();

    final tx = sheet.width - marginSize - 80 * mm;
    final ty = sheet.height - marginSize - 25 * mm;
    final framePaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 0.8 * mm / zoomScale
      ..style = PaintingStyle.stroke;
    final lightPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(tx, ty);
    canvas.drawRect(Rect.fromLTWH(0, 0, 80 * mm, 25 * mm), lightPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, 80 * mm, 25 * mm), framePaint);
    canvas.drawLine(Offset(0, 8 * mm), Offset(80 * mm, 8 * mm), framePaint);
    canvas.drawLine(
      Offset(45 * mm, 8 * mm),
      Offset(45 * mm, 25 * mm),
      framePaint,
    );
    _paintSheetLabel(
      canvas,
      'SHEET: $sheetNameText',
      4 * mm,
      6 * mm,
      const Color(0xFF333333),
      4.5 * mm / zoomScale,
    );
    _paintSheetLabel(
      canvas,
      'RELGEO: $relgeoVersionText',
      4 * mm,
      14 * mm,
      const Color(0xFF666666),
      3.5 * mm / zoomScale,
    );
    _paintSheetLabel(
      canvas,
      'DATE: $dateText',
      4 * mm,
      20 * mm,
      const Color(0xFF666666),
      3.5 * mm / zoomScale,
    );
    _paintSheetLabel(
      canvas,
      'SIZE: $sheetSizeText',
      49 * mm,
      14 * mm,
      const Color(0xFF666666),
      3.5 * mm / zoomScale,
    );
    _paintSheetLabel(
      canvas,
      'DOC VER: $documentVersionText',
      49 * mm,
      20 * mm,
      const Color(0xFF666666),
      3.5 * mm / zoomScale,
    );
    canvas.restore();
  }

  void _paintViolations(Canvas canvas) {
    canvas.save();
    canvas.translate(-scene.bbox.x, -scene.bbox.y);

    final violationLinePaint = Paint()
      ..color = const Color(0xFFFF4444)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final violationDotPaint = Paint()
      ..color = const Color(0xFFFF4444)
      ..style = PaintingStyle.fill;

    for (final violation in scene.violations) {
      final vh = violation.visualHelper;
      if (vh != null) {
        // Garis penghubung antara dua titik yang bermasalah
        final dashPath = Path()
          ..moveTo(vh.x1, vh.y1)
          ..lineTo(vh.x2, vh.y2);

        canvas.drawPath(dashPath, violationLinePaint);

        // Titik di kedua ujung
        canvas.drawCircle(Offset(vh.x1, vh.y1), 4, violationDotPaint);
        canvas.drawCircle(Offset(vh.x2, vh.y2), 4, violationDotPaint);

        // Label singkat di tengah
        final midX = (vh.x1 + vh.x2) / 2;
        final midY = (vh.y1 + vh.y2) / 2;
        final tp = TextPainter(
          text: TextSpan(
            text: '⚠ ${violation.type}',
            style: const TextStyle(
              color: Color(0xFFFF4444),
              fontSize: 9,
              fontFamily: 'monospace',
              backgroundColor: Color(0x99000000),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(midX - tp.width / 2, midY - 8));
      }
    }

    canvas.restore();
  }

  /// Merender hanya geometri dari sebuah object (tanpa transform),
  /// digunakan oleh clone untuk me-render target di konteks transform clone.
  void _drawObjectGeometry(
    Canvas canvas,
    ResolvedObject obj,
    Paint strokePaint,
    Paint fillPaint,
    List<double>? dashPattern,
  ) {
    switch (obj) {
      case ResolvedPoint():
        drawPoint(canvas, obj, strokePaint);
      case ResolvedLine():
        drawLine(canvas, obj, strokePaint, dashPattern ?? const []);
      case ResolvedRect():
        drawRect(canvas, obj, strokePaint, fillPaint, dashPattern ?? const []);
      case ResolvedCircle():
        drawCircle(
          canvas,
          obj,
          strokePaint,
          fillPaint,
          dashPattern ?? const [],
        );
      case ResolvedEllipse():
        drawEllipse(
          canvas,
          obj,
          strokePaint,
          fillPaint,
          dashPattern ?? const [],
        );
      case ResolvedArc():
        drawArc(canvas, obj, strokePaint, dashPattern ?? const []);
      case ResolvedQuadratic():
        drawQuadratic(canvas, obj, strokePaint, dashPattern ?? const []);
      case ResolvedCubic():
        drawCubic(canvas, obj, strokePaint, dashPattern ?? const []);
      case ResolvedPath():
        drawSegments(
          canvas,
          obj.segments,
          obj.holes,
          obj.closed,
          strokePaint,
          fillPaint,
          dashPattern ?? const [],
        );
      case ResolvedPolygon():
        drawSegments(
          canvas,
          obj.segments,
          obj.holes,
          true,
          strokePaint,
          fillPaint,
          dashPattern ?? const [],
        );
      case ResolvedBoolean():
        drawSegments(
          canvas,
          obj.segments,
          obj.holes,
          true,
          strokePaint,
          fillPaint,
          dashPattern ?? const [],
        );
      case ResolvedText():
        drawText(canvas, obj, strokePaint.color);
      default:
        break;
    }
  }

  void _paintOverlay(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(-scene.bbox.x, -scene.bbox.y);

    final Map<String, String> parentMap = {};
    for (final entry in scene.objects.entries) {
      final obj = entry.value;
      if (obj is BaseResolvedGroup) {
        for (final child in obj.children) {
          parentMap[child] = obj.id;
        }
      }
    }

    final anchorPaint = Paint()
      ..color = visualProfile.accentColor.withOpacity(0.5)
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    final bboxPaint = Paint()
      ..color = visualProfile.accentColor.withOpacity(0.45)
      ..strokeWidth = 0.6 / zoomScale
      ..style = PaintingStyle.stroke;

    for (final entry in scene.objects.entries) {
      final id = entry.key;
      final obj = entry.value;
      if (!obj.meta.visible) continue;
      // Lewati objek struktural
      if (obj is BaseResolvedGroup ||
          obj is ResolvedCollection ||
          obj is ResolvedClone) {
        continue;
      }

      // Terapkan transform parent untuk mendapat world-space position
      final worldOffset = _getWorldOffset(obj, parentMap);

      // Bounding box overlay (already in world space if parentMap is provided)
      if (overlay.showBoundingBoxes) {
        final bbox = _getBboxForObj(obj, parentMap);
        if (bbox != null) {
          canvas.save();
          canvas.drawRect(
            Rect.fromLTWH(bbox.x, bbox.y, bbox.width, bbox.height),
            bboxPaint,
          );
          canvas.restore();
        }
      }

      // Anchor crosshairs overlay
      if (overlay.showAnchors) {
        final anchors = _getAnchorPoints(obj);
        for (final ap in anchors) {
          final wx = ap.x + worldOffset.x;
          final wy = ap.y + worldOffset.y;
          final r = 3.5 / zoomScale;
          canvas.drawLine(Offset(wx - r, wy), Offset(wx + r, wy), anchorPaint);
          canvas.drawLine(Offset(wx, wy - r), Offset(wx, wy + r), anchorPaint);
          canvas.drawCircle(
            Offset(wx, wy),
            1.0 / zoomScale,
            Paint()
              ..color = visualProfile.accentColor
              ..style = PaintingStyle.fill,
          );
        }
      }

      // Label overlay
      if (overlay.showLabels) {
        final center = _getCenterForObj(obj);
        if (center != null) {
          final wx = center.x + worldOffset.x;
          final wy = center.y + worldOffset.y;
          _paintLabel(canvas, id, wx, wy);
        }
      }
    }

    canvas.restore();
  }

  void _paintLabel(Canvas canvas, String id, double x, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: id,
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: 7 / zoomScale,
          fontWeight: FontWeight.bold,
          color: visualProfile.accentColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgPaint = Paint()
      ..color = visualProfile.overlayBackgroundColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final padding = EdgeInsets.symmetric(
      horizontal: 3 / zoomScale,
      vertical: 1.5 / zoomScale,
    );
    final rect = Rect.fromLTWH(
      x - tp.width / 2 - padding.left,
      y - tp.height - (8 / zoomScale) - padding.top,
      tp.width + padding.horizontal,
      tp.height + padding.vertical,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(2 / zoomScale)),
      bgPaint,
    );
    tp.paint(
      canvas,
      Offset(
        x - tp.width / 2,
        y - tp.height - (8 / zoomScale) + padding.top / 2,
      ),
    );
  }

  /// Mendapat offset world-space akumulasi dari transform objek dan semua parent-nya.
  Point2D _getWorldOffset(ResolvedObject obj, Map<String, String> parentMap) {
    double tx = 0.0, ty = 0.0;
    String? currentId = obj.id;
    while (currentId != null) {
      final currentObj = scene.objects[currentId];
      if (currentObj != null) {
        for (final op in currentObj.transforms) {
          if (op is TranslateOp) {
            tx += op.x;
            ty += op.y;
          }
        }
      }
      currentId = parentMap[currentId];
    }
    return (x: tx, y: ty);
  }

  BoundingBox? _getBboxForObj(
    ResolvedObject obj,
    Map<String, String> parentMap,
  ) {
    try {
      // Karena transforms di objek dari ResolvedScene sudah diflatten,
      // kita tidak boleh mem-passing parentMap ke calculateBoundingBox
      // karena akan menyebabkan parent transforms diaplikasikan dua kali (double application).
      return geom.calculateBoundingBox({obj.id: obj}, parentMap: null);
    } catch (_) {
      return null;
    }
  }

  /// Anchor points dalam koordinat lokal objek.
  List<Point2D> _getAnchorPoints(ResolvedObject obj) {
    return switch (obj) {
      ResolvedRect(:final x, :final y, :final width, :final height) => [
        (x: x, y: y),
        (x: x + width, y: y),
        (x: x, y: y + height),
        (x: x + width, y: y + height),
        (x: x + width / 2, y: y + height / 2),
      ],
      ResolvedCircle(:final cx, :final cy) => [(x: cx, y: cy)],
      ResolvedEllipse(:final cx, :final cy) => [(x: cx, y: cy)],
      ResolvedLine(:final x1, :final y1, :final x2, :final y2) => [
        (x: x1, y: y1),
        (x: x2, y: y2),
        (x: (x1 + x2) / 2, y: (y1 + y2) / 2),
      ],
      ResolvedPoint(:final x, :final y) => [(x: x, y: y)],
      _ => [],
    };
  }

  /// Center point dalam koordinat lokal objek.
  Point2D? _getCenterForObj(ResolvedObject obj) {
    return switch (obj) {
      ResolvedRect(:final x, :final y, :final width, :final height) => (
        x: x + width / 2,
        y: y + height / 2,
      ),
      ResolvedCircle(:final cx, :final cy) => (x: cx, y: cy),
      ResolvedEllipse(:final cx, :final cy) => (x: cx, y: cy),
      ResolvedLine(:final x1, :final y1, :final x2, :final y2) => (
        x: (x1 + x2) / 2,
        y: (y1 + y2) / 2,
      ),
      ResolvedPoint(:final x, :final y) => (x: x, y: y),
      ResolvedArc(:final cx, :final cy) => (x: cx, y: cy),
      _ => null,
    };
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.scene != scene ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.overlay != overlay ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.showConstruction != showConstruction ||
        oldDelegate.sheetId != sheetId ||
        !setEquals(oldDelegate.hiddenRoles, hiddenRoles);
  }

  // ─────────────────────────────────────────────
  // Pembantu Transformasi (Transform Application)
  // ─────────────────────────────────────────────

  void applyTransformOp(Canvas canvas, ResolvedTransformOp op) {
    switch (op) {
      case TranslateOp(:final x, :final y):
        canvas.translate(x, y);
      case RotateOp(:final angle, :final origin):
        canvas.translate(origin.x, origin.y);
        canvas.rotate(angle * (math.pi / 180.0));
        canvas.translate(-origin.x, -origin.y);
      case ScaleOp(:final sx, :final sy, :final origin):
        canvas.translate(origin.x, origin.y);
        canvas.scale(sx, sy);
        canvas.translate(-origin.x, -origin.y);
      case MirrorOp(:final axis, :final origin):
        canvas.translate(origin.x, origin.y);
        if (axis.toLowerCase() == 'x') {
          canvas.scale(1.0, -1.0);
        } else {
          canvas.scale(-1.0, 1.0);
        }
        canvas.translate(-origin.x, -origin.y);
    }
  }

  // ─────────────────────────────────────────────
  // Fungsi Gambar Primitif (Drawing Functions)
  // ─────────────────────────────────────────────

  void drawPoint(Canvas canvas, ResolvedPoint pt, Paint paint) {
    final x = pt.x;
    final y = pt.y;
    final pointScale = sheetId != null
        ? _effectivePresentationalZoom()
        : zoomScale;
    final explicitSize = pt.meta.extra.containsKey('pointSize')
        ? RenderTypography.parseScalar(pt.meta.extra['pointSize'], 0)
        : null;
    final defaultSize = math.max(
      math.sqrt(
            scene.bbox.width * scene.bbox.width +
                scene.bbox.height * scene.bbox.height,
          ) *
          0.01,
      0.5,
    );
    final markerSize = (explicitSize ?? defaultSize) / pointScale;
    final pointShape = pt.meta.extra['pointShape']?.toString().trim() ?? 'plus';

    if (pointShape == 'circle') {
      final fillPaint = pt.meta.fill != null
          ? getPaintForMeta(pt.meta, isFill: true)
          : (paint.color.alpha > 0
                  ? (Paint()
                      ..color = paint.color
                      ..style = PaintingStyle.fill)
                  : Paint()
              ..color = Colors.transparent);
      final strokePaint = pt.meta.stroke != null
          ? getPaintForMeta(pt.meta, isFill: false)
          : (Paint()
              ..color = Colors.transparent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0);
      canvas.drawCircle(Offset(x, y), markerSize, fillPaint);
      if (strokePaint.color.alpha > 0 && strokePaint.strokeWidth > 0) {
        canvas.drawCircle(Offset(x, y), markerSize, strokePaint);
      }
      return;
    }

    final crossPaint = Paint()
      ..color = paint.color
      ..strokeWidth = 1.0 / pointScale
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(x - markerSize, y),
      Offset(x + markerSize, y),
      crossPaint,
    );
    canvas.drawLine(
      Offset(x, y - markerSize),
      Offset(x, y + markerSize),
      crossPaint,
    );
    canvas.drawCircle(
      Offset(x, y),
      1.5 / pointScale,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }

  void drawLine(
    Canvas canvas,
    ResolvedLine line,
    Paint paint,
    List<double> dashPattern,
  ) {
    final path = Path()
      ..moveTo(line.x1, line.y1)
      ..lineTo(line.x2, line.y2);
    drawDashedPath(canvas, path, paint, dashPattern);
  }

  void drawRect(
    Canvas canvas,
    ResolvedRect rect,
    Paint strokePaint,
    Paint fillPaint,
    List<double> dashPattern,
  ) {
    final path = Path()
      ..addRect(Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height));

    for (final hole in rect.holes) {
      final holePath = Path();
      bool first = true;
      for (final seg in hole.segments) {
        final pts = geom.sampleSegmentLikePoints(seg);
        if (pts.isEmpty) continue;
        if (first) {
          holePath.moveTo(pts.first.x, pts.first.y);
          first = false;
        }
        for (final p in pts.skip(1)) {
          holePath.lineTo(p.x, p.y);
        }
      }
      holePath.close();
      path.addPath(holePath, Offset.zero);
    }

    if (fillPaint.color.alpha > 0) {
      canvas.drawPath(path, fillPaint);
    }
    drawDashedPath(canvas, path, strokePaint, dashPattern);
  }

  void drawCircle(
    Canvas canvas,
    ResolvedCircle circle,
    Paint strokePaint,
    Paint fillPaint,
    List<double> dashPattern,
  ) {
    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(circle.cx, circle.cy),
          radius: circle.radius,
        ),
      );

    for (final hole in circle.holes) {
      final holePath = Path();
      bool first = true;
      for (final seg in hole.segments) {
        final pts = geom.sampleSegmentLikePoints(seg);
        if (pts.isEmpty) continue;
        if (first) {
          holePath.moveTo(pts.first.x, pts.first.y);
          first = false;
        }
        for (final p in pts.skip(1)) {
          holePath.lineTo(p.x, p.y);
        }
      }
      holePath.close();
      path.addPath(holePath, Offset.zero);
    }

    if (fillPaint.color.alpha > 0) {
      canvas.drawPath(path, fillPaint);
    }
    drawDashedPath(canvas, path, strokePaint, dashPattern);
  }

  void drawEllipse(
    Canvas canvas,
    ResolvedEllipse ellipse,
    Paint strokePaint,
    Paint fillPaint,
    List<double> dashPattern,
  ) {
    final base = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(ellipse.cx, ellipse.cy),
          width: ellipse.rx * 2,
          height: ellipse.ry * 2,
        ),
      );
    final matrix = Matrix4.identity()
      ..translate(ellipse.cx, ellipse.cy)
      ..rotateZ(ellipse.rotation)
      ..translate(-ellipse.cx, -ellipse.cy);
    final rotated = base.transform(matrix.storage);

    final path = Path()..addPath(rotated, Offset.zero);

    for (final hole in ellipse.holes) {
      final holePath = Path();
      bool first = true;
      for (final seg in hole.segments) {
        final pts = geom.sampleSegmentLikePoints(seg);
        if (pts.isEmpty) continue;
        if (first) {
          holePath.moveTo(pts.first.x, pts.first.y);
          first = false;
        }
        for (final p in pts.skip(1)) {
          holePath.lineTo(p.x, p.y);
        }
      }
      holePath.close();
      path.addPath(holePath, Offset.zero);
    }

    if (fillPaint.color.alpha > 0) {
      canvas.drawPath(path, fillPaint);
    }
    drawDashedPath(canvas, path, strokePaint, dashPattern);
  }

  void drawArc(
    Canvas canvas,
    ResolvedArc arc,
    Paint paint,
    List<double> dashPattern,
  ) {
    final rect = Rect.fromCircle(
      center: Offset(arc.cx, arc.cy),
      radius: arc.radius,
    );
    final path = Path();

    double startAngle = arc.startAngle;
    double endAngle = arc.endAngle;

    if (arc.sweep == 1 && endAngle < startAngle) endAngle += 2 * math.pi;
    if (arc.sweep == 0 && endAngle > startAngle) endAngle -= 2 * math.pi;

    final sweepAngle = endAngle - startAngle;
    path.addArc(rect, startAngle, sweepAngle);
    drawDashedPath(canvas, path, paint, dashPattern);
  }

  void drawQuadratic(
    Canvas canvas,
    ResolvedQuadratic quad,
    Paint paint,
    List<double> dashPattern,
  ) {
    final path = Path()
      ..moveTo(quad.x1, quad.y1)
      ..quadraticBezierTo(quad.cpx, quad.cpy, quad.x2, quad.y2);
    drawDashedPath(canvas, path, paint, dashPattern);
  }

  void drawCubic(
    Canvas canvas,
    ResolvedCubic cubic,
    Paint paint,
    List<double> dashPattern,
  ) {
    final path = Path()
      ..moveTo(cubic.x1, cubic.y1)
      ..cubicTo(
        cubic.cp1x,
        cubic.cp1y,
        cubic.cp2x,
        cubic.cp2y,
        cubic.x2,
        cubic.y2,
      );
    drawDashedPath(canvas, path, paint, dashPattern);
  }

  void drawSegments(
    Canvas canvas,
    List<PathResolvedSegment> segments,
    List<ResolvedHole> holes,
    bool closed,
    Paint strokePaint,
    Paint fillPaint,
    List<double> dashPattern,
  ) {
    if (segments.isEmpty) return;
    final path = Path();

    Point2D? lastEnd;
    for (final seg in segments) {
      final pts = geom.sampleSegmentLikePoints(seg);
      if (pts.isEmpty) continue;

      final start = pts.first;
      if (lastEnd == null) {
        path.moveTo(start.x, start.y);
      } else {
        final dx = start.x - lastEnd.x;
        final dy = start.y - lastEnd.y;
        if (math.sqrt(dx * dx + dy * dy) > 1e-5) {
          path.moveTo(start.x, start.y);
        }
      }

      for (final p in pts.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      lastEnd = pts.last;
    }
    if (closed) {
      path.close();
    }

    for (final hole in holes) {
      final holePath = Path();
      Point2D? holeLastEnd;
      for (final seg in hole.segments) {
        final pts = geom.sampleSegmentLikePoints(seg);
        if (pts.isEmpty) continue;

        final start = pts.first;
        if (holeLastEnd == null) {
          holePath.moveTo(start.x, start.y);
        } else {
          final dx = start.x - holeLastEnd.x;
          final dy = start.y - holeLastEnd.y;
          if (math.sqrt(dx * dx + dy * dy) > 1e-5) {
            holePath.moveTo(start.x, start.y);
          }
        }

        for (final p in pts.skip(1)) {
          holePath.lineTo(p.x, p.y);
        }
        holeLastEnd = pts.last;
      }
      holePath.close();
      path.addPath(holePath, Offset.zero);
    }

    if (closed && fillPaint.color.alpha > 0) {
      canvas.drawPath(path, fillPaint);
    }
    drawDashedPath(canvas, path, strokePaint, dashPattern);
  }

  void drawText(Canvas canvas, ResolvedText textObj, Color textColor) {
    final textScale = sheetId != null ? _effectivePresentationalZoom() : 1.0;
    final fontSize = RenderTypography.textFontSize(textObj.meta) / textScale;
    final fontFamily = RenderTypography.fontFamily(textObj.meta);
    final lineHeight = RenderTypography.parseScalar(
      textObj.meta.extra['lineHeight'],
      1.0,
    );
    final resolvedTextColor = RenderTypography.textColor(
      textObj.meta,
      fallback: textColor,
      defaultFill: const Color(0xFF000000),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: textObj.content,
        style: TextStyle(
          color: resolvedTextColor,
          fontSize: fontSize,
          fontFamily: fontFamily,
          height: lineHeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Resolver already returns the final visual origin for text.
    tp.paint(canvas, Offset(textObj.x, textObj.y));
  }

  void drawArrowhead(Canvas canvas, ArrowheadLayout layout, Color color) {
    final path = Path()
      ..moveTo(layout.tip.x, layout.tip.y)
      ..lineTo(layout.wing1.x, layout.wing1.y)
      ..lineTo(layout.wing2.x, layout.wing2.y)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void drawDimension(Canvas canvas, ResolvedDimension dim, Color color) {
    final scaleRef = RenderTypography.sceneScaleRef(scene);
    final effectiveZoom = _effectivePresentationalZoom();
    final arrowLength =
        RenderTypography.arrowSize(dim.meta, scene) / effectiveZoom;
    final fontSize =
        RenderTypography.dimensionFontSize(dim.meta, scene) / effectiveZoom;
    final fontFamily = RenderTypography.fontFamily(dim.meta);
    final textColor = RenderTypography.textColor(
      dim.meta,
      fallback: color,
      defaultFill: const Color(0xFF444444),
    );

    switch (dim.kind) {
      case 'linear':
        final p1 = dim.fromPoint;
        final p2 = dim.toPoint;
        if (p1 == null || p2 == null) return;
        final arrowWidth = arrowLength / 3;
        final layout = RenderPresentational.linearDimensionLayout(
          from: p1,
          to: p2,
          offset: dim.offset / _activeSheetPresentationalScale,
          arrowLength: arrowLength,
          arrowWidth: arrowWidth,
        );
        if (layout == null) return;

        final dimPaint = Paint()
          ..color = color
          ..strokeWidth = 1.0 / effectiveZoom
          ..style = PaintingStyle.stroke;

        canvas.drawLine(
          Offset(layout.extension1.from.x, layout.extension1.from.y),
          Offset(layout.extension1.to.x, layout.extension1.to.y),
          dimPaint,
        );
        canvas.drawLine(
          Offset(layout.extension2.from.x, layout.extension2.from.y),
          Offset(layout.extension2.to.x, layout.extension2.to.y),
          dimPaint,
        );
        canvas.drawLine(
          Offset(layout.dimensionLine.from.x, layout.dimensionLine.from.y),
          Offset(layout.dimensionLine.to.x, layout.dimensionLine.to.y),
          dimPaint,
        );

        drawArrowhead(canvas, layout.arrowStart, color);
        drawArrowhead(canvas, layout.arrowEnd, color);

        final tp = TextPainter(
          text: TextSpan(
            text: dim.text,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontFamily: fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final textBgPaint = Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;

        canvas.save();
        canvas.translate(layout.labelX, layout.labelY);
        canvas.rotate(layout.labelRotationDeg * math.pi / 180);
        canvas.translate(0, -layout.labelOffset);

        final rectWidth = tp.width + 8.0 / effectiveZoom;
        final rectHeight = tp.height + 4.0 / effectiveZoom;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: rectWidth,
            height: rectHeight,
          ),
          textBgPaint,
        );

        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
        return;
      case 'radius':
      case 'diameter':
        final target = dim.target != null ? scene.objects[dim.target] : null;
        late final double centerX;
        late final double centerY;
        late final double circleRadius;
        if (target is ResolvedCircle) {
          centerX = target.cx;
          centerY = target.cy;
          circleRadius = target.radius;
        } else if (target is ResolvedArc) {
          centerX = target.cx;
          centerY = target.cy;
          circleRadius = target.radius;
        } else {
          return;
        }
        final arrowWidth = arrowLength / 3;
        final layout = RenderPresentational.radialDimensionLayout(
          center: (x: centerX, y: centerY),
          radius: circleRadius,
          arrowLength: arrowLength,
          arrowWidth: arrowWidth,
          diameter: dim.kind == 'diameter',
        );
        if (layout == null) return;
        final basePaint = Paint()
          ..color = color
          ..strokeWidth = 1.0 / effectiveZoom
          ..style = PaintingStyle.stroke;

        canvas.drawLine(
          Offset(layout.baseLine.from.x, layout.baseLine.from.y),
          Offset(layout.baseLine.to.x, layout.baseLine.to.y),
          basePaint,
        );
        drawArrowhead(canvas, layout.arrowPrimary, color);
        if (layout.arrowSecondary != null) {
          drawArrowhead(canvas, layout.arrowSecondary!, color);
        }

        final path = Path()
          ..moveTo(layout.leader1.from.x, layout.leader1.from.y)
          ..lineTo(layout.leader1.to.x, layout.leader1.to.y)
          ..lineTo(layout.leader2.to.x, layout.leader2.to.y);
        canvas.drawPath(path, basePaint);
        _drawDimensionText(
          canvas,
          dim.text,
          Offset(layout.textX, layout.textY),
          textColor,
          fontSize,
          fontFamily,
          centered: false,
          background: false,
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
          presentationalScale: _activeSheetPresentationalScale,
        );
        if (layout == null) return;
        final center = Offset(layout.center.x, layout.center.y);
        final rect = Rect.fromCircle(center: center, radius: layout.radius);
        canvas.drawArc(
          rect,
          layout.startAngle,
          layout.sweepAngle,
          false,
          Paint()
            ..color = color
            ..strokeWidth = 1.0 / effectiveZoom
            ..style = PaintingStyle.stroke,
        );

        _drawDimensionText(
          canvas,
          dim.text,
          Offset(layout.textX, layout.textY),
          textColor,
          fontSize,
          fontFamily,
          centered: true,
          background: false,
        );
        return;
      default:
        return;
    }
  }

  double _effectivePresentationalZoom() {
    return zoomScale * _activeSheetPresentationalScale;
  }

  void _drawDimensionText(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double fontSize,
    String fontFamily, {
    required bool centered,
    required bool background,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final origin = centered
        ? Offset(at.dx - tp.width / 2, at.dy - tp.height / 2)
        : at;
    if (background) {
      final effectiveZoom = _effectivePresentationalZoom();
      canvas.drawRect(
        Rect.fromLTWH(
          origin.dx - 4.0 / effectiveZoom,
          origin.dy - 2.0 / effectiveZoom,
          tp.width + 8.0 / effectiveZoom,
          tp.height + 4.0 / effectiveZoom,
        ),
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill,
      );
    }
    tp.paint(canvas, origin);
  }

  void drawAnnotation(Canvas canvas, ResolvedAnnotation ann, Color color) {
    if (ann.leader != null) {
      final leader = ann.leader!;
      final effectiveZoom = _effectivePresentationalZoom();
      final fontSize =
          RenderTypography.annotationFontSize(ann.meta, scene) / effectiveZoom;
      final fontFamily = RenderTypography.fontFamily(ann.meta);
      final textColor = RenderTypography.textColor(
        ann.meta,
        fallback: color,
        defaultFill: const Color(0xFF333333),
      );
      final layout = RenderPresentational.annotationLeaderLayout(
        from: leader.fromPoint,
        to: leader.toPoint,
        text: ann.text,
        fontSize: fontSize,
        arrowLength:
            RenderPresentational.annotationArrowLength /
            _activeSheetPresentationalScale,
        arrowWidth:
            RenderPresentational.annotationArrowWidth /
            _activeSheetPresentationalScale,
        gap:
            RenderPresentational.annotationGap /
            _activeSheetPresentationalScale,
      );

      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.0 / effectiveZoom
        ..style = PaintingStyle.stroke;

      final from = Offset(layout.from.x, layout.from.y);
      final to = Offset(layout.to.x, layout.to.y);
      canvas.drawLine(from, to, paint);
      canvas.drawCircle(
        from,
        2.0 / effectiveZoom,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      if (layout.arrowhead != null) {
        final arrow = layout.arrowhead!;
        final path = Path()
          ..moveTo(arrow.tip.x, arrow.tip.y)
          ..lineTo(arrow.wing1.x, arrow.wing1.y)
          ..lineTo(arrow.wing2.x, arrow.wing2.y)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      }

      final tp = TextPainter(
        text: TextSpan(
          text: ann.text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textOffset = Offset(layout.textX, layout.textY);
      canvas.drawLine(to, Offset(layout.anchorLineEndX, to.dy), paint);

      tp.paint(canvas, textOffset);
      return;
    }

    if (ann.target != null) {
      final targetObj = scene.objects[ann.target!];
      if (targetObj == null) return;
      final fontSize =
          RenderTypography.annotationFontSize(ann.meta, scene) /
          _effectivePresentationalZoom();
      final fontFamily = RenderTypography.fontFamily(ann.meta);
      final textColor = RenderTypography.textColor(
        ann.meta,
        fallback: color,
        defaultFill: const Color(0xFF333333),
      );
      final targetBBox = geom.calculateBoundingBox({targetObj.id: targetObj});
      final layout = RenderPresentational.annotationTargetFallbackLayout(
        targetBBox: targetBBox,
        text: ann.text,
        fontSize: fontSize,
        gap:
            RenderPresentational.annotationGap /
            _activeSheetPresentationalScale,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: ann.text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(layout.textX, layout.textY));
    }
  }

  // ─────────────────────────────────────────────
  // Algoritma Garis Putus-putus Berkinerja Tinggi
  // ─────────────────────────────────────────────

  void drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> pattern,
  ) {
    if (pattern.isEmpty) {
      canvas.drawPath(path, paint);
      return;
    }
    final Path dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      int patternIndex = 0;
      while (distance < metric.length) {
        final len = pattern[patternIndex];
        if (draw) {
          dashedPath.addPath(
            metric.extractPath(
              distance,
              math.min(distance + len, metric.length),
            ),
            Offset.zero,
          );
        }
        distance += len;
        patternIndex = (patternIndex + 1) % pattern.length;
        draw = !draw;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  // ─────────────────────────────────────────────
  // Skema Warna & Gaya CAD Premium
  // ─────────────────────────────────────────────

  Color getDefaultRoleColor(String role) {
    return visualProfile.roleColor(role);
  }

  double getDefaultRoleStrokeWidth(String role) {
    return RenderStyle.defaultRoleStrokeWidth(role);
  }

  List<double> getDashPatternForMeta(Meta meta) {
    return RenderStyle.dashPatternForMeta(meta, zoomScale: zoomScale);
  }

  Paint getPaintForMeta(Meta meta, {required bool isFill}) {
    return RenderStyle.paintForMeta(
      meta,
      isFill: isFill,
      zoomScale: zoomScale,
      fallbackRoleColor: visualProfile.roleColor(meta.role),
    );
  }

  Color? parseColor(String str) {
    return RenderStyle.parseColor(str);
  }
}
