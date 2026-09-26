import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_icon_button.dart';

void main() {
  testWidgets('icon button preserves tooltip, key, and activation', (
    WidgetTester tester,
  ) async {
    var activationCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchIconButton(
            Icons.refresh,
            'Reset',
            () => activationCount++,
            buttonKey: const Key('reset-button'),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('reset-button')), findsOneWidget);
    expect(find.byTooltip('Reset'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset-button')));
    expect(activationCount, 1);
  });
}
