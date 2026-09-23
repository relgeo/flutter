import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('bbox of gap-based repeat matches expected extent', () {
    final yaml = '''
scene:
  unit: "mm"
parameters:
  width: 100
  height: 60
objects:
  speaker_vents:
    type: repeat
    item:
      type: rect
      size: [2, 10]
    place:
      top: 10
      right: "width - 10"
    grid:
      rows: 1
      cols: 6
      gap: 3
''';

    final parsedYaml = loadYaml(yaml) as Map;
    final scene = resolveGeometry(parsedYaml);

    final bbox = scene.bbox;
    expect(bbox.x, equals(63.0));
    expect(bbox.y, equals(10.0));
    expect(bbox.width, equals(27.0));
    expect(bbox.height, equals(10.0));
  });
}
