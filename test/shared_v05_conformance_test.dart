import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

import 'support/semantic_projection.dart';
import 'support/shared_fixture.dart';
import 'support/svg_semantic_projection.dart';

void main() {
  if (!hasSharedFixtures()) {
    test(
      'shared v0.5 fixtures require workspace fixture staging',
      () {},
      skip: 'Set RELGEO_FIXTURE_ROOT to run canonical workspace fixtures.',
    );
    return;
  }

  test('active v0.5 fixture matches the canonical semantic snapshot', () {
    final scene = resolveGeometry(
      loadSharedFixture('10-v05-relational-baseline.yaml'),
    );
    final expected = loadSharedExpectedJson('10-v05-relational-baseline.json');

    expectSemanticEqual(expected, projectScene(scene));
    expectSvgSemanticEqual(
      loadSharedExpectedText('10-v05-relational-baseline.svg'),
      SvgExporter.generateSVG(scene),
    );
  });

  test(
    'runtime diagnostic fixture matches the canonical semantic snapshot',
    () {
      final scene = resolveGeometry(
        loadSharedFixture('14-v05-runtime-align-violation.yaml'),
      );
      final expected = loadSharedExpectedJson(
        '14-v05-runtime-align-violation.json',
      );

      expectSemanticEqual(expected, projectScene(scene));
      expectSvgSemanticEqual(
        loadSharedExpectedText('14-v05-runtime-align-violation.svg'),
        SvgExporter.generateSVG(scene),
      );
    },
  );

  test('boolean and intersection candidate exercises Flutter capability', () {
    final scene = resolveGeometry(
      loadSharedFixture('15-v05-boolean-intersection-candidate.yaml'),
    );
    final expected = loadSharedExpectedJson(
      '15-v05-boolean-intersection-candidate.json',
    );

    expectCanonicalSemanticEqual(expected, projectScene(scene));
    expectSvgSemanticEqual(
      loadSharedExpectedText('15-v05-boolean-intersection-candidate.svg'),
      SvgExporter.generateSVG(scene),
    );

    final crossing = scene.objects['crossing'] as ResolvedPoint;
    expect(crossing.x, closeTo(50, 1e-6));
    expect(crossing.y, closeTo(24, 1e-6));

    final overlap = scene.objects['overlap'] as ResolvedBoolean;
    expect(overlap.operation, 'intersect');
    expect(overlap.points, hasLength(4));
    expect(_pointKeys(overlap.points), {'30,20', '50,20', '50,40', '30,40'});
    expect(overlap.segments, hasLength(4));
    expect(overlap.holes, isEmpty);

    final cut = scene.objects['cut'] as ResolvedBoolean;
    expect(cut.operation, 'subtract');
    expect(cut.points, hasLength(6));
    expect(_pointKeys(cut.points), {
      '10,10',
      '50,10',
      '50,20',
      '30,20',
      '30,40',
      '10,40',
    });
    expect(cut.segments, hasLength(6));
    expect(cut.holes, isEmpty);
  });

  test(
    'evaluator and units candidate matches the canonical semantic snapshot',
    () {
      final scene = resolveGeometry(
        loadSharedFixture('16-v05-evaluator-units-candidate.yaml'),
      );
      final expected = loadSharedExpectedJson(
        '16-v05-evaluator-units-candidate.json',
      );

      expectCanonicalSemanticEqual(expected, projectScene(scene));
      expectSvgSemanticEqual(
        loadSharedExpectedText('16-v05-evaluator-units-candidate.svg'),
        SvgExporter.generateSVG(scene),
      );

      final panel = scene.objects['panel'] as ResolvedRect;
      expect(panel.x, closeTo(15, 1e-6));
      expect(panel.y, closeTo(10, 1e-6));
      expect(panel.width, closeTo(20, 1e-6));
      expect(panel.height, closeTo(25.4, 1e-6));

      final marker = scene.objects['marker'] as ResolvedCircle;
      expect(marker.radius, closeTo(2, 1e-6));
    },
  );
}

Set<String> _pointKeys(List<Point2D> points) {
  return {for (final point in points) '${point.x.toInt()},${point.y.toInt()}'};
}
