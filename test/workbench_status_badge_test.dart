import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_status_badge.dart';

void main() {
  testWidgets('status badge renders label and visual contract', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchStatusBadge(
            label: 'MODEL PREVIEW',
            backgroundColor: Colors.black,
            borderColor: Colors.white,
            textColor: Colors.green,
          ),
        ),
      ),
    );

    expect(find.text('MODEL PREVIEW'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(5));
  });
}
