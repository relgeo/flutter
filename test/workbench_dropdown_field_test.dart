import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_dropdown_field.dart';

void main() {
  testWidgets('dropdown field preserves selector and semantics keys', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchDropdownField<String>(
            buttonKey: const Key('mode-selector'),
            semanticsKey: const Key('mode-semantics'),
            value: 'a',
            semanticsLabel: 'Mode',
            semanticsValue: 'A',
            semanticsHint: 'Choose a mode',
            backgroundColor: Colors.black,
            borderColor: Colors.white,
            mutedColor: Colors.grey,
            accentColor: Colors.green,
            onChanged: (_) {},
            items: const [
              DropdownMenuItem<String>(value: 'a', child: Text('A')),
              DropdownMenuItem<String>(value: 'b', child: Text('B')),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('mode-selector')), findsOneWidget);
    expect(find.byKey(const Key('mode-semantics')), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });
}
