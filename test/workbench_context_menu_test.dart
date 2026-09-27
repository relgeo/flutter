import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_commands.dart';
import 'package:relgeo_flutter/src/ui/workbench_context_menu.dart';

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
    await tester.tap(
      find.widgetWithText(MenuItemButton, 'Fit viewport'),
    );
    await tester.pumpAndSettle();
    expect(invoked, isTrue);
  });
}
