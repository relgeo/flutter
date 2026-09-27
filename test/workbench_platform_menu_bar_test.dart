import 'package:flutter/material.dart';
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
}
