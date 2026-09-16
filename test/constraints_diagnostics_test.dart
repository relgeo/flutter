import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

void main() {
  test('align point diagnostic follows the TypeScript contract baseline', () {
    final scene = resolveGeometry({
      'version': 0.5,
      'objects': {
        'first': {
          'type': 'point',
          'at': [0, 0],
        },
        'second': {
          'type': 'point',
          'at': [10, 10],
        },
      },
      'constraints': [
        {
          'align': {'target': 'first', 'with': 'second'},
        },
      ],
    });

    expect(scene.violations, hasLength(1));
    final violation = scene.violations.single;
    expect(violation.type, 'align');
    expect(violation.message, 'Points are not aligned. Distance: 14.1421');
    expect(violation.deviation, closeTo(14.142135623730951, 1e-9));
    expect(violation.path, 'constraints[0]');
    expect(violation.involvedObjects, isEmpty);
    expect(violation.visualHelper?.x1, 0);
    expect(violation.visualHelper?.y1, 0);
    expect(violation.visualHelper?.x2, 10);
    expect(violation.visualHelper?.y2, 10);
  });
}
