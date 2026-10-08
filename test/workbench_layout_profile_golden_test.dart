@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/main.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _goldenDsl = '''scene:
  unit: mm
  padding: 20

objects:
  panel:
    type: rect
    size: [120, 80]
    meta:
      role: final

  center_axis:
    type: line
    start: [60, -10]
    end: [60, 90]
    meta:
      role: centerline

views:
  front:
    target: panel
    scale: "1:1"
    filter:
      roles: [final, centerline]

sheets:
  sheet_a4:
    size: A4
    orientation: landscape
    views:
      - use: front
        place:
          topLeft: [20, 20]
''';

void main() {
  const profiles = <String, String>{
    'standard': 'Standard',
    'writing': 'Writing',
    'preview': 'Preview',
    'inspect': 'Inspect',
    'minimal': 'Minimal',
  };

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAllTestValues();
  });

  for (final entry in profiles.entries) {
    testWidgets('workbench ${entry.key} layout golden', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const RelGeoCADApp(initialDsl: _goldenDsl, showInWindowMenu: true),
      );
      await tester.pumpAndSettle();

      if (entry.key != 'standard') {
        await tester.tap(find.text('Workbench'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.value));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      final profile = WorkbenchLayoutProfiles.byId(entry.key)!;
      for (final id in [
        WorkbenchPanelId.editor,
        WorkbenchPanelId.preview,
        WorkbenchPanelId.inspector,
      ]) {
        final expectedVisibility = profile.layout.panels[id]!.visibility;
        expect(
          find.byKey(ValueKey('workbench-panel-${id.name}')),
          expectedVisibility == WorkbenchPanelVisibility.visible
              ? findsOneWidget
              : findsNothing,
          reason: '${entry.key} should render ${id.name} exactly as configured',
        );
      }
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/workbench_layout_${entry.key}.png'),
      );
    });
  }
}
