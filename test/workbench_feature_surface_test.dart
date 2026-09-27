import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:relgeo_flutter/src/features/editor/workbench_editor_feature.dart';
import 'package:relgeo_flutter/src/features/editor/workbench_editor_contract.dart';
import 'package:relgeo_flutter/src/features/inspector/workbench_inspector_feature.dart';
import 'package:relgeo_flutter/src/features/inspector/workbench_inspector_contract.dart';
import 'package:relgeo_flutter/src/features/parameters/workbench_parameters_contract.dart';
import 'package:relgeo_flutter/src/features/parameters/workbench_parameters_feature.dart';
import 'package:relgeo_flutter/src/ui/workbench_visual_profile.dart';

void main() {
  testWidgets('editor feature forwards its contract to the editor panel', (
    tester,
  ) async {
    final controller = CodeLineEditingController.fromText('scene: {}');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 400,
          child: WorkbenchEditorFeature(
            contract: WorkbenchEditorContract(
              controller: controller,
              visualProfile: WorkbenchVisualProfile.cad,
            ),
          ),
        ),
      ),
    );

    expect(find.text('DSL EDITOR'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('inspector feature forwards scene and diagnostics contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 400,
          child: WorkbenchInspectorFeature(
            contract: WorkbenchInspectorContract(
              scene: null,
              yamlError: null,
              compilerError: 'compile error',
              targetUnit: 'mm',
              visualProfile: WorkbenchVisualProfile.cad,
              themeTokens: null,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ERRORS'));
    await tester.pumpAndSettle();
    expect(find.text('compile error'), findsOneWidget);
  });

  testWidgets('parameters feature is independently renderable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: WorkbenchParametersFeature(
              contract: WorkbenchParametersContract(
                paramValues: const {'width': 40},
                paramOverrides: const {'width': 20.0},
                targetUnit: 'mm',
                onParamChanged: (_, _) {},
                onParamReset: () {},
                visualProfile: WorkbenchVisualProfile.cad,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('PARAMETERS (1)'), findsOneWidget);
    expect(find.text('width'), findsOneWidget);
  });

  testWidgets('parameters feature exposes semantic reset and slider controls', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: WorkbenchParametersFeature(
              contract: WorkbenchParametersContract(
                paramValues: const {'width': 40},
                paramOverrides: const {'width': 20.0},
                targetUnit: 'mm',
                onParamChanged: (_, _) {},
                onParamReset: () {},
                visualProfile: WorkbenchVisualProfile.cad,
              ),
            ),
          ),
        ),
      ),
    );

    final reset = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Reset parameter overrides',
      ),
    );
    expect(reset.hint, 'Restore default parameter values');
    expect(reset.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);

    final slider = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'width parameter',
      ),
    );
    expect(slider.value, '20.0 mm');
    expect(slider.hint, 'Adjust width');
    final sliderControl = tester.getSemantics(find.byType(Slider));
    expect(
      sliderControl.getSemanticsData().hasAction(ui.SemanticsAction.increase),
      isTrue,
    );
    semanticsHandle.dispose();
  });
}
