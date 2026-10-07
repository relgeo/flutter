import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'package:relgeo_flutter/src/features/inspector/inspector_panel.dart';
import 'package:relgeo_flutter/src/ui/app_theme.dart';
import 'package:relgeo_flutter/src/ui/relgeo_theme_extension.dart';
import 'package:relgeo_flutter/src/ui/workbench_visual_profile.dart';

void main() {
  testWidgets('inspector primary labels follow light and dark app themes', (
    WidgetTester tester,
  ) async {
    final profile = WorkbenchVisualProfile.cad;
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: {
        'ellipse1': ResolvedEllipse(
          id: 'ellipse1',
          meta: Meta(role: 'final'),
          cx: 50,
          cy: 40,
          rx: 20,
          ry: 10,
          rotation: 0,
        ),
      },
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 30, y: 30, width: 40, height: 20),
    );

    for (final theme in [
      buildRelGeoLightTheme(profile: profile),
      buildRelGeoDarkTheme(profile: profile),
    ]) {
      final themedProfile = profile.withChromeTheme(theme.colorScheme);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 720,
              child: InspectorPanel(
                scene: scene,
                yamlError: null,
                compilerError: null,
                targetUnit: 'mm',
                visualProfile: themedProfile,
                themeTokens: theme.extension<RelGeoThemeExtension>(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final objectLabel = tester.widget<Text>(find.text('ellipse1'));
      expect(objectLabel.style?.color, theme.colorScheme.onSurface);
    }
  });

  testWidgets('inspector panel shows ellipse geometry details', (
    WidgetTester tester,
  ) async {
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: {
        'ellipse1': ResolvedEllipse(
          id: 'ellipse1',
          meta: Meta(role: 'final'),
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 720,
            child: InspectorPanel(
              scene: scene,
              yamlError: null,
              compilerError: null,
              targetUnit: 'mm',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ellipse1'), findsOneWidget);
    expect(find.text('ELLIPSE'), findsOneWidget);

    await tester.tap(find.text('ellipse1'));
    await tester.pumpAndSettle();

    expect(find.text('Radii'), findsOneWidget);
    expect(find.text('20.00 × 10.00 mm'), findsOneWidget);
    expect(find.text('Rotation'), findsOneWidget);
    expect(find.text('30.0°'), findsOneWidget);
    expect(find.text('Area'), findsOneWidget);
    expect(find.text('628.3 mm²'), findsOneWidget);
    expect(find.text('Perimeter'), findsOneWidget);
  });

  testWidgets('inspector object headers expose expansion semantics', (
    WidgetTester tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: {
        'ellipse1': ResolvedEllipse(
          id: 'ellipse1',
          meta: Meta(role: 'final'),
          cx: 50,
          cy: 40,
          rx: 20,
          ry: 10,
          rotation: 0,
        ),
      },
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 30, y: 30, width: 40, height: 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 720,
            child: InspectorPanel(
              scene: scene,
              yamlError: null,
              compilerError: null,
              targetUnit: 'mm',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final object = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Object ellipse1',
      ),
    );
    expect(object.value, 'ELLIPSE');
    expect(object.hint, 'Expand object details');
    expect(object.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    semanticsHandle.dispose();
  });

  testWidgets('inspector BOM tab includes ellipse profile summary', (
    WidgetTester tester,
  ) async {
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: {
        'ellipse1': ResolvedEllipse(
          id: 'ellipse1',
          meta: Meta(role: 'final'),
          cx: 50,
          cy: 40,
          rx: 20,
          ry: 10,
          rotation: 0,
        ),
      },
      parameters: const {},
      values: const {},
      bbox: const BoundingBox(x: 30, y: 30, width: 40, height: 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 720,
            child: InspectorPanel(
              scene: scene,
              yamlError: null,
              compilerError: null,
              targetUnit: 'mm',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BOM'));
    await tester.pumpAndSettle();

    expect(find.text('Ellipse (20×10)'), findsOneWidget);
    expect(find.text('1'), findsAtLeastNWidgets(1));
    expect(find.text('628.3 mm²'), findsOneWidget);
    expect(find.textContaining('Area: 628.3 mm²'), findsOneWidget);
  });
}
