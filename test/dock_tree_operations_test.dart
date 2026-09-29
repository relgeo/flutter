import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_tree_operations.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';

void main() {
  test('serializes and restores a nested dock tree', () {
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
          ratios: const [0.7, 0.3],
        ),
      ],
      ratios: const [0.32, 0.68],
    );
    final layout = DockedLayout(schemaVersion: 2, root: root);

    expect(DockedLayout.fromJson(layout.toJson()), layout);
    expect(DockTreeOperations.isValid(root), isTrue);
  });

  test(
    'left/right creates horizontal and top/bottom creates vertical splits',
    () {
      const root = DockPanelNode(WorkbenchPanelId.preview);

      final left = DockTreeOperations.insert(
        root: root,
        panel: WorkbenchPanelId.editor,
        target: WorkbenchPanelId.preview,
        zone: DockZone.left,
      );
      expect(left, isA<DockSplitNode>());
      expect((left as DockSplitNode).axis, DockAxis.horizontal);
      expect(left.children.first, const DockPanelNode(WorkbenchPanelId.editor));

      final bottom = DockTreeOperations.insert(
        root: root,
        panel: WorkbenchPanelId.inspector,
        target: WorkbenchPanelId.preview,
        zone: DockZone.bottom,
      );
      expect((bottom as DockSplitNode).axis, DockAxis.vertical);
      expect(
        bottom.children.last,
        const DockPanelNode(WorkbenchPanelId.inspector),
      );
    },
  );

  test(
    'insert nests into an existing tree and remove normalizes single-child splits',
    () {
      const root = DockPanelNode(WorkbenchPanelId.editor);
      final withPreview = DockTreeOperations.insert(
        root: root,
        panel: WorkbenchPanelId.preview,
        target: WorkbenchPanelId.editor,
        zone: DockZone.right,
      );
      final nested = DockTreeOperations.insert(
        root: withPreview,
        panel: WorkbenchPanelId.inspector,
        target: WorkbenchPanelId.preview,
        zone: DockZone.bottom,
      );

      expect(DockTreeOperations.isValid(nested), isTrue);
      final restored = DockTreeOperations.remove(
        root: nested,
        panel: WorkbenchPanelId.preview,
      );
      expect(restored, isA<DockSplitNode>());
      expect(DockTreeOperations.isValid(restored), isTrue);
      expect((restored as DockSplitNode).panels, {
        WorkbenchPanelId.editor,
        WorkbenchPanelId.inspector,
      });
    },
  );

  test('repeated moves retain each panel exactly once', () {
    final initial = DockSplitNode(
      axis: DockAxis.horizontal,
      children: const [
        DockPanelNode(WorkbenchPanelId.editor),
        DockPanelNode(WorkbenchPanelId.preview),
        DockPanelNode(WorkbenchPanelId.inspector),
      ],
      ratios: const [0.34, 0.33, 0.33],
    );

    final moved = DockTreeOperations.move(
      root: initial,
      panel: WorkbenchPanelId.preview,
      target: WorkbenchPanelId.inspector,
      zone: DockZone.bottom,
    );
    final movedAgain = DockTreeOperations.move(
      root: moved,
      panel: WorkbenchPanelId.preview,
      target: WorkbenchPanelId.editor,
      zone: DockZone.right,
    );

    expect(DockTreeOperations.isValid(movedAgain), isTrue);
    expect((movedAgain as DockSplitNode).panels, {
      WorkbenchPanelId.editor,
      WorkbenchPanelId.preview,
      WorkbenchPanelId.inspector,
    });
  });

  test('duplicate and missing targets are rejected without a partial tree', () {
    const root = DockPanelNode(WorkbenchPanelId.editor);

    expect(
      () => DockTreeOperations.insert(
        root: root,
        panel: WorkbenchPanelId.editor,
        target: WorkbenchPanelId.editor,
        zone: DockZone.right,
      ),
      throwsStateError,
    );
    expect(
      () => DockTreeOperations.insert(
        root: root,
        panel: WorkbenchPanelId.preview,
        target: WorkbenchPanelId.inspector,
        zone: DockZone.right,
      ),
      throwsStateError,
    );
  });

  test(
    'invalid ratios are reported and normalization repairs safe weights',
    () {
      final invalid = DockSplitNode(
        axis: DockAxis.horizontal,
        children: const [
          DockPanelNode(WorkbenchPanelId.editor),
          DockPanelNode(WorkbenchPanelId.preview),
        ],
        ratios: const [1, 0],
      );
      expect(DockTreeOperations.validate(invalid), isNotEmpty);

      final normalized = DockTreeOperations.normalize(invalid) as DockSplitNode;
      expect(normalized.ratios, const [0.5, 0.5]);
      expect(DockTreeOperations.isValid(normalized), isTrue);
    },
  );

  test(
    'resizes a nested split with positive delta growing the first child',
    () {
      final root = DockSplitNode(
        axis: DockAxis.horizontal,
        children: const [
          DockPanelNode(WorkbenchPanelId.editor),
          DockPanelNode(WorkbenchPanelId.preview),
        ],
        ratios: const [0.5, 0.5],
      );

      final resized =
          DockTreeOperations.resize(
                root: root,
                splitPath: const [],
                dividerIndex: 0,
                deltaPixels: 100,
                availablePixels: 800,
                minimumPixels: 120,
              )
              as DockSplitNode;

      expect(resized.ratios.first, closeTo(0.625, 0.0001));
      expect(resized.ratios.last, closeTo(0.375, 0.0001));
    },
  );

  test('resize clamps both sides and addresses nested split path', () {
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
          ratios: const [0.5, 0.5],
        ),
      ],
      ratios: const [0.4, 0.6],
    );

    final resized =
        DockTreeOperations.resize(
              root: root,
              splitPath: const [1],
              dividerIndex: 0,
              deltaPixels: 1000,
              availablePixels: 600,
              minimumPixels: 120,
            )
            as DockSplitNode;
    final nested = resized.children[1] as DockSplitNode;

    expect(nested.ratios.first, closeTo(0.8, 0.0001));
    expect(nested.ratios.last, closeTo(0.2, 0.0001));
    expect(DockTreeOperations.isValid(resized), isTrue);
  });
}
