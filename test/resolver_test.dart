import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

class _CustomTextMetricsProvider extends TextMetricsProvider {
  @override
  TextMetrics measure({
    required String content,
    required double fontSize,
    String? fontFamily,
    dynamic fontWeight,
    String? fontStyle,
    required double lineHeight,
  }) {
    return TextMetrics(
      width: 100.0,
      height: 40.0,
    );
  }
}

Map<dynamic, dynamic> _loadFixture(String name) {
  final file = File('../fixtures/reference/$name');
  return loadYaml(file.readAsStringSync()) as Map<dynamic, dynamic>;
}

void main() {
  group('RelGeo Compiler & resolver.dart Test Suite', () {
    test('Topological Scene Resolution & Geometry Evaluation', () {
      final doc = {
        'scene': {'unit': 'mm'},
        'parameters': {
          'lebar': {'default': '120mm'},
          'tinggi': {'default': '80mm'},
        },
        'derived': {'centerX': 'lebar / 2', 'centerY': 'tinggi / 2'},
        'objects': {
          'rect1': {
            'type': 'rect',
            'size': ['lebar', 'tinggi'],
          },
          'p1': {
            'type': 'point',
            'at': ['centerX', 'centerY'],
          },
          'circle1': {'type': 'circle', 'center': 'p1', 'radius': '25mm'},
        },
      };

      final scene = resolveGeometry(doc);

      expect(scene.unit, equals(LengthUnit.mm));
      expect(scene.objects.containsKey('rect1'), isTrue);
      expect(scene.objects.containsKey('p1'), isTrue);
      expect(scene.objects.containsKey('circle1'), isTrue);

      final rect = scene.objects['rect1'] as ResolvedRect;
      expect(rect.width, equals(120.0));
      expect(rect.height, equals(80.0));

      final p1 = scene.objects['p1'] as ResolvedPoint;
      expect(p1.x, equals(60.0));
      expect(p1.y, equals(40.0));

      final circle = scene.objects['circle1'] as ResolvedCircle;
      expect(circle.cx, equals(60.0));
      expect(circle.cy, equals(40.0));
      expect(circle.radius, equals(25.0));
    });

    test('Text fallback metrics use v0.4 baseline defaults', () {
      final doc = {
        'version': 0.4,
        'objects': {
          'label': {
            'type': 'text',
            'at': [100.0, 40.0],
            'content': 'Hello',
          },
        },
      };

      final scene = resolveGeometry(doc);
      final label = scene.objects['label'] as ResolvedText;

      expect(label.width, equals(36.0));
      expect(label.height, equals(12.0));
      expect(label.x, equals(100.0));
      expect(label.y, equals(40.0));
    });

    test('Text anchor topCenter shifts resolved x like core TypeScript', () {
      final doc = {
        'version': 0.4,
        'objects': {
          'label': {
            'type': 'text',
            'at': [100.0, 40.0],
            'content': 'Hello',
            'anchor': 'topCenter',
          },
        },
      };

      final scene = resolveGeometry(doc);
      final label = scene.objects['label'] as ResolvedText;

      expect(label.width, equals(36.0));
      expect(label.height, equals(12.0));
      expect(label.x, equals(82.0));
      expect(label.y, equals(40.0));
    });

    test('Text anchors expose bottomCenter from resolved bounding box', () {
      final doc = {
        'version': 0.4,
        'objects': {
          't1': {
            'type': 'text',
            'at': [50.0, 60.0],
            'content': 'Hello',
            'anchor': 'topLeft',
          },
          'p1': {'type': 'point', 'at': 't1.bottomCenter'},
        },
      };

      final scene = resolveGeometry(doc);
      final p1 = scene.objects['p1'] as ResolvedPoint;

      expect(p1.x, equals(68.0));
      expect(p1.y, equals(72.0));
    });

    test('Text fallback metrics measure multiline width by longest line', () {
      final provider = TextMetricsProvider();
      final metrics = provider.measure(
        content: 'AB\nLONGER',
        fontSize: 10.0,
        lineHeight: 1.0,
      );

      expect(metrics.width, equals(36.0));
      expect(metrics.height, equals(20.0));
    });

    test('Text resolver accepts string fontSize and lineHeight like TypeScript', () {
      final doc = {
        'version': 0.5,
        'objects': {
          'label': {
            'type': 'text',
            'at': [100.0, 40.0],
            'anchor': 'center',
            'content': 'AB\nLONGER',
            'meta': {
              'fontSize': '14px',
              'lineHeight': '1.5',
            },
          },
        },
      };

      final scene = resolveGeometry(doc);
      final label = scene.objects['label'] as ResolvedText;

      expect(label.width, closeTo(50.4, 1e-9));
      expect(label.height, closeTo(42.0, 1e-9));
      expect(label.x, closeTo(74.8, 1e-9));
      expect(label.y, closeTo(19.0, 1e-9));
    });

    test('Text resolver honors injected textMetrics provider for layout', () {
      final doc = {
        'version': 0.5,
        'objects': {
          'label': {
            'type': 'text',
            'at': [100.0, 40.0],
            'anchor': 'center',
            'content': 'AB\nLONGER',
          },
        },
      };

      final scene = resolveGeometry(
        doc,
        ResolveOptions(textMetrics: _CustomTextMetricsProvider()),
      );
      final label = scene.objects['label'] as ResolvedText;

      expect(label.width, equals(100.0));
      expect(label.height, equals(40.0));
      expect(label.x, equals(50.0));
      expect(label.y, equals(20.0));
    });

    test(
      'component params inherit applies ordered multiple inherit before local overrides',
      () {
        final doc = {
          'version': 0.5,
          'scene': {'unit': 'mm'},
          'constants': {
            'commonBracket': {
              'width': 120,
              'thickness': 6,
            },
            'standardBoltM6': {
              'diameter': 6,
              'clearance': 0.5,
            },
          },
          'components': {
            'holeMark': {
              'parameters': {
                'diameter': {'type': 'length', 'default': 4},
                'clearance': {'type': 'length', 'default': 0},
                'width': {'type': 'length', 'default': 10},
              },
              'objects': {
                'guide': {
                  'type': 'line',
                  'from': [0, 0],
                  'to': ['width + diameter + clearance', 0],
                },
              },
              'exports': {
                'end': 'guide.end',
              },
            },
          },
          'objects': {
            'hole1': {
              'type': 'component',
              'use': 'holeMark',
              'params': {
                'inherit': ['commonBracket', 'standardBoltM6'],
                'diameter': 8,
              },
            },
          },
        };

        final scene = resolveGeometry(doc);
        final guide = scene.objects['hole1.guide'] as ResolvedLine;

        expect(guide.x2, closeTo(128.5, 1e-9));
      },
    );

    test(
      'metaPreset, meta.inherit, and local meta merge in normative order',
      () {
        final doc = {
          'version': 0.5,
          'scene': {'unit': 'mm'},
          'constants': {
            'inspectionOverlay': {
              'dash': '4 2',
              'opacity': 0.7,
              'strokeWidth': 3,
            },
          },
          'metaPresets': {
            'guideLine': {
              'stroke': '#999999',
              'strokeWidth': 1,
            },
          },
          'objects': {
            'centerLine': {
              'type': 'line',
              'from': [0, 0],
              'to': [10, 0],
              'metaPreset': 'guideLine',
              'meta': {
                'inherit': 'inspectionOverlay',
                'strokeWidth': 2,
                'intent': 'centerline',
              },
            },
          },
        };

        final scene = resolveGeometry(doc);
        final line = scene.objects['centerLine'] as ResolvedLine;

        expect(line.meta.stroke, equals('#999999'));
        expect(line.meta.dash, equals('4 2'));
        expect(line.meta.opacity, equals(0.7));
        expect(line.meta.strokeWidth, equals(2.0));
        expect(line.meta.extra['intent'], equals('centerline'));
      },
    );

    test('meta.inherit resolves through metaPresets before local overrides', () {
      final doc = {
        'version': 0.5,
        'scene': {'unit': 'mm'},
        'metaPresets': {
          'finalStroke': {
            'role': 'final',
            'stroke': '#111827',
            'strokeWidth': 1,
          },
          'inspectionMark': {
            'inherit': 'finalStroke',
            'dash': '4 2',
            'opacity': 0.7,
          },
        },
        'objects': {
          'mark': {
            'type': 'line',
            'from': [0, 0],
            'to': [10, 0],
            'meta': {
              'inherit': 'inspectionMark',
              'intent': 'inspection-mark',
              'strokeWidth': 2,
            },
          },
        },
      };

      final scene = resolveGeometry(doc);
      final mark = scene.objects['mark'] as ResolvedLine;

      expect(mark.meta.role, equals('final'));
      expect(mark.meta.stroke, equals('#111827'));
      expect(mark.meta.dash, equals('4 2'));
      expect(mark.meta.opacity, equals(0.7));
      expect(mark.meta.strokeWidth, equals(2.0));
      expect(mark.meta.extra['intent'], equals('inspection-mark'));
    });

    test(
      'style alias still resolves through styles map for backward compatibility',
      () {
        final doc = {
          'version': 0.5,
          'styles': {
            'guideLine': {
              'stroke': '#999999',
              'strokeWidth': 1,
            },
          },
          'objects': {
            'centerLine': {
              'type': 'line',
              'from': [0, 0],
              'to': [10, 0],
              'style': 'guideLine',
            },
          },
        };

        final scene = resolveGeometry(doc);
        final line = scene.objects['centerLine'] as ResolvedLine;

        expect(line.meta.stroke, equals('#999999'));
        expect(line.meta.strokeWidth, equals(1.0));
      },
    );

    test('cyclic structured inherit throws CIRCULAR_INHERIT', () {
      final doc = {
        'version': 0.5,
        'constants': {
          'a': {
            'inherit': 'b',
            'stroke': '#111111',
          },
          'b': {
            'inherit': 'a',
            'stroke': '#222222',
          },
        },
        'objects': {
          'centerLine': {
            'type': 'line',
            'from': [0, 0],
            'to': [10, 0],
            'meta': {
              'inherit': 'a',
            },
          },
        },
      };

      expect(
        () => resolveGeometry(doc),
        throwsA(
          predicate(
            (error) => error.toString().contains('CIRCULAR_INHERIT'),
          ),
        ),
      );
    });

    test('Complex Multi-level Anchors & Transformations Resolution', () {
      final doc = {
        'scene': {'unit': 'px'},
        'objects': {
          'rect1': {
            'type': 'rect',
            'size': [100.0, 50.0],
            'transform': [
              {
                'translate': [10.0, 20.0],
              },
            ],
          },
          'p1': {'type': 'point', 'at': 'rect1.center'},
        },
      };

      final scene = resolveGeometry(doc);

      expect(scene.objects.containsKey('rect1'), isTrue);
      expect(scene.objects.containsKey('p1'), isTrue);

      final rect = scene.objects['rect1'] as ResolvedRect;
      expect(rect.x, equals(10.0)); // translation applied to x/y of rect
      expect(rect.y, equals(20.0));

      final p1 = scene.objects['p1'] as ResolvedPoint;
      // rect1.center (raw) = (50, 25). With TranslateOp(10, 20), p1 = (60, 45).
      expect(p1.x, equals(60.0));
      expect(p1.y, equals(45.0));
    });

    test(
      'Structural Component, Repeat, Divide, and Style/Transform Propagation',
      () {
        final doc = {
          'version': 0.4,
          'scene': {'unit': 'mm'},
          'components': {
            'bolt': {
              'parameters': {'diameter': 5, 'length': 15},
              'objects': {
                'head': {
                  'type': 'circle',
                  'center': [0, 0],
                  'radius': 'diameter * 1.5',
                },
                'shaft': {
                  'type': 'line',
                  'from': [0, 0],
                  'to': [0, 'length'],
                },
              },
              'exports': {'centerPoint': 'head.center', 'tip': 'shaft.end'},
            },
          },
          'objects': {
            'plate': {
              'type': 'rect',
              'place': {
                'center': [0, 0],
              },
              'size': [100, 50],
            },
            'hole_path': {
              'type': 'path',
              'points': [
                [-40, -15],
                [40, -15],
              ],
              'meta': {'role': 'construction'},
            },
            'hole_centers': {
              'type': 'divide',
              'target': 'hole_path',
              'count': 3,
            },
            'bolts': {
              'type': 'repeat',
              'each': 'hole_centers',
              'item': {
                'type': 'component',
                'use': 'bolt',
                'params': {'diameter': 4, 'length': 12},
                'on': {
                  'point': {'at': 'item', 'anchor': 'centerPoint'},
                },
                'transform': [
                  {
                    'rotate': {
                      'angle': 'index * 45deg',
                      'origin': 'centerPoint',
                    },
                  },
                ],
              },
            },
          },
        };

        final scene = resolveGeometry(doc);

        // Verify that all 3 points of hole_centers were generated
        expect(scene.objects.containsKey('hole_centers[0]'), isTrue);
        expect(scene.objects.containsKey('hole_centers[1]'), isTrue);
        expect(scene.objects.containsKey('hole_centers[2]'), isTrue);

        final p0 = scene.objects['hole_centers[0]'] as ResolvedPoint;
        final p1 = scene.objects['hole_centers[1]'] as ResolvedPoint;
        final p2 = scene.objects['hole_centers[2]'] as ResolvedPoint;
        expect(p0.x, equals(-40.0));
        expect(p1.x, equals(0.0));
        expect(p2.x, equals(40.0));

        // Verify that repeated bolt components and their nested child objects are generated
        expect(scene.objects.containsKey('bolts[0]'), isTrue);
        expect(scene.objects.containsKey('bolts[0].head'), isTrue);
        expect(scene.objects.containsKey('bolts[0].shaft'), isTrue);

        final b0 = scene.objects['bolts[0]'] as ResolvedComponent;
        expect(b0.children, containsAll(['bolts[0].head', 'bolts[0].shaft']));

        // Verify parent transform propagation
        final b0Head = scene.objects['bolts[0].head'] as ResolvedCircle;
        expect(b0Head.transforms, isNotEmpty);
        expect(b0Head.transforms.first, isA<TranslateOp>());
        final tOp0 = b0Head.transforms.first as TranslateOp;
        expect(tOp0.x, equals(-40.0));
        expect(tOp0.y, equals(-15.0));

        final b1Head = scene.objects['bolts[1].head'] as ResolvedCircle;
        expect(b1Head.transforms, hasLength(2));
        expect(b1Head.transforms[0], isA<TranslateOp>());
        expect(b1Head.transforms[1], isA<RotateOp>());

        final tOp1 = b1Head.transforms[0] as TranslateOp;
        final rOp1 = b1Head.transforms[1] as RotateOp;
        expect(tOp1.x, equals(0.0));
        expect(tOp1.y, equals(-15.0));
        expect(rOp1.angle, closeTo(45.0, 0.0001));
      },
    );

    test('repeat.along uniform-length resolves positions on open path', () {
      final doc = {
        'version': 0.5,
        'scene': {'unit': 'px'},
        'objects': {
          'guide': {
            'type': 'line',
            'from': [0, 0],
            'to': [100, 0],
          },
          'marks': {
            'type': 'repeat',
            'along': {
              'target': 'guide',
              'count': 3,
              'spacing': 'uniform-length',
            },
            'item': {
              'type': 'point',
              'at': 'item.point',
            },
          },
        },
      };

      final scene = resolveGeometry(doc);
      final marks = scene.objects['marks'] as ResolvedCollection;

      expect(marks.children, hasLength(3));

      final p0 = scene.objects['marks[0]'] as ResolvedPoint;
      final p1 = scene.objects['marks[1]'] as ResolvedPoint;
      final p2 = scene.objects['marks[2]'] as ResolvedPoint;

      expect(p0.x, closeTo(0.0, 0.001));
      expect(p1.x, closeTo(50.0, 0.001));
      expect(p2.x, closeTo(100.0, 0.001));
      expect(p0.y, closeTo(0.0, 0.001));
      expect(p1.y, closeTo(0.0, 0.001));
      expect(p2.y, closeTo(0.0, 0.001));
    });

    test(
      'repeat.along fixed-distance derives count from usable length',
      () {
        final doc = {
          'version': 0.5,
          'scene': {'unit': 'px'},
          'objects': {
            'guide': {
              'type': 'line',
              'from': [0, 0],
              'to': [100, 0],
            },
            'pegs': {
              'type': 'repeat',
              'along': {
                'target': 'guide',
                'spacing': 'fixed-distance',
                'distance': 30,
              },
              'item': {
                'type': 'point',
                'at': ['item.distance', 'item.t * 100'],
              },
            },
          },
        };

        final scene = resolveGeometry(doc);
        final pegs = scene.objects['pegs'] as ResolvedCollection;

        expect(pegs.children, hasLength(4));

        final p0 = scene.objects['pegs[0]'] as ResolvedPoint;
        final p1 = scene.objects['pegs[1]'] as ResolvedPoint;
        final p2 = scene.objects['pegs[2]'] as ResolvedPoint;
        final p3 = scene.objects['pegs[3]'] as ResolvedPoint;

        expect(p0.x, closeTo(0.0, 0.001));
        expect(p1.x, closeTo(30.0, 0.001));
        expect(p2.x, closeTo(60.0, 0.001));
        expect(p3.x, closeTo(90.0, 0.001));
        expect(p3.y, closeTo(90.0, 0.001));
      },
    );

    test(
      'repeat.along fixed-distance rejects explicit count in v0.5',
      () {
        final doc = {
          'version': 0.5,
          'scene': {'unit': 'px'},
          'objects': {
            'guide': {
              'type': 'line',
              'from': [0, 0],
              'to': [100, 0],
            },
            'badRepeat': {
              'type': 'repeat',
              'along': {
                'target': 'guide',
                'spacing': 'fixed-distance',
                'distance': 20,
                'count': 5,
              },
              'item': {
                'type': 'point',
                'at': [0, 0],
              },
            },
          },
        };

        expect(
          () => resolveGeometry(doc),
          throwsA(
            predicate(
              (error) => error.toString().contains(
                'INVALID_REPEAT_ALONG_SPACING',
              ),
            ),
          ),
        );
      },
    );

    test(
      'repeat.along with on.frame item.frame resolves oriented child transforms',
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
                'on': {
                  'frame': 'item.frame',
                },
              },
            },
          },
        };

        final scene = resolveGeometry(doc);
        final slots = scene.objects['slots'] as ResolvedCollection;
        expect(slots.children, hasLength(3));

        final s0 = scene.objects['slots[0]'] as ResolvedRect;
        final s1 = scene.objects['slots[1]'] as ResolvedRect;
        final s2 = scene.objects['slots[2]'] as ResolvedRect;

        expect(s0.x, closeTo(-5.0, 0.001));
        expect(s0.y, closeTo(-2.0, 0.001));
        expect(s1.x, closeTo(-5.0, 0.001));
        expect(s1.y, closeTo(48.0, 0.001));
        expect(s2.x, closeTo(-5.0, 0.001));
        expect(s2.y, closeTo(98.0, 0.001));

        expect(s0.transforms, isNotEmpty);
        expect(s1.transforms, isNotEmpty);
        expect(s2.transforms, isNotEmpty);
        expect(s0.transforms.first, isA<RotateOp>());
        expect(s1.transforms.first, isA<RotateOp>());
        expect(s2.transforms.first, isA<RotateOp>());

        final r0 = s0.transforms.first as RotateOp;
        final r1 = s1.transforms.first as RotateOp;
        final r2 = s2.transforms.first as RotateOp;

        expect(r0.angle, closeTo(90.0, 0.001));
        expect(r1.angle, closeTo(90.0, 0.001));
        expect(r2.angle, closeTo(90.0, 0.001));
        expect(r0.origin.x, closeTo(0.0, 0.001));
        expect(r0.origin.y, closeTo(0.0, 0.001));
        expect(r1.origin.x, closeTo(0.0, 0.001));
        expect(r1.origin.y, closeTo(50.0, 0.001));
        expect(r2.origin.x, closeTo(0.0, 0.001));
        expect(r2.origin.y, closeTo(100.0, 0.001));
      },
    );

    test(
      'shared reference fixture sheet resolves from portable relative path',
      () {
        final scene = resolveGeometry(
          _loadFixture('02-mixed-presentational-sheet.yaml'),
        );

        expect(scene.views.containsKey('mixedView'), isTrue);
        expect(scene.sheets.containsKey('drawing1'), isTrue);
        expect(scene.objects.containsKey('title'), isTrue);
        expect(scene.objects.containsKey('note'), isTrue);
        expect(scene.objects.containsKey('dim'), isTrue);
      },
    );

    test('boolean scene resolves expected result objects', () {
      final doc = {
        'version': 0.4,
        'scene': {'unit': 'mm', 'autoSize': true, 'padding': 30},
        'objects': {
          'base_circle': {
            'type': 'circle',
            'radius': 40,
            'center': [50, 50],
          },
          'cutter_rect': {
            'type': 'rect',
            'size': [40, 100],
            'place': {
              'center': [50, 50],
            },
          },
          'cutter_rect2': {
            'type': 'rect',
            'size': [100, 40],
            'place': {
              'center': [50, 50],
            },
          },
          'shape_subtract': {
            'type': 'boolean',
            'operation': 'subtract',
            'base': 'base_circle',
            'tools': ['cutter_rect', 'cutter_rect2'],
            'result': {'mode': 'multi'},
            'meta': {'fill': '#ff0000'},
          },
          'circ1': {
            'type': 'circle',
            'radius': 30,
            'center': [200, 40],
          },
          'circ2': {
            'type': 'circle',
            'radius': 30,
            'center': [230, 40],
          },
          'circ3': {
            'type': 'circle',
            'radius': 30,
            'center': [215, 65],
          },
          'shape_union': {
            'type': 'boolean',
            'operation': 'union',
            'shapes': ['circ1', 'circ2', 'circ3'],
            'meta': {'fill': '#0000ff'},
          },
          'shape_intersect': {
            'type': 'boolean',
            'operation': 'intersect',
            'shapes': ['circ1', 'circ2'],
            'place': {'left': 'shape_union.right + 40', 'top': 20},
            'meta': {'fill': '#00ff00'},
          },
        },
      };

      final scene = resolveGeometry(doc);

      final subtract = scene.objects['shape_subtract'];
      final union = scene.objects['shape_union'];
      final intersect = scene.objects['shape_intersect'];

      expect(subtract, isA<ResolvedBoolean>());
      expect(union, isA<ResolvedBoolean>());
      expect(intersect, isA<ResolvedBoolean>());

      final subtractBool = subtract as ResolvedBoolean;
      final unionBool = union as ResolvedBoolean;
      final intersectBool = intersect as ResolvedBoolean;

      expect(subtractBool.points, isNotEmpty);
      expect(subtractBool.segments, isNotEmpty);
      expect(subtractBool.meta.fill, equals('#ff0000'));

      expect(unionBool.points, isNotEmpty);
      expect(unionBool.segments, isNotEmpty);
      expect(unionBool.meta.fill, equals('#0000ff'));

      expect(intersectBool.points, isNotEmpty);
      expect(intersectBool.segments, isNotEmpty);
      expect(intersectBool.meta.fill, equals('#00ff00'));
    });

    test('Derived accessing object properties (e.g. plat.center)', () {
      // Test case: derived yang mengakses properti objek (Point2D)
      // Ini test kasus dari user: derived { tengah: plat.center }
      final doc = {
        'scene': {'unit': 'mm'},
        'parameters': {'lebar': 120, 'tinggi': 80, 'lubang_r': 18},
        'derived': {
          'cx': 'lebar / 2',
          'cy': 'tinggi / 2',
          'tengah': 'plat.center',
        },
        'objects': {
          'plat': {
            'type': 'rect',
            'size': ['lebar', 'tinggi'],
          },
          'c_lubang': {
            'type': 'circle',
            'center': ['cx', 'cy'],
            'radius': 'lubang_r',
          },
        },
      };

      final scene = resolveGeometry(doc);

      // Scalar numerik normal harus tetap tersedia
      expect(scene.values['cx'], equals(60.0));
      expect(scene.values['cy'], equals(40.0));

      // Derived yang menghasilkan Point2D harus tersimpan
      final tengah = scene.values['tengah'];
      expect(tengah, isNotNull);

      // Verifikasi posisi center plat = (lebar/2, tinggi/2) = (60, 40)
      // Point2D adalah record ({x, y}), akses via reflection-like check
      final tengahStr = tengah.toString();
      expect(tengahStr, contains('60'));
      expect(tengahStr, contains('40'));

      // Objek yang menggunakan cx/cy harus resolve dengan benar
      final plat = scene.objects['plat'] as ResolvedRect;
      expect(plat.width, equals(120.0));
      expect(plat.height, equals(80.0));

      final lubang = scene.objects['c_lubang'] as ResolvedCircle;
      expect(lubang.cx, equals(60.0));
      expect(lubang.cy, equals(40.0));
      expect(lubang.radius, equals(18.0));
    });

    test('global bbox ignores technical roles and propagates scene fields', () {
      final doc = {
        'scene': {
          'unit': 'mm',
          'orientation': 'y-up',
          'origin': 'center',
          'padding': '10mm',
          'autoSize': false,
        },
        'meta': {'title': 'Test Scene'},
        'objects': {
          'finalBox': {
            'type': 'rect',
            'size': [100, 50],
            'place': {'left': 0, 'top': 0},
          },
          'constructionGuide': {
            'type': 'line',
            'from': [200, 0],
            'to': [300, 0],
            'meta': {'role': 'construction'},
          },
        },
      };

      final scene = resolveGeometry(doc);

      expect(scene.orientation, equals(Orientation.yUp));
      expect(scene.origin, equals(Origin.center));
      expect(scene.autoSize, isFalse);
      expect(scene.padding, equals(10.0));
      expect(
        scene.meta?.extra['title'] ?? scene.meta?.label ?? 'Test Scene',
        equals('Test Scene'),
      );
      expect(scene.bbox.x, equals(0.0));
      expect(scene.bbox.y, equals(0.0));
      expect(scene.bbox.width, equals(100.0));
      expect(scene.bbox.height, equals(50.0));
    });

    test(
      'dimension resolver preserves offset and resolves placeholders by kind',
      () {
        final doc = {
          'version': 0.4,
          'scene': {'unit': 'mm'},
          'objects': {
            'P1': {
              'type': 'point',
              'at': [10, 10],
            },
            'P2': {
              'type': 'point',
              'at': [40, 50],
            },
            'C1': {
              'type': 'circle',
              'center': [50, 50],
              'radius': 20,
            },
            'L1': {
              'type': 'line',
              'from': [0, 0],
              'to': [100, 0],
            },
            'L2': {
              'type': 'line',
              'from': [0, 0],
              'to': [100, 100],
            },
            'DLinear': {
              'type': 'dimension',
              'kind': 'linear',
              'from': 'P1',
              'to': 'P2',
              'offset': 15,
              'text': 'Distance: {distance}',
            },
            'DRadius': {
              'type': 'dimension',
              'kind': 'radius',
              'target': 'C1',
              'text': 'R={radius}',
            },
            'DDiameter': {
              'type': 'dimension',
              'kind': 'diameter',
              'target': 'C1',
              'text': 'Dia: {diameter}',
            },
            'DAngle': {
              'type': 'dimension',
              'kind': 'angle',
              'between': ['L1', 'L2'],
              'text': 'Angle: {angle}',
            },
          },
        };

        final scene = resolveGeometry(doc);
        final linear = scene.objects['DLinear'] as ResolvedDimension;
        final radius = scene.objects['DRadius'] as ResolvedDimension;
        final diameter = scene.objects['DDiameter'] as ResolvedDimension;
        final angle = scene.objects['DAngle'] as ResolvedDimension;

        expect(linear.offset, equals(15));
        expect(linear.distance, closeTo(50, 0.0001));
        expect(linear.text, equals('Distance: 50.0mm'));

        expect(radius.target, equals('C1'));
        expect(radius.distance, equals(20));
        expect(radius.text, equals('R=20.0mm'));

        expect(diameter.target, equals('C1'));
        expect(diameter.distance, equals(40));
        expect(diameter.text, equals('Dia: 40.0mm'));

        expect(angle.between, equals(['L1', 'L2']));
        expect(angle.angle, closeTo(45, 0.0001));
        expect(angle.text, equals('Angle: 45.0°'));
      },
    );

    test('resolves views and sheets into resolved scene', () {
      final doc = {
        'version': 0.4,
        'scene': {'unit': 'mm'},
        'objects': {
          'panel': {
            'type': 'rect',
            'size': [100, 50],
            'place': {'left': 0, 'top': 0},
          },
        },
        'views': {
          'front': {
            'target': 'panel',
            'scale': '1:2',
            'filter': {
              'roles': ['final'],
            },
          },
        },
        'sheets': {
          'drawing1': {
            'size': 'A4',
            'orientation': 'landscape',
            'views': [
              {
                'use': 'front',
                'place': {
                  'topLeft': [20, 30],
                },
              },
            ],
          },
        },
      };

      final scene = resolveGeometry(doc);

      expect(scene.views.containsKey('front'), isTrue);
      final view = scene.views['front']!;
      expect(view.scaleFactor, equals(0.5));
      expect(view.objects.containsKey('panel'), isTrue);
      expect(view.bbox.width, equals(50.0));
      expect(view.bbox.height, equals(25.0));

      expect(scene.sheets.containsKey('drawing1'), isTrue);
      final sheet = scene.sheets['drawing1']!;
      expect(sheet.width, equals(297.0));
      expect(sheet.height, equals(210.0));
      expect(sheet.views, hasLength(1));
      expect(sheet.views.first.x, equals(20.0));
      expect(sheet.views.first.y, equals(30.0));
      expect(sheet.views.first.width, equals(50.0));
      expect(sheet.views.first.height, equals(25.0));
    });
  });
}
