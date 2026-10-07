import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_icon_button.dart';

void main() {
  testWidgets('default icon color follows the active application theme', (
    WidgetTester tester,
  ) async {
    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Theme(
              data: theme,
              child: WorkbenchIconButton(Icons.zoom_in, 'Zoom in', () {}),
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.zoom_in));
      final inheritedTheme = Theme.of(
        tester.element(find.byType(WorkbenchIconButton)),
      );
      expect(inheritedTheme.brightness, theme.brightness);
      expect(icon.color, inheritedTheme.colorScheme.onSurface);
    }
  });
}
