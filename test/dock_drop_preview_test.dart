import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_drop_preview.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';

void main() {
  final root = DockSplitNode(
    axis: DockAxis.horizontal,
    children: [
      const DockPanelNode(WorkbenchPanelId.editor),
      DockSplitNode(
        axis: DockAxis.vertical,
        children: const [
          DockPanelNode(WorkbenchPanelId.preview),
          DockPanelNode(WorkbenchPanelId.inspector),
        ],
        ratios: const [0.6, 0.4],
      ),
    ],
    ratios: const [0.4, 0.6],
  );

  test('finds nested target and returns top preview geometry', () {
    final preview = DockDropPreviewCalculator.forPointer(
      root: root,
      canvasSize: const Size(1000, 800),
      pointer: const Offset(700, 90),
      sourcePanel: WorkbenchPanelId.editor,
      targetPanel: WorkbenchPanelId.preview,
    );

    expect(preview, isNotNull);
    expect(preview!.targetPath, [1, 0]);
    expect(preview.targetPanel, WorkbenchPanelId.preview);
    expect(preview.zone, DockZone.top);
    expect(preview.orientation, DockDropPreviewOrientation.vertical);
    expect(preview.rect.top, preview.targetRect.top);
    expect(preview.rect.height, closeTo(preview.targetRect.height / 2, 0.01));
  });

  test('returns left, right, and center zones for the same target', () {
    DockDropPreview? preview = DockDropPreviewCalculator.forPointer(
      root: root,
      canvasSize: const Size(1000, 800),
      pointer: const Offset(390, 300),
      sourcePanel: WorkbenchPanelId.inspector,
      targetPanel: WorkbenchPanelId.editor,
    );
    expect(preview!.zone, DockZone.right);
    expect(preview.orientation, DockDropPreviewOrientation.horizontal);

    preview = DockDropPreviewCalculator.forPointer(
      root: root,
      canvasSize: const Size(1000, 800),
      pointer: const Offset(180, 320),
      sourcePanel: WorkbenchPanelId.inspector,
      targetPanel: WorkbenchPanelId.editor,
    );
    expect(preview!.zone, DockZone.center);
    expect(preview.orientation, DockDropPreviewOrientation.none);
    expect(preview.isValid, isTrue);
  });

  test('does not preview self-drop or pointer outside target', () {
    expect(
      DockDropPreviewCalculator.forPointer(
        root: root,
        canvasSize: const Size(1000, 800),
        pointer: const Offset(180, 320),
        sourcePanel: WorkbenchPanelId.editor,
        targetPanel: WorkbenchPanelId.editor,
      ),
      isNull,
    );
    expect(
      DockDropPreviewCalculator.forPointer(
        root: root,
        canvasSize: const Size(1000, 800),
        pointer: const Offset(990, 790),
        sourcePanel: WorkbenchPanelId.editor,
        targetPanel: WorkbenchPanelId.preview,
      ),
      isNull,
    );
  });

  test('an unavailable panel absent from the active tree is not a target', () {
    expect(
      DockDropPreviewCalculator.forPointer(
        root: root,
        canvasSize: const Size(1000, 800),
        pointer: const Offset(500, 300),
        sourcePanel: WorkbenchPanelId.editor,
        targetPanel: WorkbenchPanelId.parameters,
      ),
      isNull,
    );
  });

  test('marks a target invalid when the resulting split is too small', () {
    final preview = DockDropPreviewCalculator.forPointer(
      root: const DockPanelNode(WorkbenchPanelId.editor),
      canvasSize: const Size(200, 200),
      pointer: const Offset(100, 100),
      sourcePanel: WorkbenchPanelId.inspector,
      targetPanel: WorkbenchPanelId.editor,
      minimumPanelSize: const Size(120, 120),
    );

    expect(preview, isNotNull);
    expect(preview!.isValid, isFalse);
  });
}
