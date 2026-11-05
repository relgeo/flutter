import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/geometry/types.dart';
import 'package:relgeo_flutter/src/features/preview/workbench_preview_target.dart';
import 'package:relgeo_flutter/src/ui/workbench_document_controller.dart';
import 'package:relgeo_flutter/src/features/editor/workbench_document_settings.dart';

void main() {
  test('document controller protects mutable maps from external mutation', () {
    final values = {'width': 10.0};
    final overrides = {'width': 12.0};
    final profiles = {
      'default': <String, dynamic>{'width': 10.0},
    };
    final controller = WorkbenchDocumentController();
    addTearDown(controller.dispose);

    controller.setParameters(values: values, overrides: overrides);
    controller.setProfiles(profiles);
    values['width'] = 20.0;
    overrides['width'] = 30.0;
    profiles['default']!['width'] = 40.0;

    expect(controller.paramValues['width'], 10.0);
    expect(controller.paramOverrides['width'], 12.0);
    expect(controller.profiles['default']!['width'], 10.0);
  });

  test('compile diagnostics and selected document state are explicit', () {
    final controller = WorkbenchDocumentController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.beginCompile();
    controller.setYamlError('invalid yaml');
    controller.setCompilerError('invalid geometry');
    controller.setSelectedSheetId('sheet-a');
    controller.setTargetUnit(LengthUnit.cm);
    controller.setActiveProfile('default');

    expect(controller.yamlError, 'invalid yaml');
    expect(controller.compilerError, 'invalid geometry');
    expect(controller.selectedSheetId, 'sheet-a');
    expect(controller.targetUnit, LengthUnit.cm);
    expect(controller.activeProfile, 'default');
    expect(notifications, greaterThan(0));
  });

  test('removing a profile clears an active profile reference', () {
    final controller = WorkbenchDocumentController();
    addTearDown(controller.dispose);

    controller.setProfiles({'default': <String, dynamic>{}});
    controller.setActiveProfile('default');
    controller.setProfiles(const {});

    expect(controller.activeProfile, isNull);
  });

  test('parameter overrides stay numeric and ignore unknown fields', () {
    final controller = WorkbenchDocumentController();
    addTearDown(controller.dispose);

    controller.setParameters(
      values: const {'width': 40},
      overrides: const {'width': 40},
      specs: const {
        'width': WorkbenchParameterSpec(id: 'width', type: 'length'),
      },
    );
    controller.setParamOverride('width', 55);
    controller.setParamOverride('missing', 99);

    expect(controller.paramOverrides, {'width': 55.0});
    expect(controller.parameterSpecs['width']?.type, 'length');
  });

  test(
    'parameter overrides preserve state when values are outside the bounds',
    () {
      final controller = WorkbenchDocumentController();
      addTearDown(controller.dispose);

      controller.setParameters(
        values: const {'width': 40},
        overrides: const {
          'width': 100,
          'unknown': 20,
        },
        specs: const {
          'width': WorkbenchParameterSpec(
            id: 'width',
            type: 'length',
            min: 10,
            max: 80,
          ),
        },
      );

      expect(controller.paramOverrides, isEmpty);

      controller.setParamOverride('width', 55);
      expect(controller.paramOverrides, {'width': 55.0});

      controller.setParamOverride('width', 9);
      controller.setParamOverride('width', 81);
      controller.setParamOverride('width', double.nan);
      controller.setParamOverride('width', double.infinity);
      controller.setParamOverride('missing', 20);

      expect(controller.paramOverrides, {'width': 55.0});
    },
  );

  test(
    'preview target identifies model, sheet, and reserved component targets',
    () {
      final controller = WorkbenchDocumentController();
      addTearDown(controller.dispose);

      const model = WorkbenchPreviewTarget.model();
      controller.setPreviewTarget(model);
      expect(controller.previewTarget, model);
      expect(controller.selectedSheetId, isNull);

      const sheet = WorkbenchPreviewTarget.sheet('sheet-a4');
      controller.setPreviewTarget(sheet);
      expect(controller.previewTarget, sheet);
      expect(controller.selectedSheetId, 'sheet-a4');
      expect(sheet.label, 'Sheet/View: sheet-a4');

      const component = WorkbenchPreviewTarget.component('gear');
      controller.setPreviewTarget(component);
      expect(controller.previewTarget, component);
      expect(controller.selectedSheetId, isNull);
      expect(component.label, 'Component: gear');
    },
  );
}
