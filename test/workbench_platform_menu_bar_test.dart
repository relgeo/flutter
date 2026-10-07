import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_commands.dart';
import 'package:relgeo_flutter/src/ui/workbench_platform_menu_bar.dart';

void main() {
  testWidgets(
    'macOS reserves its app menu before File',
    (tester) async {
      final registry = WorkbenchCommandRegistry([
        WorkbenchCommand(
          id: WorkbenchCommandId.openDocument,
          menu: 'File',
          label: 'Open document…',
          onInvoke: () {},
        ),
        WorkbenchCommand(
          id: WorkbenchCommandId.quitApplication,
          menu: 'File',
          label: 'Quit RelGeo',
          onInvoke: () {},
        ),
        WorkbenchCommand(
          id: WorkbenchCommandId.aboutRelGeo,
          menu: 'Help',
          label: 'About RelGeo',
          onInvoke: () {},
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchPlatformMenuBar(
            registry: registry,
            child: const SizedBox(),
          ),
        ),
      );

      final platformMenuBar = tester.widget<PlatformMenuBar>(
        find.byType(PlatformMenuBar),
      );
      expect(
        platformMenuBar.menus.map((menu) => menu.label),
        containsAllInOrder(<String>[
          'RelGeo',
          ...WorkbenchCommandRegistry.menuOrder,
        ]),
      );
      final applicationMenu = platformMenuBar.menus.first as PlatformMenu;
      expect(
        applicationMenu.menus.whereType<PlatformMenuItem>().map(
          (item) => item.label,
        ),
        containsAllInOrder(<String>['About RelGeo', 'Quit RelGeo']),
      );
      final fileMenu = platformMenuBar.menus[1] as PlatformMenu;
      expect(
        fileMenu.menus.whereType<PlatformMenuItem>().map((item) => item.label),
        contains('Open document…'),
      );
      expect(
        fileMenu.menus.whereType<PlatformMenuItem>().map((item) => item.label),
        isNot(contains('Quit RelGeo')),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

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
        id: WorkbenchCommandId.copySource,
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

  testWidgets('file and document shortcuts dispatch through the registry', (
    tester,
  ) async {
    final invoked = <WorkbenchCommandId>[];
    final registry = WorkbenchCommandRegistry([
      for (final entry in <(WorkbenchCommandId, LogicalKeyboardKey)>[
        (WorkbenchCommandId.newDocument, LogicalKeyboardKey.keyN),
        (WorkbenchCommandId.openDocument, LogicalKeyboardKey.keyO),
        (WorkbenchCommandId.saveDocument, LogicalKeyboardKey.keyS),
      ])
        WorkbenchCommand(
          id: entry.$1,
          menu: 'File',
          label: entry.$1.name,
          shortcut: SingleActivator(entry.$2, control: true),
          shortcutActivator: SingleActivator(entry.$2, control: true),
          onInvoke: () => invoked.add(entry.$1),
        ),
      WorkbenchCommand(
        id: WorkbenchCommandId.recompileDocument,
        menu: 'Document',
        label: 'Recompile document',
        shortcut: const SingleActivator(LogicalKeyboardKey.f5),
        shortcutActivator: const SingleActivator(LogicalKeyboardKey.f5),
        onInvoke: () => invoked.add(WorkbenchCommandId.recompileDocument),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchCommandSurface(
          registry: registry,
          child: const Focus(
            autofocus: true,
            child: SizedBox(key: Key('file-shortcut-surface')),
          ),
        ),
      ),
    );

    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.keyN,
      LogicalKeyboardKey.keyO,
      LogicalKeyboardKey.keyS,
    ]) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);

    expect(invoked, const [
      WorkbenchCommandId.newDocument,
      WorkbenchCommandId.openDocument,
      WorkbenchCommandId.saveDocument,
      WorkbenchCommandId.recompileDocument,
    ]);
  });
}
