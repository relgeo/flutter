import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:relgeo_flutter/src/features/preview/workbench_preview_feature.dart';

void main() {
  testWidgets('composes viewport toolbar, overlay toolbar, and panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 400,
          child: WorkbenchPreviewFeature(
            toolbar: const Text('toolbar'),
            overlayToolbar: const Text('overlay'),
            panel: const Text('panel'),
          ),
        ),
      ),
    );

    expect(find.text('toolbar'), findsOneWidget);
    expect(find.text('overlay'), findsOneWidget);
    expect(find.text('panel'), findsOneWidget);
  });
}
