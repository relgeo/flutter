import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'package:relgeo_flutter/src/ui/render_style.dart';

void main() {
  test(
    'resolvedStrokeWidth keeps visible default stroke for stroked objects without explicit strokeWidth',
    () {
      final meta = Meta(role: 'final', stroke: '#0f172a');

      expect(
        RenderStyle.resolvedStrokeWidth(meta),
        RenderStyle.defaultVisibleStrokeWidth,
      );
    },
  );

  test('resolvedStrokeWidth keeps explicit strokeWidth authoritative', () {
    final meta = Meta(role: 'final', stroke: '#0f172a', strokeWidth: 2.5);

    expect(RenderStyle.resolvedStrokeWidth(meta), 2.5);
  });

  test('paintForMeta can use workbench role fallback color override', () {
    final meta = Meta(role: 'final');
    final paint = RenderStyle.paintForMeta(
      meta,
      isFill: false,
      fallbackRoleColor: const Color(0xFF123456),
    );

    expect(paint.color.value, const Color(0xFF123456).value);
  });

  test(
    'svg exporter keeps visible default stroke for stroked meter-scale objects without explicit strokeWidth',
    () {
      final scene = ResolvedScene(
        unit: LengthUnit.m,
        objects: {
          'frame': ResolvedRect(
            id: 'frame',
            meta: Meta(stroke: '#0f172a'),
            x: 0,
            y: 0,
            width: 8,
            height: 5,
          ),
        },
        parameters: const {},
        values: const {},
        bbox: const BoundingBox(x: 0, y: 0, width: 8, height: 5),
      );

      final svg = SvgExporter.generateSVG(scene);
      expect(svg.contains('stroke="#0f172a"'), isTrue);
      expect(svg.contains('stroke-width="0.5"'), isTrue);
    },
  );
}
