import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/main.dart';
import 'package:relgeo_flutter/src/features/editor/editor_panel.dart';
import 'package:relgeo_flutter/src/ui/workbench_commands.dart';
import 'package:relgeo_flutter/src/ui/workbench_context_menu.dart';

const _editorDsl = '''scene:
  unit: mm

objects:
  panel:
    type: rect
    size: [120, 80]
''';

void main() {
  testWidgets('context menu invokes the same registry command', (
    WidgetTester tester,
  ) async {
    var invoked = false;
    final registry = WorkbenchCommandRegistry([
      WorkbenchCommand(
        id: WorkbenchCommandId.fitViewport,
        menu: 'View',
        label: 'Fit viewport',
        onInvoke: () => invoked = true,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: WorkbenchCommandContextMenu(
            registry: registry,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      const Offset(100, 100),
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Fit viewport'), findsOneWidget);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Fit viewport'));
    await tester.pumpAndSettle();
    expect(invoked, isTrue);
  });

  testWidgets('workbench editor exposes registry context commands', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RelGeoCADApp(initialDsl: _editorDsl));
    await tester.pump(const Duration(seconds: 1));

    final editor = tester.widget<EditorPanel>(find.byType(EditorPanel));
    final editorCenter = tester.getCenter(find.byType(EditorPanel));
    editor.controller.text = '${editor.controller.text}\n# edit';
    await tester.pump();

    final gesture = await tester.startGesture(
      editorCenter,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.widgetWithText(MenuItemButton, 'Undo'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Redo'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Copy source'), findsOneWidget);
    expect(
      find.widgetWithText(MenuItemButton, 'Recompile document'),
      findsOneWidget,
    );
  });
}
