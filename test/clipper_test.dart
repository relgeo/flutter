import 'package:flutter_test/flutter_test.dart';
import 'package:clipper2/clipper2.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

void main() {
  test('Clipper2 Basic Operations Test', () {
    final subject = [
      PointD(0, 0),
      PointD(100, 0),
      PointD(100, 100),
      PointD(0, 100),
    ];

    final clip = [
      PointD(50, 50),
      PointD(150, 50),
      PointD(150, 150),
      PointD(50, 150),
    ];

    final unionResult = Clipper.unionD(
      subject: [subject],
      clip: [clip],
      fillRule: FillRule.nonZero,
    );

    expect(unionResult.length, greaterThan(0));

    final intersectResult = Clipper.intersectD(
      subject: [subject],
      clip: [clip],
      fillRule: FillRule.nonZero,
    );
    expect(intersectResult.length, greaterThan(0));

    final diffResult = Clipper.differenceD(
      subject: [subject],
      clip: [clip],
      fillRule: FillRule.nonZero,
    );
    expect(diffResult.length, greaterThan(0));

    final xorResult = Clipper.xorD(
      subject: [subject],
      clip: [clip],
      fillRule: FillRule.nonZero,
    );
    expect(xorResult.length, greaterThan(0));
  });

  test('ClipperBooleanEngine Rect & Circle Integration Test', () {
    final rect = ResolvedRect(
      id: 'rect1',
      meta: Meta(),
      x: 0,
      y: 0,
      width: 100,
      height: 100,
    );

    final circle = ResolvedCircle(
      id: 'circle1',
      meta: Meta(),
      cx: 50,
      cy: 50,
      radius: 60,
    );

    final normalizedRect = normalizeClosedShape(rect);
    final normalizedCircle = normalizeClosedShape(circle);

    expect(normalizedRect.outer.length, equals(4));
    expect(normalizedCircle.outer.length, equals(64));

    final engine = ClipperBooleanEngine();
    
    // Test subtract (Rect - Circle)
    final subResult = engine.subtract(normalizedRect, [normalizedCircle]);
    // Since circle is centered at 50,50 with radius 60, the corners (which are at distance ~70.7)
    // are not covered, so it yields 4 separate corner shapes.
    expect(subResult.length, equals(4));

    // Test union with a smaller circle at 100, 100 with radius 20 (partially overlaps)
    final smallCircle = ResolvedCircle(
      id: 'circle2',
      meta: Meta(),
      cx: 100,
      cy: 100,
      radius: 20,
    );
    final normalizedSmallCircle = normalizeClosedShape(smallCircle);
    final unionResult = engine.union([normalizedRect, normalizedSmallCircle]);
    expect(unionResult.length, equals(1)); // Merged into 1 shape
    expect(unionResult.first.outer.length, greaterThan(4));
  });

  test('resolveBoolean integration test with placement and multiple shapes', () {
    final ctx = ResolveContext(
      scalars: {},
      objects: {},
      targetUnit: LengthUnit.mm,
      parentMap: {},
      mode: 'editor',
      textMetrics: TextMetricsProvider(),
      doc: {},
    );

    // base circle at 50,50 with radius 40
    final baseCircle = ResolvedCircle(
      id: 'base_circle',
      meta: Meta(visible: false),
      cx: 50,
      cy: 50,
      radius: 40,
    );
    ctx.objects['base_circle'] = baseCircle;

    // cutter_rect size [40, 100], centered at [50,50] via place: { center: [50, 50] }
    final cutterRect = ResolvedRect(
      id: 'cutter_rect',
      meta: Meta(visible: false),
      x: 30, // 50 - 40/2
      y: 0,  // 50 - 100/2
      width: 40,
      height: 100,
    );
    ctx.objects['cutter_rect'] = cutterRect;

    // cutter_rect2 size [100, 40], centered at [50,50] via place: { center: [50, 50] }
    final cutterRect2 = ResolvedRect(
      id: 'cutter_rect2',
      meta: Meta(visible: false),
      x: 0,  // 50 - 100/2
      y: 30, // 50 - 40/2
      width: 100,
      height: 40,
    );
    ctx.objects['cutter_rect2'] = cutterRect2;

    // resolveBoolean Subtract
    final resolvedBoolean = resolveBoolean('shape_subtract', {
      'operation': 'subtract',
      'base': 'base_circle',
      'tools': ['cutter_rect', 'cutter_rect2'],
      'place': {'topLeft': [0, 0]},
    }, ctx);

    expect(resolvedBoolean, isNotNull);
    expect(resolvedBoolean.operation, equals('subtract'));
    // Since it's subtracted by a cross, the circle is divided into 4 corners
    // Our resolver should have flattened all of them, yielding points and segments
    expect(resolvedBoolean.points, isNotEmpty);
    expect(resolvedBoolean.segments, isNotEmpty);
    
    // Check that placement was resolved: place: {topLeft: [0, 0]}
    // Since it was placed at [0, 0], let's check the bounding box or transformed coordinates
    final bbox = calculateBoundingBox({'shape_subtract': resolvedBoolean});
    expect(bbox.x, closeTo(0.0, 1e-5));
    expect(bbox.y, closeTo(0.0, 1e-5));
  });
}
