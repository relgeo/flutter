import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_commands.dart';
import 'package:relgeo_flutter/src/ui/workbench_platform_menu_bar.dart';

void main() {
  testWidgets('platform menu adapter preserves its child and platform policy', (
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
        home: WorkbenchPlatformMenuBar(
          registry: registry,
          child: const SizedBox(key: Key('platform-menu-child')),
        ),
      ),
    );

    expect(find.byKey(const Key('platform-menu-child')), findsOneWidget);
    expect(registry.find(WorkbenchCommandId.fitViewport), isNotNull);
    registry.find(WorkbenchCommandId.fitViewport)!.invoke();
    expect(invoked, isTrue);

    if (WorkbenchPlatformMenuBar.usesNativeMenu) {
      expect(find.byType(PlatformMenuBar), findsOneWidget);
    } else {
      expect(find.byType(PlatformMenuBar), findsNothing);
    }
  });

  testWidgets(
    'command surface invokes the same callback from a global shortcut',
    (tester) async {
      var invoked = false;
      final registry = WorkbenchCommandRegistry([
        WorkbenchCommand(
          id: WorkbenchCommandId.copySource,
          menu: 'Edit',
          label: 'Copy source',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.keyC,
            control: true,
          ),
          shortcutActivator: const SingleActivator(
            LogicalKeyboardKey.keyC,
            control: true,
          ),
          onInvoke: () => invoked = true,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchCommandSurface(
            registry: registry,
            child: const Focus(
              autofocus: true,
              child: SizedBox(key: Key('shortcut-surface')),
            ),
          ),
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(invoked, isTrue);
    },
  );

  testWidgets('disabled command remains inert through the global shortcut', (
    tester,
  ) async {
    var invoked = false;
    final registry = WorkbenchCommandRegistry([
      WorkbenchCommand(
        id: WorkbenchCommandId.exportSvg,
        menu: 'File',
        label: 'Export SVG',
        enabled: false,
        shortcut: const SingleActivator(LogicalKeyboardKey.keyE, control: true),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.keyE,
          control: true,
        ),
        onInvoke: () => invoked = true,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchCommandSurface(
          registry: registry,
          child: const Focus(
            autofocus: true,
            child: SizedBox(key: Key('disabled-shortcut-surface')),
          ),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(invoked, isFalse);
  });
}
