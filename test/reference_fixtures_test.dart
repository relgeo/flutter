import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'package:yaml/yaml.dart';

Map<dynamic, dynamic> _loadFixture(String name) {
  final file = File('../fixtures/reference/$name');
  return loadYaml(file.readAsStringSync()) as Map<dynamic, dynamic>;
}

void main() {
  test(
    'resolves text-anchor multiline fixture from shared reference folder',
    () {
      final scene = resolveGeometry(
        _loadFixture('01-text-anchor-multiline.yaml'),
      );

      final title = scene.objects['title'] as ResolvedText;
      final footer = scene.objects['footer'] as ResolvedText;

      expect(title.x, closeTo(58.4, 0.0001));
      expect(title.y, closeTo(24.0, 0.0001));
      expect(title.width, closeTo(43.2, 0.0001));
      expect(title.height, closeTo(31.2, 0.0001));

      expect(footer.x, closeTo(146.8, 0.0001));
      expect(footer.y, closeTo(88.8, 0.0001));
      expect(footer.width, closeTo(43.2, 0.0001));
      expect(footer.height, closeTo(31.2, 0.0001));
    },
  );

  test(
    'renders mixed presentational sheet fixture from shared reference folder',
    () {
      final scene = resolveGeometry(
        _loadFixture('02-mixed-presentational-sheet.yaml'),
      );
      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');

      expect(svg.contains('SHEET: drawing1'), isTrue);
      expect(svg.contains('>FACE A</tspan>'), isTrue);
      expect(svg.contains('>CHECK</tspan>'), isTrue);
      expect(
        RegExp(r'<circle cx="140\.0" cy="55\.0" r="2(?:\.0+)?"').hasMatch(svg),
        isTrue,
      );
      expect(svg.contains('>EDGE</tspan>'), isTrue);
      expect(svg.contains('>BREAK</tspan>'), isTrue);
      expect(svg.contains('transform="rotate('), isTrue);
      expect(svg.contains('>120mm</text>'), isTrue);
    },
  );

  test('renders sheet title block fixture from shared reference folder', () {
    final scene = resolveGeometry(_loadFixture('03-sheet-title-block.yaml'));
    final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');

    expect(svg.contains('SHEET: Assembly Sheet'), isTrue);
    expect(svg.contains('RELGEO: v0.5'), isTrue);
    expect(svg.contains('DATE: 2026-06-23'), isTrue);
    expect(svg.contains('SIZE: A4'), isTrue);
    expect(svg.contains('DOC VER: 1.2'), isTrue);
    expect(svg.contains('Viewport: front'), isTrue);
  });

  test(
    'renders grouped sheet rooting fixture from shared reference folder',
    () {
      final scene = resolveGeometry(
        _loadFixture('04-grouped-sheet-rooting.yaml'),
      );
      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');

      final rectMatch = RegExp(
        r'<rect\b[^>]*x="10\.0" y="20\.0" width="100\.0" height="50\.0"',
      ).allMatches(svg);
      expect(rectMatch.length, 1);
      expect(svg.contains('stroke="#ff0000"'), isTrue);
    },
  );

  test('renders clone sheet target fixture from shared reference folder', () {
    final scene = resolveGeometry(_loadFixture('05-clone-sheet-target.yaml'));
    final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');

    final rectMatch = RegExp(
      r'<rect\b[^>]*x="0\.0" y="0\.0" width="100\.0" height="50\.0"',
    ).allMatches(svg);
    expect(rectMatch.length, 1);
    expect(svg.contains('<g transform="translate(200.0, 0.0)">'), isTrue);
    expect(svg.contains('stroke="#00aa88"'), isTrue);
  });

  test(
    'renders nested structural sheet fixture from shared reference folder',
    () {
      final scene = resolveGeometry(
        _loadFixture('06-nested-structural-sheet.yaml'),
      );
      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');

      final rectMatch = RegExp(
        r'<rect\b[^>]*x="30\.0" y="20\.0" width="90\.0" height="40\.0"',
      ).allMatches(svg);
      expect(rectMatch.length, 1);
      expect(
        svg.contains('<line x1="90.0" y1="50.0" x2="145.0" y2="70.0"'),
        isTrue,
      );
      expect(
        RegExp(r'<circle cx="90\.0" cy="50\.0" r="2(?:\.0+)?"').hasMatch(svg),
        isTrue,
      );
      expect(svg.contains('<tspan x="149.0" dy="0">FACE B</tspan>'), isTrue);
    },
  );

  test(
    'renders component sheet meta override fixture from shared reference folder',
    () {
      final scene = resolveGeometry(
        _loadFixture('07-component-sheet-meta-override.yaml'),
      );
      final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');

      expect(svg.contains('stroke="#2244ff"'), isTrue);
      expect(
        RegExp(
          r'<rect\b[^>]*x="40\.0" y="15\.0" width="80\.0" height="30\.0"',
        ).hasMatch(svg),
        isTrue,
      );
    },
  );

  test('renders sheet xml escaping fixture from shared reference folder', () {
    final scene = resolveGeometry(_loadFixture('08-sheet-xml-escaping.yaml'));
    final svg = SvgExporter.generateSVG(scene, sheetId: 'drawing1');

    expect(svg.contains('A&amp;B &lt;main&gt;'), isTrue);
    expect(svg.contains('SHEET: Assembly &lt;A&amp;B&gt;'), isTrue);
    expect(svg.contains('RELGEO: v0.5'), isTrue);
    expect(svg.contains('DOC VER: 1&lt;2&amp;3&gt;'), isTrue);
    expect(svg.contains('front&amp;detail (Scale 1&lt;2)'), isTrue);
  });

  test('renders multi-sheet title block fixture from shared reference folder', () {
    final scene = resolveGeometry(_loadFixture('09-multi-sheet-title-block.yaml'));
    final sheetA = SvgExporter.generateSVG(scene, sheetId: 'sheetA');
    final sheetB = SvgExporter.generateSVG(scene, sheetId: 'sheetB');

    expect(sheetA.contains('SHEET: Bracket Assembly Sheet'), isTrue);
    expect(sheetA.contains('DATE: 2026-07-13'), isTrue);
    expect(sheetA.contains('DOC VER: BRKT-2026.07'), isTrue);
    expect(sheetA.contains('SIZE: A4 Landscape'), isTrue);
    expect(sheetA.contains('Viewport: front'), isTrue);

    expect(sheetB.contains('SHEET: Bracket Detail Sheet'), isTrue);
    expect(sheetB.contains('DATE: 2026-07-14'), isTrue);
    expect(sheetB.contains('DOC VER: BRKT-DET-02'), isTrue);
    expect(sheetB.contains('SIZE: A4 Detail'), isTrue);
    expect(sheetB.contains('Viewport: detail'), isTrue);
    expect(
      sheetB.contains(
        '<g transform="translate(40.0, 45.0) scale(2.0) translate(-0.0, -0.0)">',
      ),
      isTrue,
    );
  });
}
