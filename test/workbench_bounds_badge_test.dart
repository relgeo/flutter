import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_bounds_badge.dart';

void main() {
  testWidgets('bounds badge renders its formatted bounds and unit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchBoundsBadge(
            bounds: const Rect.fromLTWH(1, 2, 3, 4),
            unit: 'mm',
            backgroundColor: Colors.black,
            borderColor: Colors.white,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('bounds-badge')), findsOneWidget);
    expect(find.textContaining('BOUNDS:'), findsOneWidget);
    expect(find.textContaining('[3.0 × 4.0 mm]'), findsOneWidget);
  });
}
