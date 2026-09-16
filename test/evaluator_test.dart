import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

void main() {
  group('RelGeo Evaluator & Unit System Port Test Suite', () {
    test('Kalkulasi Aritmatika Dasar', () {
      final context = SimpleEvalContext(scalars: {});
      final evaluator = Evaluator(context);

      expect(evaluator.evaluate('2 + 3 * 4'), 14.0);
      expect(evaluator.evaluate('(2 + 3) * 4'), 20.0);
      expect(evaluator.evaluate('10 / 2 - 1'), 4.0);
      expect(evaluator.evaluate('2 ^ 3'), 8.0);
      expect(evaluator.evaluate('-5 + 10'), 5.0);
    });

    test('Evaluasi Variabel Dinamik (Scalars)', () {
      final context = SimpleEvalContext(
        scalars: {'lebar': 120.0, 'tinggi': 80.0, 'skala': 0.5},
      );
      final evaluator = Evaluator(context);

      expect(evaluator.evaluate('lebar * skala'), 60.0);
      expect(evaluator.evaluate('tinggi / 2 + lebar'), 160.0);
      expect(evaluator.evaluate('lebar - tinggi * skala'), 80.0);
    });

    test('Fungsi Matematika Standard', () {
      final context = SimpleEvalContext(scalars: {});
      final evaluator = Evaluator(context);

      expect(evaluator.evaluate('min(15, 5, 20)'), 5.0);
      expect(evaluator.evaluate('max(15, 5, 20)'), 20.0);
      expect(evaluator.evaluate('abs(-42)'), 42.0);
      expect(evaluator.evaluate('clamp(10, 0, 5)'), 5.0);
      expect(evaluator.evaluate('cos(0)'), 1.0);
      expect(evaluator.evaluate('sin(0)'), 0.0);
    });

    test('Sistem Normalisasi Unit Ukuran (units.dart)', () {
      // 96px = 25.4mm
      // 1mm = 96/25.4 = 3.779527559px
      final mmInPx = convertToPx('10mm');
      expect(mmInPx, closeTo(37.79527559, 1e-5));

      final cmInPx = convertToPx('5cm');
      expect(cmInPx, closeTo(188.97637795, 1e-5));

      final inchInPx = convertToPx('1in');
      expect(inchInPx, closeTo(96.0, 1e-5));

      final context = SimpleEvalContext(scalars: {}, targetUnit: LengthUnit.mm);
      final evaluator = Evaluator(context);

      // Evaluasi "10mm + 2cm" dalam targetUnit: mm
      // 2cm = 20mm, total = 30mm
      final result = evaluator.evaluate('10mm + 2cm');
      expect(result, closeTo(30.0, 1e-5));

      final inchContext = SimpleEvalContext(
        scalars: {},
        targetUnit: LengthUnit.ip,
      );
      final inchResult = Evaluator(inchContext).evaluate('2in + 25.4mm');
      expect(inchResult, closeTo(3.0, 1e-5));

      expect(normalizeUnit('guide', LengthUnit.mm), equals('guide'));
      expect(normalizeUnit('12xyz', LengthUnit.mm), equals('12xyz'));
    });

    test('Evaluasi Operator Logika & Ternary', () {
      final context = SimpleEvalContext(
        scalars: {'lebar': 100.0, 'tinggi': 50.0},
      );
      final evaluator = Evaluator(context);

      expect(evaluator.evaluate('lebar > tinggi ? 99 : 11'), 99.0);
      expect(evaluator.evaluate('lebar == tinggi ? 99 : 11'), 11.0);
      expect(evaluator.evaluate('lebar > 50 && tinggi < 100'), true);
      expect(evaluator.evaluate('lebar < 50 || tinggi == 50'), true);
    });

    test('Fungsi v0.5 geometry dan string minimum', () {
      final context = SimpleEvalContext(
        scalars: {'prefix': 'A', 'count': 5.0, 'localPt': (x: 2.0, y: 3.0)},
        objects: {
          'A': ResolvedPoint(id: 'A', meta: Meta(), x: 0, y: 0),
          'B': ResolvedPoint(id: 'B', meta: Meta(), x: 10, y: 10),
          'centerPt': ResolvedPoint(id: 'centerPt', meta: Meta(), x: 5, y: 5),
          'mirrorCenter': ResolvedPoint(
            id: 'mirrorCenter',
            meta: Meta(),
            x: 4,
            y: 1,
          ),
          'guideLine': ResolvedLine(
            id: 'guideLine',
            meta: Meta(),
            x1: 0,
            y1: 0,
            x2: 10,
            y2: 0,
          ),
          'rect1': ResolvedRect(
            id: 'rect1',
            meta: Meta(),
            x: 10,
            y: 20,
            width: 30,
            height: 40,
          ),
          'ellipse1': ResolvedEllipse(
            id: 'ellipse1',
            meta: Meta(),
            cx: 20,
            cy: 30,
            rx: 10,
            ry: 5,
            rotation: 0,
          ),
          'closedPath': ResolvedPath(
            id: 'closedPath',
            meta: Meta(),
            points: const [
              (x: 0.0, y: 0.0),
              (x: 10.0, y: 0.0),
              (x: 10.0, y: 10.0),
              (x: 0.0, y: 10.0),
            ],
            segments: const [],
            closed: true,
          ),
        },
      );
      final evaluator = Evaluator(context);

      expect(evaluator.evaluate('midpoint(A, B)'), (x: 5.0, y: 5.0));
      expect(evaluator.evaluate('polar(centerPt, 10, 0)'), (x: 15.0, y: 5.0));
      expect(
        evaluator.evaluate('angleBetween(A, B)'),
        closeTo(0.78539816339, 1e-6),
      );
      expect(evaluator.evaluate('bbox(rect1)'), {
        'minX': 10.0,
        'maxX': 40.0,
        'minY': 20.0,
        'maxY': 60.0,
        'width': 30.0,
        'height': 40.0,
      });
      expect(evaluator.evaluate('bbox(rect1).width'), 30.0);
      expect(evaluator.evaluate('bbox(rect1).minX'), 10.0);
      expect(evaluator.evaluate('width(rect1)'), 30.0);
      expect(evaluator.evaluate('height(rect1)'), 40.0);
      expect(evaluator.evaluate('minX(rect1)'), 10.0);
      expect(evaluator.evaluate('maxX(rect1)'), 40.0);
      expect(evaluator.evaluate('minY(rect1)'), 20.0);
      expect(evaluator.evaluate('maxY(rect1)'), 60.0);
      expect(evaluator.evaluate('project(localPt, guideLine)'), (
        x: 2.0,
        y: 0.0,
      ));
      expect(evaluator.evaluate('reflect(localPt, mirrorCenter)'), (
        x: 6.0,
        y: -1.0,
      ));
      expect(evaluator.evaluate('reflect(localPt, guideLine)'), (
        x: 2.0,
        y: -3.0,
      ));
      expect(evaluator.evaluate('perimeter(closedPath)'), 40.0);
      expect(
        evaluator.evaluate('concat("Part-", prefix, "-", count)'),
        'Part-A-5.0',
      );
      expect(evaluator.evaluate('charAt("Hello", 1)'), 'e');
      expect(evaluator.evaluate('format("ID: {0}", prefix)'), 'ID: A');
    });
  });
}
