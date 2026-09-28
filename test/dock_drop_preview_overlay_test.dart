import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_drop_preview.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_drop_preview_overlay.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';

void main() {
  DockDropPreview preview() {
    return DockDropPreviewCalculator.forPointer(
      root: const DockPanelNode(WorkbenchPanelId.preview),
      canvasSize: const Size(400, 300),
      pointer: const Offset(10, 150),
      sourcePanel: WorkbenchPanelId.editor,
      targetPanel: WorkbenchPanelId.preview,
    )!;
  }

  testWidgets('renders a labeled overlay only for a valid preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const SizedBox(width: 400, height: 300),
            DockDropPreviewOverlay(preview: preview()),
          ],
        ),
      ),
    );

    expect(find.byKey(const ValueKey('dock-drop-preview')), findsOneWidget);
    expect(find.text('Dock left'), findsOneWidget);
  });

  testWidgets('renders no overlay for null or invalid preview', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Stack(children: [DockDropPreviewOverlay()])),
    );
    expect(find.byKey(const ValueKey('dock-drop-preview')), findsNothing);
  });
}
