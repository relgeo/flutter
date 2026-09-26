import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/features/editor/workbench_document_settings.dart';
import 'package:relgeo_flutter/src/geometry/types.dart';

void main() {
  test('parses profiles, parameter defaults, overrides, and scene unit', () {
    final settings = WorkbenchDocumentSettings.fromDocument(
      {
        'profiles': {
          'wide': {'width': 80, 'unknown': 12},
        },
        'parameters': {
          'width': {'default': 40},
          'height': 20,
        },
        'scene': {'unit': 'cm'},
      },
      existingParamOverrides: const {'width': 55, 'stale': 99},
      currentTargetUnit: LengthUnit.mm,
    );

    expect(settings.profiles.keys, contains('wide'));
    expect(settings.paramValues, {'width': 40, 'height': 20});
    expect(settings.paramOverrides, {'width': 55, 'height': 20});
    expect(settings.targetUnit, LengthUnit.cm);
  });

  test('profile updates only known parameters and converts numeric values', () {
    final settings = WorkbenchDocumentSettings(
      profiles: {
        'wide': {'width': 80, 'unknown': 12},
      },
      paramValues: const {'width': 40, 'height': 20},
      paramOverrides: const {'width': 55, 'height': 20},
      targetUnit: LengthUnit.mm,
    );

    expect(settings.overridesForProfile('wide'), {'width': 80.0, 'height': 20});
  });

  test('clearing an unknown or null profile clears overrides', () {
    final settings = WorkbenchDocumentSettings(
      profiles: const {},
      paramValues: const {'width': 40},
      paramOverrides: const {'width': 55},
      targetUnit: LengthUnit.mm,
    );

    expect(settings.overridesForProfile(null), isEmpty);
    expect(settings.overridesForProfile('missing'), isEmpty);
  });
}
