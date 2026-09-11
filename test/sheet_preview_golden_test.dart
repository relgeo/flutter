import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'package:relgeo_flutter/src/ui/canvas_painter.dart';

void main() {
  testWidgets('sheet preview matches baseline golden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;

    final Map<String, ResolvedObject> viewObjects = {
      'panel': ResolvedRect(
        id: 'panel',
        meta: Meta(fill: '#E5E7EB', stroke: '#111827'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      ),
      'center_axis': ResolvedLine(
        id: 'center_axis',
        meta: Meta(role: 'centerline', stroke: '#DC2626'),
        x1: 50,
        y1: -10,
        x2: 50,
        y2: 60,
      ),
    };

    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: viewObjects,
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 0, y: 0, width: 100, height: 50),
      meta: Meta.fromJson({'author': 'RelGeo', 'date': '2026-07-08'}),
      views: {
        'front': ResolvedView(
          id: 'front',
          target: 'panel',
          scale: '1:2',
          scaleFactor: 0.5,
          objects: viewObjects,
          bbox: const BoundingBox(x: 0, y: 0, width: 50, height: 25),
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
              x: 24,
              y: 30,
              width: 50,
              height: 25,
            ),
          ],
          meta: Meta.fromJson({'title': 'Bracket Sheet', 'scale': '1:2'}),
        ),
      },
    );

    await tester.pumpWidget(
      _goldenHost(
        boundaryKey: const Key('sheet-preview-boundary'),
        width: 317,
        height: 230,
        painter: CanvasPainter(scene: scene, sheetId: 'drawing1'),
      ),
    );

    await tester.pump();

    expectLater(
      find.byKey(const Key('sheet-preview-boundary')),
      matchesGoldenFile('goldens/sheet_preview.png'),
    );
  });

  testWidgets('nested sheet preview matches complex hierarchy golden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;

    final Map<String, ResolvedObject> viewObjects = {
      'inst.body': ResolvedRect(
        id: 'inst.body',
        meta: Meta(fill: '#E2E8F0', stroke: '#111827'),
        x: 30,
        y: 20,
        width: 90,
        height: 40,
        transforms: [TranslateOp(15, 10)],
      ),
      'inst.note': ResolvedAnnotation(
        id: 'inst.note',
        meta: Meta(role: 'annotation'),
        text: 'FACE B',
        leader: (fromPoint: (x: 90.0, y: 50.0), toPoint: (x: 145.0, y: 70.0)),
      ),
      'inst.cluster': ResolvedGroup(
        id: 'inst.cluster',
        meta: Meta(stroke: '#AA5500'),
        children: ['inst.body', 'inst.note'],
      ),
      'inst': ResolvedComponent(
        id: 'inst',
        meta: Meta(stroke: '#1122CC'),
        children: ['inst.cluster'],
        hasExports: false,
      ),
    };

    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: viewObjects,
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 45, y: 30, width: 100, height: 40),
      meta: Meta.fromJson({'author': 'RelGeo', 'date': '2026-07-09'}),
      views: {
        'nestedView': ResolvedView(
          id: 'nestedView',
          target: 'inst',
          scale: '1:1',
          scaleFactor: 1,
          objects: viewObjects,
          bbox: const BoundingBox(x: 45, y: 30, width: 100, height: 40),
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
              use: 'nestedView',
              x: 24,
              y: 28,
              width: 100,
              height: 40,
            ),
          ],
          meta: Meta.fromJson({'title': 'Nested Assembly', 'scale': '1:1'}),
        ),
      },
    );

    await tester.pumpWidget(
      _goldenHost(
        boundaryKey: const Key('nested-sheet-preview-boundary'),
        width: 317,
        height: 230,
        painter: CanvasPainter(scene: scene, sheetId: 'drawing1'),
      ),
    );

    await tester.pump();

    expectLater(
      find.byKey(const Key('nested-sheet-preview-boundary')),
      matchesGoldenFile('goldens/nested_sheet_preview.png'),
    );
  });

  testWidgets('sheet preview matches dimension family golden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;

    final Map<String, ResolvedObject> viewObjects = {
      'panel': ResolvedRect(
        id: 'panel',
        meta: Meta(fill: '#E5E7EB', stroke: '#111827'),
        x: 20,
        y: 20,
        width: 120,
        height: 70,
      ),
      'hole': ResolvedCircle(
        id: 'hole',
        meta: Meta(fill: '#FFFFFF', stroke: '#111827'),
        cx: 70,
        cy: 55,
        radius: 12,
      ),
      'axisBase': ResolvedLine(
        id: 'axisBase',
        meta: Meta(role: 'construction', stroke: '#94A3B8'),
        x1: 190,
        y1: 80,
        x2: 270,
        y2: 80,
      ),
      'axisTilt': ResolvedLine(
        id: 'axisTilt',
        meta: Meta(role: 'construction', stroke: '#94A3B8'),
        x1: 190,
        y1: 80,
        x2: 245,
        y2: 25,
      ),
      'dimLinear': ResolvedDimension(
        id: 'dimLinear',
        meta: Meta(
          role: 'dimension',
          stroke: '#0F766E',
          fill: '#0F172A',
          extra: {'fontSize': 9, 'arrowSize': 6},
        ),
        kind: 'linear',
        fromPoint: (x: 20.0, y: 20.0),
        toPoint: (x: 140.0, y: 20.0),
        offset: -16,
        text: '120mm',
      ),
      'dimRadius': ResolvedDimension(
        id: 'dimRadius',
        meta: Meta(
          role: 'dimension',
          stroke: '#0F766E',
          fill: '#0F172A',
          extra: {'fontSize': 9, 'arrowSize': 6},
        ),
        kind: 'radius',
        target: 'hole',
        text: 'R12mm',
      ),
      'dimDiameter': ResolvedDimension(
        id: 'dimDiameter',
        meta: Meta(
          role: 'dimension',
          stroke: '#0F766E',
          fill: '#0F172A',
          extra: {'fontSize': 9, 'arrowSize': 6},
        ),
        kind: 'diameter',
        target: 'hole',
        text: 'D24mm',
      ),
      'dimAngle': ResolvedDimension(
        id: 'dimAngle',
        meta: Meta(
          role: 'dimension',
          stroke: '#0F766E',
          fill: '#0F172A',
          extra: {'fontSize': 9, 'arrowSize': 6},
        ),
        kind: 'angle',
        between: const ['axisBase', 'axisTilt'],
        text: '45deg',
      ),
    };

    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: viewObjects,
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 20, y: 4, width: 250, height: 86),
      meta: Meta.fromJson({'author': 'RelGeo', 'date': '2026-07-10'}),
      views: {
        'dimensionView': ResolvedView(
          id: 'dimensionView',
          target: 'panel',
          scale: '1:1',
          scaleFactor: 1,
          objects: viewObjects,
          bbox: const BoundingBox(x: 20, y: 4, width: 250, height: 86),
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
              use: 'dimensionView',
              x: 20,
              y: 24,
              width: 250,
              height: 86,
            ),
          ],
          meta: Meta.fromJson({'title': 'Dimension Family', 'scale': '1:1'}),
        ),
      },
    );

    await tester.pumpWidget(
      _goldenHost(
        boundaryKey: const Key('dimension-sheet-preview-boundary'),
        width: 317,
        height: 230,
        painter: CanvasPainter(
          scene: scene,
          sheetId: 'drawing1',
          showConstruction: true,
        ),
      ),
    );

    await tester.pump();

    expectLater(
      find.byKey(const Key('dimension-sheet-preview-boundary')),
      matchesGoldenFile('goldens/dimension_sheet_preview.png'),
    );
  });

  testWidgets('sheet preview matches text anchor and multiline golden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;

    final Map<String, ResolvedObject> viewObjects = {
      'guideBox': ResolvedRect(
        id: 'guideBox',
        meta: Meta(stroke: '#CBD5E1', fill: '#FFFFFF'),
        x: 20,
        y: 20,
        width: 180,
        height: 110,
      ),
      'topLeftMark': ResolvedCircle(
        id: 'topLeftMark',
        meta: Meta(fill: '#DC2626', stroke: '#DC2626'),
        cx: 40,
        cy: 38,
        radius: 2,
      ),
      'topCenterMark': ResolvedCircle(
        id: 'topCenterMark',
        meta: Meta(fill: '#2563EB', stroke: '#2563EB'),
        cx: 110,
        cy: 38,
        radius: 2,
      ),
      'bottomRightMark': ResolvedCircle(
        id: 'bottomRightMark',
        meta: Meta(fill: '#059669', stroke: '#059669'),
        cx: 190,
        cy: 120,
        radius: 2,
      ),
      'textTopLeft': ResolvedText(
        id: 'textTopLeft',
        meta: Meta(fill: '#111827'),
        x: 40,
        y: 38,
        width: 36,
        height: 12,
        content: 'TopLeft',
        anchor: 'topLeft',
      ),
      'textTopCenter': ResolvedText(
        id: 'textTopCenter',
        meta: Meta(fill: '#111827'),
        x: 80,
        y: 38,
        width: 60,
        height: 12,
        content: 'Centered',
        anchor: 'topCenter',
      ),
      'textBottomRight': ResolvedText(
        id: 'textBottomRight',
        meta: Meta(fill: '#111827', extra: {'lineHeight': 1.3}),
        x: 126,
        y: 96,
        width: 64,
        height: 24,
        content: 'Line A\nLine B',
        anchor: 'bottomRight',
      ),
    };

    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: viewObjects,
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 20, y: 20, width: 180, height: 110),
      meta: Meta.fromJson({'date': '2026-07-12'}),
      views: {
        'textView': ResolvedView(
          id: 'textView',
          target: 'guideBox',
          scale: '1:1',
          scaleFactor: 1,
          objects: viewObjects,
          bbox: const BoundingBox(x: 20, y: 20, width: 180, height: 110),
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
              use: 'textView',
              x: 24,
              y: 24,
              width: 180,
              height: 110,
            ),
          ],
          meta: Meta.fromJson({'title': 'Text Layout'}),
        ),
      },
    );

    await tester.pumpWidget(
      _goldenHost(
        boundaryKey: const Key('text-sheet-preview-boundary'),
        width: 317,
        height: 230,
        painter: CanvasPainter(scene: scene, sheetId: 'drawing1'),
      ),
    );

    await tester.pump();

    expectLater(
      find.byKey(const Key('text-sheet-preview-boundary')),
      matchesGoldenFile('goldens/text_sheet_preview.png'),
    );
  });

  testWidgets('sheet preview matches mixed presentational scene golden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;

    final Map<String, ResolvedObject> viewObjects = {
      'panel': ResolvedRect(
        id: 'panel',
        meta: Meta(fill: '#E5E7EB', stroke: '#111827'),
        x: 20,
        y: 20,
        width: 120,
        height: 70,
      ),
      'title': ResolvedText(
        id: 'title',
        meta: Meta(fill: '#1F2937', extra: {'lineHeight': 1.3}),
        x: 56,
        y: 24,
        width: 48,
        height: 24,
        content: 'FACE A\nCHECK',
        anchor: 'topCenter',
      ),
      'note': ResolvedAnnotation(
        id: 'note',
        meta: Meta(role: 'annotation', stroke: '#92400E'),
        text: 'EDGE\nBREAK',
        leader: (fromPoint: (x: 140.0, y: 55.0), toPoint: (x: 185.0, y: 35.0)),
      ),
      'dim': ResolvedDimension(
        id: 'dim',
        meta: Meta(
          role: 'dimension',
          stroke: '#0F766E',
          fill: '#0F172A',
          extra: {'fontSize': 10, 'arrowSize': 6},
        ),
        kind: 'linear',
        fromPoint: (x: 20.0, y: 20.0),
        toPoint: (x: 140.0, y: 20.0),
        offset: -14,
        text: '120mm',
      ),
    };

    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: viewObjects,
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 20, y: 6, width: 165, height: 84),
      meta: Meta.fromJson({'date': '2026-07-12'}),
      views: {
        'mixedView': ResolvedView(
          id: 'mixedView',
          target: 'panel',
          scale: '1:1',
          scaleFactor: 1,
          objects: viewObjects,
          bbox: const BoundingBox(x: 20, y: 6, width: 165, height: 84),
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
              use: 'mixedView',
              x: 20,
              y: 24,
              width: 165,
              height: 84,
            ),
          ],
          meta: Meta.fromJson({'title': 'Mixed Presentation'}),
        ),
      },
    );

    await tester.pumpWidget(
      _goldenHost(
        boundaryKey: const Key('mixed-sheet-preview-boundary'),
        width: 317,
        height: 230,
        painter: CanvasPainter(scene: scene, sheetId: 'drawing1'),
      ),
    );

    await tester.pump();

    expectLater(
      find.byKey(const Key('mixed-sheet-preview-boundary')),
      matchesGoldenFile('goldens/mixed_presentational_sheet_preview.png'),
    );
  });

  testWidgets('sheet preview matches scaled view framing golden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;

    final viewObjects = <String, ResolvedObject>{
      'panel': ResolvedRect(
        id: 'panel',
        meta: Meta(fill: '#E5E7EB', stroke: '#111827'),
        x: 100,
        y: 20,
        width: 100,
        height: 50,
      ),
    };

    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: viewObjects,
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 100, y: 20, width: 100, height: 50),
      meta: Meta.fromJson({'date': '2026-07-13'}),
      views: {
        'front': ResolvedView(
          id: 'front',
          target: 'panel',
          scale: '1:2',
          scaleFactor: 0.5,
          objects: viewObjects,
          bbox: const BoundingBox(x: 40, y: 10, width: 50, height: 25),
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
              y: 30,
              width: 50,
              height: 25,
            ),
          ],
          meta: Meta.fromJson({'title': 'Scaled Framing'}),
        ),
      },
    );

    await tester.pumpWidget(
      _goldenHost(
        boundaryKey: const Key('scaled-sheet-preview-boundary'),
        width: 317,
        height: 230,
        painter: CanvasPainter(scene: scene, sheetId: 'drawing1'),
      ),
    );

    await tester.pump();

    expectLater(
      find.byKey(const Key('scaled-sheet-preview-boundary')),
      matchesGoldenFile('goldens/scaled_sheet_preview.png'),
    );
  });

  testWidgets(
    'sheet preview matches scaled presentational physical-preview golden',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;

      final viewObjects = <String, ResolvedObject>{
        'panel': ResolvedRect(
          id: 'panel',
          meta: Meta(fill: '#E5E7EB', stroke: '#111827'),
          x: 20,
          y: 20,
          width: 120,
          height: 70,
        ),
        'dim': ResolvedDimension(
          id: 'dim',
          meta: Meta(
            role: 'dimension',
            stroke: '#0F766E',
            fill: '#0F172A',
            extra: {'fontSize': 10, 'arrowSize': 6},
          ),
          kind: 'linear',
          fromPoint: (x: 20.0, y: 20.0),
          toPoint: (x: 140.0, y: 20.0),
          offset: -16,
          text: '120mm',
        ),
        'note': ResolvedAnnotation(
          id: 'note',
          meta: Meta(
            role: 'annotation',
            stroke: '#92400E',
            extra: {'fontSize': 10},
          ),
          text: 'EDGE\nCHECK',
          leader: (
            fromPoint: (x: 140.0, y: 55.0),
            toPoint: (x: 185.0, y: 35.0),
          ),
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 20, y: 4, width: 165, height: 86),
        meta: Meta.fromJson({'date': '2026-07-20'}),
        views: {
          'detail': ResolvedView(
            id: 'detail',
            target: 'panel',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 40, y: 8, width: 330, height: 172),
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
                use: 'detail',
                x: 20,
                y: 24,
                width: 330,
                height: 172,
              ),
            ],
            meta: Meta.fromJson({'title': 'Scaled Presentation'}),
          ),
        },
      );

      await tester.pumpWidget(
        _goldenHost(
          boundaryKey: const Key(
            'scaled-presentational-sheet-preview-boundary',
          ),
          width: 360,
          height: 250,
          painter: CanvasPainter(scene: scene, sheetId: 'drawing1'),
        ),
      );

      await tester.pump();

      expectLater(
        find.byKey(const Key('scaled-presentational-sheet-preview-boundary')),
        matchesGoldenFile('goldens/scaled_presentational_sheet_preview.png'),
      );
    },
  );

  testWidgets(
    'sheet preview matches scaled dimension family physical-preview golden',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(980, 760);
      tester.view.devicePixelRatio = 1.0;

      final viewObjects = <String, ResolvedObject>{
        'panel': ResolvedRect(
          id: 'panel',
          meta: Meta(fill: '#E5E7EB', stroke: '#111827'),
          x: 20,
          y: 20,
          width: 120,
          height: 70,
        ),
        'hole': ResolvedCircle(
          id: 'hole',
          meta: Meta(fill: '#FFFFFF', stroke: '#111827'),
          cx: 70,
          cy: 55,
          radius: 10,
        ),
        'axisBase': ResolvedLine(
          id: 'axisBase',
          meta: Meta(role: 'construction', stroke: '#94A3B8'),
          x1: 180,
          y1: 78,
          x2: 250,
          y2: 78,
        ),
        'axisTilt': ResolvedLine(
          id: 'axisTilt',
          meta: Meta(role: 'construction', stroke: '#94A3B8'),
          x1: 180,
          y1: 78,
          x2: 230,
          y2: 28,
        ),
        'dimLinear': ResolvedDimension(
          id: 'dimLinear',
          meta: Meta(
            role: 'dimension',
            stroke: '#0F766E',
            fill: '#0F172A',
            extra: {'fontSize': 10, 'arrowSize': 6},
          ),
          kind: 'linear',
          fromPoint: (x: 20.0, y: 20.0),
          toPoint: (x: 140.0, y: 20.0),
          offset: -16,
          text: '120mm',
        ),
        'dimRadius': ResolvedDimension(
          id: 'dimRadius',
          meta: Meta(
            role: 'dimension',
            stroke: '#0F766E',
            fill: '#0F172A',
            extra: {'fontSize': 10, 'arrowSize': 6},
          ),
          kind: 'radius',
          target: 'hole',
          text: 'R10mm',
        ),
        'dimDiameter': ResolvedDimension(
          id: 'dimDiameter',
          meta: Meta(
            role: 'dimension',
            stroke: '#0F766E',
            fill: '#0F172A',
            extra: {'fontSize': 10, 'arrowSize': 6},
          ),
          kind: 'diameter',
          target: 'hole',
          text: 'D20mm',
        ),
        'dimAngle': ResolvedDimension(
          id: 'dimAngle',
          meta: Meta(
            role: 'dimension',
            stroke: '#0F766E',
            fill: '#0F172A',
            extra: {'fontSize': 10, 'arrowSize': 6},
          ),
          kind: 'angle',
          between: const ['axisBase', 'axisTilt'],
          text: '45deg',
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 20, y: 4, width: 230, height: 84),
        meta: Meta.fromJson({'date': '2026-07-20'}),
        views: {
          'dimensionView': ResolvedView(
            id: 'dimensionView',
            target: 'panel',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 40, y: 8, width: 460, height: 168),
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
                use: 'dimensionView',
                x: 18,
                y: 22,
                width: 460,
                height: 168,
              ),
            ],
            meta: Meta.fromJson({'title': 'Scaled Dimension Family'}),
          ),
        },
      );

      await tester.pumpWidget(
        _goldenHost(
          boundaryKey: const Key(
            'scaled-dimension-family-sheet-preview-boundary',
          ),
          width: 400,
          height: 260,
          painter: CanvasPainter(
            scene: scene,
            sheetId: 'drawing1',
            showConstruction: true,
          ),
        ),
      );

      await tester.pump();

      expectLater(
        find.byKey(
          const Key('scaled-dimension-family-sheet-preview-boundary'),
        ),
        matchesGoldenFile(
          'goldens/scaled_dimension_family_sheet_preview.png',
        ),
      );
    },
  );

  testWidgets(
    'sheet preview matches scaled text physical-preview golden',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;

      final viewObjects = <String, ResolvedObject>{
        'guideBox': ResolvedRect(
          id: 'guideBox',
          meta: Meta(stroke: '#CBD5E1', fill: '#FFFFFF'),
          x: 20,
          y: 20,
          width: 120,
          height: 70,
        ),
        'title': ResolvedText(
          id: 'title',
          meta: Meta(fill: '#111827', extra: {'fontSize': 12, 'lineHeight': 1.2}),
          x: 34,
          y: 28,
          width: 80,
          height: 24,
          content: 'PLATE A\nCHECK',
          anchor: 'topLeft',
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 20, y: 20, width: 120, height: 70),
        meta: Meta.fromJson({'date': '2026-07-20'}),
        views: {
          'textView': ResolvedView(
            id: 'textView',
            target: 'guideBox',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 40, y: 40, width: 240, height: 140),
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
                use: 'textView',
                x: 20,
                y: 24,
                width: 240,
                height: 140,
              ),
            ],
            meta: Meta.fromJson({'title': 'Scaled Text'}),
          ),
        },
      );

      await tester.pumpWidget(
        _goldenHost(
          boundaryKey: const Key('scaled-text-sheet-preview-boundary'),
          width: 360,
          height: 250,
          painter: CanvasPainter(scene: scene, sheetId: 'drawing1'),
        ),
      );

      await tester.pump();

      expectLater(
        find.byKey(const Key('scaled-text-sheet-preview-boundary')),
        matchesGoldenFile('goldens/scaled_text_sheet_preview.png'),
      );
    },
  );

  testWidgets(
    'sheet preview matches scaled point physical-preview golden',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;

      final viewObjects = <String, ResolvedObject>{
        'guideBox': ResolvedRect(
          id: 'guideBox',
          meta: Meta(stroke: '#CBD5E1', fill: '#FFFFFF'),
          x: 20,
          y: 20,
          width: 120,
          height: 70,
        ),
        'markA': ResolvedPoint(
          id: 'markA',
          meta: Meta.fromJson({
            'fill': '#111827',
            'pointShape': 'circle',
            'pointSize': 4,
          }),
          x: 40,
          y: 40,
        ),
        'markB': ResolvedPoint(
          id: 'markB',
          meta: Meta.fromJson({
            'stroke': '#0F766E',
            'pointShape': 'plus',
            'pointSize': 5,
          }),
          x: 110,
          y: 65,
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 20, y: 20, width: 120, height: 70),
        meta: Meta.fromJson({'date': '2026-07-20'}),
        views: {
          'pointView': ResolvedView(
            id: 'pointView',
            target: 'guideBox',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 40, y: 40, width: 240, height: 140),
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
                use: 'pointView',
                x: 20,
                y: 24,
                width: 240,
                height: 140,
              ),
            ],
            meta: Meta.fromJson({'title': 'Scaled Point'}),
          ),
        },
      );

      await tester.pumpWidget(
        _goldenHost(
          boundaryKey: const Key('scaled-point-sheet-preview-boundary'),
          width: 360,
          height: 250,
          painter: CanvasPainter(scene: scene, sheetId: 'drawing1'),
        ),
      );

      await tester.pump();

      expectLater(
        find.byKey(const Key('scaled-point-sheet-preview-boundary')),
        matchesGoldenFile('goldens/scaled_point_sheet_preview.png'),
      );
    },
  );

  testWidgets('sheet preview matches target-only annotation fallback golden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;

    final viewObjects = <String, ResolvedObject>{
      'hole': ResolvedCircle(
        id: 'hole',
        meta: Meta(fill: '#FFFFFF', stroke: '#111827'),
        cx: 70,
        cy: 55,
        radius: 10,
      ),
      'note': ResolvedAnnotation(
        id: 'note',
        meta: Meta(role: 'annotation'),
        target: 'hole',
        text: 'M6 clearance',
      ),
    };

    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: viewObjects,
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 60, y: 45, width: 90, height: 20),
      meta: Meta.fromJson({'date': '2026-07-13'}),
      views: {
        'annotationView': ResolvedView(
          id: 'annotationView',
          target: 'hole',
          scale: '1:1',
          scaleFactor: 1,
          objects: viewObjects,
          bbox: const BoundingBox(x: 60, y: 45, width: 90, height: 20),
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
              use: 'annotationView',
              x: 20,
              y: 24,
              width: 90,
              height: 20,
            ),
          ],
          meta: Meta.fromJson({'title': 'Target Annotation'}),
        ),
      },
    );

    await tester.pumpWidget(
      _goldenHost(
        boundaryKey: const Key('target-annotation-sheet-preview-boundary'),
        width: 317,
        height: 230,
        painter: CanvasPainter(scene: scene, sheetId: 'drawing1'),
      ),
    );

    await tester.pump();

    expectLater(
      find.byKey(const Key('target-annotation-sheet-preview-boundary')),
      matchesGoldenFile('goldens/target_annotation_sheet_preview.png'),
    );
  });

  testWidgets(
    'scene preview keeps default stroke visible under fit-like scale',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;

      const fitScale = 0.18;
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'frame': ResolvedRect(
            id: 'frame',
            meta: Meta(stroke: '#111827'),
            x: 0,
            y: 0,
            width: 1600,
            height: 1000,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 0, y: 0, width: 1600, height: 1000),
      );

      await tester.pumpWidget(
        _goldenHost(
          boundaryKey: const Key('fit-visible-stroke-scene-preview-boundary'),
          width: 320,
          height: 220,
          sceneScale: fitScale,
          painter: CanvasPainter(scene: scene, zoomScale: fitScale),
        ),
      );

      await tester.pump();

      expectLater(
        find.byKey(const Key('fit-visible-stroke-scene-preview-boundary')),
        matchesGoldenFile('goldens/fit_visible_stroke_scene_preview.png'),
      );
    },
  );
}

Widget _goldenHost({
  required Key boundaryKey,
  required double width,
  required double height,
  required CanvasPainter painter,
  double sceneScale = 1.0,
}) {
  final displayWidth = painter.sheetId != null
      ? painter.scene.sheets[painter.sheetId]!.width
      : painter.scene.bbox.width;
  final displayHeight = painter.sheetId != null
      ? painter.scene.sheets[painter.sheetId]!.height
      : painter.scene.bbox.height;
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Center(
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: width,
            height: height,
            child: Transform.translate(
              offset: const Offset(10, 10),
              child: Transform.scale(
                alignment: Alignment.topLeft,
                scale: sceneScale,
                child: CustomPaint(
                  size: Size(displayWidth, displayHeight),
                  painter: painter,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
