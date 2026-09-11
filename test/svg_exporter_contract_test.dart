import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

void main() {
  test(
    'svg exporter hides construction by default and can show it explicitly',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'buildLine': ResolvedLine(
            id: 'buildLine',
            meta: Meta(role: 'construction'),
            x1: 0,
            y1: 0,
            x2: 100,
            y2: 0,
          ),
          'panel': ResolvedRect(
            id: 'panel',
            meta: Meta(),
            x: 0,
            y: 0,
            width: 100,
            height: 50,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 0, y: 0, width: 100, height: 50),
      );

      final hiddenByDefault = SvgExporter.generateSVG(scene);
      expect(hiddenByDefault.contains('id="buildLine"'), isFalse);

      final shownExplicitly = SvgExporter.generateSVG(
        scene,
        showConstruction: true,
      );
      expect(shownExplicitly.contains('id="buildLine"'), isTrue);
    },
  );

  test(
    'svg exporter exposes inspection metadata attributes for rendered objects',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'marker': ResolvedRect(
            id: 'marker',
            meta: Meta(
              role: 'final',
              label: 'M1',
              extra: {'intent': 'inspection-mark'},
            ),
            x: 10,
            y: 20,
            width: 30,
            height: 15,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 10, y: 20, width: 30, height: 15),
      );

      final svg = SvgExporter.generateSVG(scene);
      expect(svg.contains('id="marker"'), isTrue);
      expect(svg.contains('class="role-final"'), isTrue);
      expect(svg.contains('data-role="final"'), isTrue);
      expect(svg.contains('data-intent="inspection-mark"'), isTrue);
      expect(svg.contains('data-label="M1"'), isTrue);
    },
  );

  test(
    'svg exporter respects hiddenRoles for non-construction technical roles',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'guideLine': ResolvedLine(
            id: 'guideLine',
            meta: Meta(role: 'guide'),
            x1: 0,
            y1: 0,
            x2: 100,
            y2: 0,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 0, y: 0, width: 100, height: 10),
      );

      final svg = SvgExporter.generateSVG(scene, hiddenRoles: {'guide'});
      expect(svg.contains('guideLine'), isFalse);
      expect(
        svg.contains('<line x1="0.0" y1="0.0" x2="100.0" y2="0.0"'),
        isFalse,
      );
    },
  );

  test(
    'svg exporter still hides construction by default even when hiddenRoles omits it',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'buildLine': ResolvedLine(
            id: 'buildLine',
            meta: Meta(role: 'construction'),
            x1: 0,
            y1: 0,
            x2: 100,
            y2: 0,
          ),
          'guideLine': ResolvedLine(
            id: 'guideLine',
            meta: Meta(role: 'guide'),
            x1: 0,
            y1: 10,
            x2: 100,
            y2: 10,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 0, y: 0, width: 100, height: 10),
      );

      final svg = SvgExporter.generateSVG(scene, hiddenRoles: const {'guide'});
      expect(svg.contains('id="buildLine"'), isFalse);
      expect(svg.contains('id="guideLine"'), isFalse);

      final shownExplicitly = SvgExporter.generateSVG(
        scene,
        showConstruction: true,
        hiddenRoles: const {'guide'},
      );
      expect(shownExplicitly.contains('id="buildLine"'), isTrue);
      expect(shownExplicitly.contains('id="guideLine"'), isFalse);
    },
  );

  test('svg exporter uses final-output default role palette baseline', () {
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: {
        'guideLine': ResolvedLine(
          id: 'guideLine',
          meta: Meta(role: 'guide'),
          x1: 0,
          y1: 0,
          x2: 20,
          y2: 0,
        ),
        'centerAxis': ResolvedLine(
          id: 'centerAxis',
          meta: Meta(role: 'centerline'),
          x1: 0,
          y1: 10,
          x2: 20,
          y2: 10,
        ),
        'hiddenEdge': ResolvedLine(
          id: 'hiddenEdge',
          meta: Meta(role: 'hidden'),
          x1: 0,
          y1: 20,
          x2: 20,
          y2: 20,
        ),
      },
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 0, y: 0, width: 20, height: 20),
    );

    final svg = SvgExporter.generateSVG(scene, hiddenRoles: const {});
    expect(svg.contains('id="guideLine"'), isTrue);
    expect(svg.contains('stroke="#3b82f6"'), isTrue);
    expect(svg.contains('id="centerAxis"'), isTrue);
    expect(svg.contains('stroke="#ff0000"'), isTrue);
    expect(svg.contains('id="hiddenEdge"'), isTrue);
    expect(svg.contains('stroke="#555555"'), isTrue);
  });

  test('svg exporter uses final-output default role dash baseline', () {
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: {
        'guideLine': ResolvedLine(
          id: 'guideLine',
          meta: Meta(role: 'guide'),
          x1: 0,
          y1: 0,
          x2: 20,
          y2: 0,
        ),
        'hiddenEdge': ResolvedLine(
          id: 'hiddenEdge',
          meta: Meta(role: 'hidden'),
          x1: 0,
          y1: 10,
          x2: 20,
          y2: 10,
        ),
        'centerAxis': ResolvedLine(
          id: 'centerAxis',
          meta: Meta(role: 'centerline'),
          x1: 0,
          y1: 20,
          x2: 20,
          y2: 20,
        ),
      },
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 0, y: 0, width: 20, height: 20),
    );

    final svg = SvgExporter.generateSVG(scene, hiddenRoles: const {});
    expect(svg.contains('id="guideLine"'), isTrue);
    expect(svg.contains('stroke-dasharray="2.0,2.0"'), isTrue);
    expect(svg.contains('id="hiddenEdge"'), isTrue);
    expect(svg.contains('stroke-dasharray="6.0,4.0"'), isTrue);
    expect(svg.contains('id="centerAxis"'), isTrue);
    expect(svg.contains('stroke-dasharray="12.0,3.0,3.0,3.0"'), isTrue);
  });

  test('svg exporter renders ellipse with rotation', () {
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: {
        'ellipse1': ResolvedEllipse(
          id: 'ellipse1',
          meta: Meta(fill: '#ddeeff', stroke: '#224466'),
          cx: 50,
          cy: 40,
          rx: 20,
          ry: 10,
          rotation: math.pi / 6,
        ),
      },
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 30, y: 30, width: 40, height: 20),
    );

    final svg = SvgExporter.generateSVG(scene);
    expect(svg.contains('<ellipse id="ellipse1"'), isTrue);
    expect(svg.contains('cx="50.0" cy="40.0" rx="20.0" ry="10.0"'), isTrue);
    expect(
      svg.contains('transform="rotate(29.999999999999996 50.0 40.0)"'),
      isTrue,
    );
  });

  test('svg exporter applies parent collection transforms to child geometry', () {
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: {
        'slotBody': ResolvedRect(
          id: 'slotBody',
          meta: Meta(stroke: '#224466', fill: '#ddeeff'),
          x: -6,
          y: -2,
          width: 12,
          height: 4,
        ),
        'slots': ResolvedCollection(
          id: 'slots',
          meta: Meta(),
          children: const ['slotBody'],
          transforms: [TranslateOp(40, 20), RotateOp(90, (x: 0, y: 0))],
        ),
      },
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: -6, y: -2, width: 52, height: 28),
    );

    final svg = SvgExporter.generateSVG(scene);

    expect(
      svg.contains(
        '<g transform="translate(40.0, 20.0) translate(0.0, 0.0) rotate(90.0) translate(-0.0, -0.0)">',
      ),
      isTrue,
    );
    expect(svg.contains('<rect id="slotBody"'), isTrue);
  });

  test(
    'svg exporter renders repeat.along items that use on.frame item.frame with oriented transforms',
    () {
      final doc = {
        'version': 0.5,
        'scene': {'unit': 'px'},
        'objects': {
          'guide': {
            'type': 'line',
            'from': [0, 0],
            'to': [0, 100],
          },
          'slots': {
            'type': 'repeat',
            'along': {
              'target': 'guide',
              'count': 3,
              'spacing': 'uniform-length',
            },
            'item': {
              'type': 'rect',
              'size': [10, 4],
              'on': {'frame': 'item.frame'},
            },
          },
        },
      };

      final scene = resolveGeometry(doc);
      final svg = SvgExporter.generateSVG(scene);

      expect(svg.contains('id="slots[0]"'), isTrue);
      expect(svg.contains('id="slots[1]"'), isTrue);
      expect(svg.contains('id="slots[2]"'), isTrue);
      expect(RegExp(r'rotate\(90\.0\)').allMatches(svg).length, equals(3));
    },
  );

  test(
    'sheet svg export includes annotation leader dot arrow accent and multiline text',
    () {
      final Map<String, ResolvedObject> viewObjects = {
        'callout': ResolvedAnnotation(
          id: 'callout',
          meta: Meta(role: 'annotation', stroke: '#555555'),
          text: 'EDGE A\nCHECK',
          leader: (fromPoint: (x: 20.0, y: 20.0), toPoint: (x: 60.0, y: 40.0)),
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 20, y: 20, width: 40, height: 20),
        views: {
          'annotationView': ResolvedView(
            id: 'annotationView',
            target: 'callout',
            scale: '1:1',
            scaleFactor: 1,
            objects: viewObjects,
            bbox: const BoundingBox(x: 20, y: 20, width: 40, height: 20),
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
                y: 30,
                width: 40,
                height: 20,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');
      expect(
        svg.contains(
          '<line x1="20.0" y1="20.0" x2="60.0" y2="40.0" stroke="#555555" stroke-width="0.5" vector-effect="non-scaling-stroke" />',
        ),
        isTrue,
      );
      expect(
        svg.contains('<circle cx="20.0" cy="20.0" r="2.0" fill="#555555"'),
        isTrue,
      );
      expect(svg.contains('<path d="M 20.0 20.0 L '), isTrue);
      expect(svg.contains('<line x1="60.0" y1="40.0" x2="'), isTrue);
      expect(svg.contains('<tspan x="64.0" dy="0">EDGE A</tspan>'), isTrue);
      expect(svg.contains('<tspan x="64.0" dy="1.2em">CHECK</tspan>'), isTrue);
    },
  );

  test(
    'sheet svg export preserves parent collection transforms inside the view hierarchy',
    () {
      final Map<String, ResolvedObject> viewObjects = {
        'slotBody': ResolvedRect(
          id: 'slotBody',
          meta: Meta(stroke: '#224466', fill: '#ddeeff'),
          x: -6,
          y: -2,
          width: 12,
          height: 4,
        ),
        'slots': ResolvedCollection(
          id: 'slots',
          meta: Meta(),
          children: const ['slotBody'],
          transforms: [TranslateOp(30, 15), RotateOp(90, (x: 0, y: 0))],
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: -6, y: -2, width: 42, height: 22),
        views: {
          'slotView': ResolvedView(
            id: 'slotView',
            target: 'slots',
            scale: '1:1',
            scaleFactor: 1,
            objects: viewObjects,
            bbox: const BoundingBox(x: -6, y: -2, width: 42, height: 22),
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
                use: 'slotView',
                x: 20,
                y: 30,
                width: 42,
                height: 22,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');

      expect(
        svg.contains(
          '<g transform="translate(30.0, 15.0) translate(0.0, 0.0) rotate(90.0) translate(-0.0, -0.0)">',
        ),
        isTrue,
      );
      expect(svg.contains('<rect id="slotBody"'), isTrue);
    },
  );

  test(
    'sheet svg export renders linear dimension with extension lines arrowheads and rotated label',
    () {
      final Map<String, ResolvedObject> viewObjects = {
        'dim': ResolvedDimension(
          id: 'dim',
          meta: Meta(
            role: 'dimension',
            stroke: '#336699',
            fill: '#112233',
            extra: {'fontSize': 12, 'arrowSize': 6},
          ),
          kind: 'linear',
          fromPoint: (x: 10.0, y: 20.0),
          toPoint: (x: 70.0, y: 20.0),
          offset: -15,
          text: '60mm',
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 10, y: 5, width: 60, height: 30),
        views: {
          'dimensionView': ResolvedView(
            id: 'dimensionView',
            target: 'dim',
            scale: '1:1',
            scaleFactor: 1,
            objects: viewObjects,
            bbox: const BoundingBox(x: 10, y: 5, width: 60, height: 30),
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
                y: 30,
                width: 60,
                height: 30,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');
      expect(
        svg.contains('<line x1="10.0" y1="18.2" x2="10.0" y2="2.0" />'),
        isTrue,
      );
      expect(
        svg.contains('<line x1="70.0" y1="18.2" x2="70.0" y2="2.0" />'),
        isTrue,
      );
      expect(
        svg.contains('<line x1="10.0" y1="5.0" x2="70.0" y2="5.0" />'),
        isTrue,
      );
      expect(
        svg.contains(
          '<path d="M 10.0 5.0 L 16.0 7.0 L 16.0 3.0 Z" fill="#336699"',
        ),
        isTrue,
      );
      expect(
        svg.contains(
          '<path d="M 70.0 5.0 L 64.0 7.0 L 64.0 3.0 Z" fill="#336699"',
        ),
        isTrue,
      );
      expect(
        svg.contains('transform="rotate(0.0, 40.0, 5.0) translate(0, -6.0)"'),
        isTrue,
      );
      expect(svg.contains('font-size="12.0px"'), isTrue);
      expect(svg.contains('fill="#112233"'), isTrue);
      expect(svg.contains('>60mm</text>'), isTrue);
    },
  );

  test(
    'sheet svg export compensates dimension presentational sizes inside scaled views',
    () {
      final Map<String, ResolvedObject> viewObjects = {
        'dim': ResolvedDimension(
          id: 'dim',
          meta: Meta(
            role: 'dimension',
            stroke: '#336699',
            fill: '#112233',
            extra: {'fontSize': 12, 'arrowSize': 6},
          ),
          kind: 'linear',
          fromPoint: (x: 10.0, y: 20.0),
          toPoint: (x: 70.0, y: 20.0),
          offset: -15,
          text: '60mm',
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 10, y: 5, width: 60, height: 30),
        views: {
          'dimensionView': ResolvedView(
            id: 'dimensionView',
            target: 'dim',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 20, y: 10, width: 120, height: 60),
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
                y: 30,
                width: 120,
                height: 60,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');
      expect(
        svg.contains(
          '<g transform="translate(20.0, 30.0) scale(2.0) translate(-10.0, -5.0)">',
        ),
        isTrue,
      );
      expect(
        svg.contains('transform="rotate(0.0, 40.0, 12.5) translate(0, -3.0)"'),
        isTrue,
      );
      expect(svg.contains('font-size="6.0px"'), isTrue);
      expect(
        svg.contains(
          '<path d="M 10.0 12.5 L 13.0 13.5 L 13.0 11.5 Z" fill="#336699"',
        ),
        isTrue,
      );
    },
  );

  test(
    'svg exporter renders radius dimension with leader and default stroke/text semantics',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'hole': ResolvedCircle(
            id: 'hole',
            meta: Meta(),
            cx: 50,
            cy: 50,
            radius: 20,
          ),
          'dim': ResolvedDimension(
            id: 'dim',
            meta: Meta(role: 'dimension', stroke: '#000000'),
            kind: 'radius',
            target: 'hole',
            text: 'R20',
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 30, y: 30, width: 40, height: 40),
      );

      final svg = SvgExporter.generateSVG(scene);
      expect(
        svg.contains(
          '<line x1="50.0" y1="50.0" x2="64.14213562373095" y2="64.14213562373095" stroke="#000000" stroke-width="0.5" vector-effect="non-scaling-stroke" />',
        ),
        isTrue,
      );
      expect(
        RegExp(
          r'<path d="M 64\.14213562373095 64\.14213562373095 L [^"]+" fill="#000000" stroke="none" />',
        ).hasMatch(svg),
        isTrue,
      );
      expect(
        svg.contains(
          '<path d="M 64.14213562373095 64.14213562373095 L 65.94213562373095 65.94213562373095 L 70.18477631085024 65.94213562373095" fill="none" stroke="#000000" stroke-width="0.5" vector-effect="non-scaling-stroke" />',
        ),
        isTrue,
      );
      expect(svg.contains('fill="#444444" stroke="none">R20</text>'), isTrue);
    },
  );

  test(
    'svg exporter renders diameter dimension with double arrowheads and custom text fill',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'hole': ResolvedCircle(
            id: 'hole',
            meta: Meta(),
            cx: 50,
            cy: 50,
            radius: 20,
          ),
          'dim': ResolvedDimension(
            id: 'dim',
            meta: Meta(role: 'dimension', stroke: '#336699', fill: '#112233'),
            kind: 'diameter',
            target: 'hole',
            text: 'D40',
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 30, y: 30, width: 40, height: 40),
      );

      final svg = SvgExporter.generateSVG(scene);
      expect(
        svg.contains(
          '<line x1="35.85786437626905" y1="35.85786437626905" x2="64.14213562373095" y2="64.14213562373095" stroke="#336699" stroke-width="0.5" vector-effect="non-scaling-stroke" />',
        ),
        isTrue,
      );
      expect(
        RegExp(r'fill="#336699" stroke="none"').allMatches(svg).length >= 2,
        isTrue,
      );
      expect(
        svg.contains(
          '<path d="M 64.14213562373095 64.14213562373095 L 65.94213562373095 65.94213562373095 L 70.18477631085024 65.94213562373095" fill="none" stroke="#336699" stroke-width="0.5" vector-effect="non-scaling-stroke" />',
        ),
        isTrue,
      );
      expect(svg.contains('fill="#112233" stroke="none">D40</text>'), isTrue);
    },
  );

  test(
    'svg exporter uses shared typography defaults for text annotation and dimension',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'label': ResolvedText(
            id: 'label',
            meta: Meta(),
            x: 10,
            y: 15,
            width: 20,
            height: 10,
            content: 'Hello',
          ),
          'note': ResolvedAnnotation(
            id: 'note',
            meta: Meta(role: 'annotation'),
            text: 'Callout',
            leader: (
              fromPoint: (x: 20.0, y: 20.0),
              toPoint: (x: 40.0, y: 30.0),
            ),
          ),
          'dim': ResolvedDimension(
            id: 'dim',
            meta: Meta(role: 'dimension'),
            kind: 'linear',
            fromPoint: (x: 0.0, y: 0.0),
            toPoint: (x: 50.0, y: 0.0),
            text: '50mm',
            offset: 10,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 0, y: 0, width: 50, height: 30),
      );

      final svg = SvgExporter.generateSVG(scene);
      expect(svg.contains('dominant-baseline="hanging"'), isTrue);
      expect(svg.contains('font-family="sans-serif"'), isTrue);
      expect(svg.contains('Hello</text>'), isTrue);
      expect(svg.contains('>50mm</text>'), isTrue);
    },
  );

  test(
    'svg exporter honors string typography metadata for text annotation and dimension',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'label': ResolvedText(
            id: 'label',
            meta: Meta(extra: {'fontSize': '14px'}),
            x: 10,
            y: 15,
            width: 20,
            height: 10,
            content: 'Hello',
          ),
          'note': ResolvedAnnotation(
            id: 'note',
            meta: Meta(role: 'annotation', extra: {'fontSize': '11px'}),
            text: 'Callout',
            leader: (
              fromPoint: (x: 20.0, y: 20.0),
              toPoint: (x: 40.0, y: 30.0),
            ),
          ),
          'dim': ResolvedDimension(
            id: 'dim',
            meta: Meta(
              role: 'dimension',
              extra: {'fontSize': '9px', 'arrowSize': '6px'},
            ),
            kind: 'linear',
            fromPoint: (x: 0.0, y: 0.0),
            toPoint: (x: 50.0, y: 0.0),
            text: '50mm',
            offset: 10,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 0, y: 0, width: 50, height: 30),
      );

      final svg = SvgExporter.generateSVG(scene);
      expect(svg.contains('id="label"'), isTrue);
      expect(svg.contains('font-size="14.0"'), isTrue);
      expect(svg.contains('id="note"'), isTrue);
      expect(svg.contains('font-size="11.0"'), isTrue);
      expect(svg.contains('id="dim"'), isTrue);
      expect(svg.contains('font-size="9.0px"'), isTrue);
      expect(
        svg.contains('transform="rotate(0.0, 25.0, 10.0) translate(0, -6.0)"'),
        isTrue,
      );
    },
  );

  test(
    'svg exporter renders target-only annotation with stable fallback placement',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'hole': ResolvedCircle(
            id: 'hole',
            meta: Meta(),
            cx: 50,
            cy: 50,
            radius: 10,
          ),
          'note': ResolvedAnnotation(
            id: 'note',
            meta: Meta(role: 'annotation'),
            target: 'hole',
            text: 'M6 clearance',
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 40, y: 40, width: 80, height: 20),
      );

      final svg = SvgExporter.generateSVG(scene);
      expect(svg.contains('dominant-baseline="hanging"'), isTrue);
      expect(svg.contains('M6 clearance'), isTrue);
      expect(
        RegExp(r'<text\b[^>]*id="note"[^>]*x="64\.0"').hasMatch(svg),
        isTrue,
      );
    },
  );

  test(
    'sheet svg export compensates annotation presentational sizes inside scaled views',
    () {
      final Map<String, ResolvedObject> viewObjects = {
        'callout': ResolvedAnnotation(
          id: 'callout',
          meta: Meta(
            role: 'annotation',
            stroke: '#555555',
            extra: {'fontSize': 10},
          ),
          text: 'EDGE A\nCHECK',
          leader: (fromPoint: (x: 20.0, y: 20.0), toPoint: (x: 60.0, y: 40.0)),
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 20, y: 20, width: 40, height: 20),
        views: {
          'annotationView': ResolvedView(
            id: 'annotationView',
            target: 'callout',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 40, y: 40, width: 80, height: 40),
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
                y: 30,
                width: 80,
                height: 40,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');
      expect(
        svg.contains(
          '<g transform="translate(20.0, 30.0) scale(2.0) translate(-20.0, -20.0)">',
        ),
        isTrue,
      );
      expect(
        svg.contains('<circle cx="20.0" cy="20.0" r="1.0" fill="#555555"'),
        isTrue,
      );
      expect(svg.contains('font-size="5.0"'), isTrue);
      expect(svg.contains('<tspan x="62.0" dy="0">EDGE A</tspan>'), isTrue);
    },
  );

  test(
    'sheet svg export compensates angular dimension presentational sizes inside scaled views',
    () {
      final Map<String, ResolvedObject> viewObjects = {
        'base': ResolvedLine(
          id: 'base',
          meta: Meta(stroke: '#111827'),
          x1: 0,
          y1: 0,
          x2: 20,
          y2: 0,
        ),
        'side': ResolvedLine(
          id: 'side',
          meta: Meta(stroke: '#111827'),
          x1: 0,
          y1: 0,
          x2: 0,
          y2: 20,
        ),
        'angle': ResolvedDimension(
          id: 'angle',
          meta: Meta(
            role: 'dimension',
            stroke: '#111827',
            extra: {'fontSize': 6, 'arrowSize': 4},
          ),
          kind: 'angle',
          between: const ['base', 'side'],
          text: '90deg',
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 0, y: 0, width: 20, height: 20),
        views: {
          'angleView': ResolvedView(
            id: 'angleView',
            target: 'angle',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 0, y: 0, width: 20, height: 20),
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
                use: 'angleView',
                x: 20,
                y: 30,
                width: 80,
                height: 80,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');
      expect(
        svg.contains(
          '<g transform="translate(20.0, 30.0) scale(2.0) translate(-0.0, -0.0)">',
        ),
        isTrue,
      );
      expect(svg.contains('A 10.0 10.0 0 0 1'), isTrue);
      expect(svg.contains('font-size="3.0px"'), isTrue);
    },
  );

  test(
    'sheet svg export compensates diameter dimension presentational sizes inside scaled views',
    () {
      final Map<String, ResolvedObject> viewObjects = {
        'hole': ResolvedCircle(
          id: 'hole',
          meta: Meta(stroke: '#111827'),
          cx: 20,
          cy: 20,
          radius: 10,
        ),
        'dim': ResolvedDimension(
          id: 'dim',
          meta: Meta(
            role: 'dimension',
            stroke: '#111827',
            extra: {'fontSize': 6, 'arrowSize': 4},
          ),
          kind: 'diameter',
          target: 'hole',
          text: '20mm',
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 10, y: 10, width: 20, height: 20),
        views: {
          'diameterView': ResolvedView(
            id: 'diameterView',
            target: 'hole',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 20, y: 20, width: 40, height: 40),
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
                use: 'diameterView',
                x: 20,
                y: 30,
                width: 80,
                height: 80,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');
      expect(
        svg.contains(
          '<g transform="translate(20.0, 30.0) scale(2.0) translate(-10.0, -10.0)">',
        ),
        isTrue,
      );
      expect(svg.contains('font-size="3.0px"'), isTrue);
      expect(svg.contains('fill="#111827" stroke="none"'), isTrue);
    },
  );

  test(
    'sheet svg export compensates text object font size inside scaled views',
    () {
      final Map<String, ResolvedObject> viewObjects = {
        'label': ResolvedText(
          id: 'label',
          meta: Meta(fill: '#111827', extra: {'fontSize': 8}),
          x: 20,
          y: 12,
          width: 30,
          height: 10,
          content: 'PLATE A',
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 20, y: 12, width: 30, height: 10),
        views: {
          'textView': ResolvedView(
            id: 'textView',
            target: 'label',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 40, y: 24, width: 60, height: 20),
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
                y: 30,
                width: 80,
                height: 30,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');
      expect(
        svg.contains(
          '<g transform="translate(20.0, 30.0) scale(2.0) translate(-20.0, -12.0)">',
        ),
        isTrue,
      );
      expect(svg.contains('font-size="4.0"'), isTrue);
      expect(svg.contains('>PLATE A</text>'), isTrue);
    },
  );

  test(
    'svg exporter renders point object with circle shape',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'mark': ResolvedPoint(
            id: 'mark',
            meta: Meta.fromJson({
              'fill': '#111827',
              'pointShape': 'circle',
              'pointSize': 3,
            }),
            x: 10,
            y: 12,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 10, y: 12, width: 1, height: 1),
      );

      final svg = SvgExporter.generateSVG(scene);
      expect(svg.contains('id="mark"'), isTrue);
      expect(svg.contains('cx="10.0" cy="12.0" r="3.0"'), isTrue);
    },
  );

  test(
    'sheet svg export compensates point marker size inside scaled views',
    () {
      final Map<String, ResolvedObject> viewObjects = {
        'mark': ResolvedPoint(
          id: 'mark',
          meta: Meta.fromJson({
            'fill': '#111827',
            'pointShape': 'circle',
            'pointSize': 4,
          }),
          x: 20,
          y: 20,
        ),
      };

      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: viewObjects,
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 20, y: 20, width: 1, height: 1),
        views: {
          'pointView': ResolvedView(
            id: 'pointView',
            target: 'mark',
            scale: '2:1',
            scaleFactor: 2,
            objects: viewObjects,
            bbox: const BoundingBox(x: 40, y: 40, width: 2, height: 2),
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
                y: 30,
                width: 40,
                height: 40,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');
      expect(
        svg.contains(
          '<g transform="translate(20.0, 30.0) scale(2.0) translate(-20.0, -20.0)">',
        ),
        isTrue,
      );
      expect(svg.contains('cx="20.0" cy="20.0" r="2.0"'), isTrue);
    },
  );

  test('sheet svg export uses resolved view bbox as framing source of truth', () {
    final viewObjects = <String, ResolvedObject>{
      'panel': ResolvedRect(
        id: 'panel',
        meta: Meta(stroke: '#111827'),
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
        ),
      },
    );

    final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');
    expect(
      svg.contains(
        '<g transform="translate(20.0, 30.0) scale(0.5) translate(-80.0, -20.0)">',
      ),
      isTrue,
    );
  });

  test('sheet svg export respects hiddenRoles inside the view viewport', () {
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: {
        'panel': ResolvedRect(
          id: 'panel',
          meta: Meta(role: 'final', stroke: '#111827'),
          x: 0,
          y: 0,
          width: 40,
          height: 20,
        ),
        'guideLine': ResolvedLine(
          id: 'guideLine',
          meta: Meta(role: 'guide', stroke: '#94a3b8'),
          x1: 0,
          y1: 10,
          x2: 40,
          y2: 10,
        ),
      },
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 0, y: 0, width: 40, height: 20),
      views: {
        'front': ResolvedView(
          id: 'front',
          target: 'panel',
          scale: '1:1',
          scaleFactor: 1,
          objects: {
            'panel': ResolvedRect(
              id: 'panel',
              meta: Meta(role: 'final', stroke: '#111827'),
              x: 0,
              y: 0,
              width: 40,
              height: 20,
            ),
            'guideLine': ResolvedLine(
              id: 'guideLine',
              meta: Meta(role: 'guide', stroke: '#94a3b8'),
              x1: 0,
              y1: 10,
              x2: 40,
              y2: 10,
            ),
          },
          bbox: const BoundingBox(x: 0, y: 0, width: 40, height: 20),
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
              width: 40,
              height: 20,
            ),
          ],
        ),
      },
    );

    final hiddenGuideSvg = SvgExporter.generateSVG(
      scene,
      sheetId: 'drawing1',
      hiddenRoles: const {'construction', 'guide'},
    );
    expect(hiddenGuideSvg.contains('stroke="#111827"'), isTrue);
    expect(hiddenGuideSvg.contains('stroke="#94a3b8"'), isFalse);

    final visibleGuideSvg = SvgExporter.generateSVG(
      scene,
      sheetId: 'drawing1',
      hiddenRoles: const {'construction'},
    );
    expect(visibleGuideSvg.contains('stroke="#94a3b8"'), isTrue);
  });

  test(
    'sheet svg export still hides construction by default even when hiddenRoles omits it',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'panel': ResolvedRect(
            id: 'panel',
            meta: Meta(role: 'final', stroke: '#111827'),
            x: 0,
            y: 0,
            width: 40,
            height: 20,
          ),
          'buildLine': ResolvedLine(
            id: 'buildLine',
            meta: Meta(role: 'construction', stroke: '#3b82f6'),
            x1: 0,
            y1: 10,
            x2: 40,
            y2: 10,
          ),
          'guideLine': ResolvedLine(
            id: 'guideLine',
            meta: Meta(role: 'guide', stroke: '#94a3b8'),
            x1: 0,
            y1: 12,
            x2: 40,
            y2: 12,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 0, y: 0, width: 40, height: 20),
        views: {
          'front': ResolvedView(
            id: 'front',
            target: 'panel',
            scale: '1:1',
            scaleFactor: 1,
            objects: {
              'panel': ResolvedRect(
                id: 'panel',
                meta: Meta(role: 'final', stroke: '#111827'),
                x: 0,
                y: 0,
                width: 40,
                height: 20,
              ),
              'buildLine': ResolvedLine(
                id: 'buildLine',
                meta: Meta(role: 'construction', stroke: '#3b82f6'),
                x1: 0,
                y1: 10,
                x2: 40,
                y2: 10,
              ),
              'guideLine': ResolvedLine(
                id: 'guideLine',
                meta: Meta(role: 'guide', stroke: '#94a3b8'),
                x1: 0,
                y1: 12,
                x2: 40,
                y2: 12,
              ),
            },
            bbox: const BoundingBox(x: 0, y: 0, width: 40, height: 20),
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
                width: 40,
                height: 20,
              ),
            ],
          ),
        },
      );

      final svg = SvgExporter.generateSVG(
        scene,
        sheetId: 'drawing1',
        hiddenRoles: const {'guide'},
      );
      expect(svg.contains('stroke="#111827"'), isTrue);
      expect(svg.contains('stroke="#3b82f6"'), isFalse);
      expect(svg.contains('stroke="#94a3b8"'), isFalse);

      final shownExplicitly = SvgExporter.generateSVG(
        scene,
        sheetId: 'drawing1',
        showConstruction: true,
        hiddenRoles: const {'guide'},
      );
      expect(shownExplicitly.contains('stroke="#3b82f6"'), isTrue);
      expect(shownExplicitly.contains('stroke="#94a3b8"'), isFalse);
    },
  );

  test(
    'svg exporter places wraparound angle dimension label on normalized sweep side',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'lineA': ResolvedLine(
            id: 'lineA',
            meta: Meta(role: 'construction'),
            x1: 0,
            y1: 0,
            x2: -98.4807753012208,
            y2: 17.364817766693026,
          ),
          'lineB': ResolvedLine(
            id: 'lineB',
            meta: Meta(role: 'construction'),
            x1: 0,
            y1: 0,
            x2: -98.4807753012208,
            y2: -17.364817766693026,
          ),
          'dim': ResolvedDimension(
            id: 'dim',
            meta: Meta(role: 'dimension'),
            kind: 'angle',
            between: const ['lineA', 'lineB'],
            text: '20deg',
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: -100, y: -20, width: 100, height: 40),
      );

      final svg = SvgExporter.generateSVG(scene, showConstruction: true);
      expect(svg.contains('A 20.0 20.0 0 0 1'), isTrue);
      expect(RegExp(r'<text\b[^>]*x="-').hasMatch(svg), isTrue);
      expect(svg.contains('>20deg</text>'), isTrue);
    },
  );

  test(
    'svg exporter renders multiline text with tspans and honors text fill',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.mm,
        objects: {
          'label': ResolvedText(
            id: 'label',
            meta: Meta(fill: '#cc3300', extra: {'lineHeight': 1.4}),
            x: 10,
            y: 15,
            width: 36,
            height: 24,
            content: 'Line 1\nLine 2',
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 10, y: 15, width: 36, height: 24),
      );

      final svg = SvgExporter.generateSVG(scene);
      expect(svg.contains('dominant-baseline="hanging"'), isTrue);
      expect(svg.contains('fill="#cc3300"'), isTrue);
      expect(svg.contains('<tspan x="10.0" dy="0">Line 1</tspan>'), isTrue);
      expect(svg.contains('<tspan x="10.0" dy="1.4em">Line 2</tspan>'), isTrue);
    },
  );
}
