import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

ResolvedScene _baseScene() {
  return ResolvedScene(
    unit: LengthUnit.mm,
    objects: {
      'frame': ResolvedRect(
        id: 'frame',
        meta: Meta(stroke: '#0f172a'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      ),
      'buildLine': ResolvedLine(
        id: 'buildLine',
        meta: Meta(role: 'construction'),
        x1: 0,
        y1: 0,
        x2: 100,
        y2: 0,
      ),
    },
    parameters: const {},
    values: const {},
    bbox: const BoundingBox(x: 0, y: 0, width: 100, height: 50),
  );
}

void main() {
  test(
    'canvas painter resolves visible default stroke width for preview path',
    () {
      final painter = CanvasPainter(scene: _baseScene(), zoomScale: 1.0);
      final strokePaint = painter.getPaintForMeta(
        Meta(role: 'final', stroke: '#0f172a'),
        isFill: false,
      );

      expect(strokePaint.style, PaintingStyle.stroke);
      expect(strokePaint.strokeWidth, 0.5);
    },
  );

  test('canvas painter scales visible default stroke width with zoom', () {
    final painter = CanvasPainter(scene: _baseScene(), zoomScale: 4.0);
    final strokePaint = painter.getPaintForMeta(
      Meta(role: 'final', stroke: '#0f172a'),
      isFill: false,
    );

    expect(strokePaint.strokeWidth, 0.125);
  });

  test('canvas painter should repaint when zoomScale changes', () {
    final oldPainter = CanvasPainter(scene: _baseScene(), zoomScale: 1.0);
    final newPainter = CanvasPainter(scene: _baseScene(), zoomScale: 2.0);

    expect(newPainter.shouldRepaint(oldPainter), isTrue);
  });

  test('canvas painter should repaint when showConstruction changes', () {
    final oldPainter = CanvasPainter(
      scene: _baseScene(),
      showConstruction: false,
    );
    final newPainter = CanvasPainter(
      scene: _baseScene(),
      showConstruction: true,
    );

    expect(newPainter.shouldRepaint(oldPainter), isTrue);
  });

  test('canvas painter should repaint when hiddenRoles changes in sheet mode', () {
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: _baseScene().objects,
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 0, y: 0, width: 100, height: 50),
      views: {
        'front': ResolvedView(
          id: 'front',
          target: 'frame',
          scale: '1:1',
          scaleFactor: 1,
          objects: _baseScene().objects,
          bbox: const BoundingBox(x: 0, y: 0, width: 100, height: 50),
        ),
      },
      sheets: {
        'drawing1': ResolvedSheet(
          id: 'drawing1',
          size: 'A4',
          width: 297,
          height: 210,
          views: [
            ResolvedSheetView(
              use: 'front',
              x: 20,
              y: 20,
              width: 100,
              height: 50,
            ),
          ],
        ),
      },
    );

    final oldPainter = CanvasPainter(
      scene: scene,
      sheetId: 'drawing1',
      hiddenRoles: const {'construction'},
    );
    final newPainter = CanvasPainter(
      scene: scene,
      sheetId: 'drawing1',
      hiddenRoles: const {'construction', 'guide'},
    );

    expect(newPainter.shouldRepaint(oldPainter), isTrue);
  });
}
