import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'package:relgeo_flutter/src/features/preview/workbench_preview_feature.dart';
import 'package:relgeo_flutter/src/features/preview/workbench_viewport_panel.dart';
import 'package:relgeo_flutter/src/ui/workbench_viewport_controller.dart';
import 'package:relgeo_flutter/src/ui/workbench_visual_profile.dart';

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

  testWidgets('canvas preview exposes selected-object semantics', (
    tester,
  ) async {
    final viewportController = WorkbenchViewportController();
    addTearDown(viewportController.dispose);
    final scene = ResolvedScene(
      unit: LengthUnit.mm,
      objects: <String, ResolvedObject>{},
      parameters: <String, double>{},
      values: <String, double>{},
      bbox: BoundingBox(x: 0, y: 0, width: 120, height: 80),
    );
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: WorkbenchViewportPanel(
            visualProfile: WorkbenchVisualProfile.cad,
            viewportController: viewportController.transformationController,
            scene: scene,
            displayBounds: scene.bbox,
            overlay: const OverlayOptions(),
            zoomLevel: 1,
            selectedSheetId: null,
            hiddenRoles: const <String>{},
            onViewportSizeChanged: (_) {},
            activeSheetPhysicalTargetLabel: null,
            activeSheetViewSummaryLabel: null,
            selectedObjectId: 'panel',
            onCanvasTap: (_) {},
            showGraph: false,
            onToggleGraph: () {},
            onSelectObject: (_) {},
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Canvas preview'),
    );
    expect(semantics.value, 'Selected object panel');
    expect(semantics.hint, 'Tap an object to select it');
    semanticsHandle.dispose();
  });
}
