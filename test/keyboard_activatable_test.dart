import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/keyboard_activatable.dart';

void main() {
  testWidgets(
    'keyboard activatable exposes focus feedback and activate shortcuts',
    (WidgetTester tester) async {
      var activationCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkbenchKeyboardActivatable(
              focusColor: Colors.deepOrange,
              onActivate: () => activationCount++,
              child: const Text('Activate me'),
            ),
          ),
        ),
      );

      final decoration = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      expect((decoration.decoration as BoxDecoration).border, isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final focusedDecoration = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      expect((focusedDecoration.decoration as BoxDecoration).border, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(activationCount, 2);
    },
  );

  testWidgets('multiple controls can be traversed in document order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (var index = 0; index < 3; index++)
                WorkbenchKeyboardActivatable(
                  onActivate: () {},
                  focusColor: Colors.deepOrange,
                  child: Text('Control $index'),
                ),
            ],
          ),
        ),
      ),
    );

    final controls = find.byType(WorkbenchKeyboardActivatable);
    expect(controls, findsNWidgets(3));

    for (var expectedIndex = 0; expectedIndex < 3; expectedIndex++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final focusedIndex = List.generate(3, (index) {
        final decorated = tester.widget<DecoratedBox>(
          find.descendant(
            of: controls.at(index),
            matching: find.byType(DecoratedBox),
          ),
        );
        return (decorated.decoration as BoxDecoration).border != null
            ? index
            : null;
      }).whereType<int>().toList();

      expect(focusedIndex, [expectedIndex]);
    }
  });
}
