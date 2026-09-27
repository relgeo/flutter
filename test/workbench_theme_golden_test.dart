import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/main.dart';
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
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAllTestValues();
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('workbench shell ${brightness.name} theme golden', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          brightness;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const RelGeoCADApp(initialDsl: _goldenDsl, showInWindowMenu: true),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/workbench_shell_${brightness.name}.png'),
      );
    });
  }
}
