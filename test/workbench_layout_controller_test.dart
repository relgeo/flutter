import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_layout_renderer.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_tree_operations.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_controller.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_profiles.dart';

void main() {
  test(
    'panel visibility changes are observable and document availability is respected',
    () {
      final controller = WorkbenchLayoutController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.togglePanel(WorkbenchPanelId.inspector);
      expect(controller.isPanelVisible(WorkbenchPanelId.inspector), isFalse);
      expect(notifications, 1);

      controller.togglePanel(
        WorkbenchPanelId.parameters,
        availability: WorkbenchPanelAvailability.unavailable,
      );
      expect(
        controller.panel(WorkbenchPanelId.parameters).visibility,
        WorkbenchPanelVisibility.visible,
      );
      expect(notifications, 1);
    },
  );

  test(
    'close, placement, bounds, split ratio, and profile are independent operations',
    () {
      final controller = WorkbenchLayoutController();

      controller.closePanel(WorkbenchPanelId.preview);
      expect(
        controller.panel(WorkbenchPanelId.preview).visibility,
        WorkbenchPanelVisibility.hidden,
      );
      controller.togglePanel(WorkbenchPanelId.preview);
      controller.setPlacement(
        WorkbenchPanelId.preview,
        WorkbenchPanelPlacement.floating,
      );
      controller.setBounds(
        WorkbenchPanelId.preview,
        const WorkbenchPanelBounds(width: 720, height: 480),
      );
      controller.setFloatingBounds(
        WorkbenchPanelId.preview,
        const WorkbenchPanelBounds(width: 720, height: 480),
      );
      controller.setSplitRatio('left', 0.4);
      controller.setActiveProfile('custom');

      expect(
        controller.panel(WorkbenchPanelId.preview).visibility,
        WorkbenchPanelVisibility.visible,
      );
      expect(
        controller.panel(WorkbenchPanelId.preview).placement,
        WorkbenchPanelPlacement.floating,
      );
      expect(controller.layout.splitRatios['left'], 0.4);
      expect(controller.layout.activeProfileId, 'custom');
    },
  );

  test('invalid split ratios and empty profile ids do not mutate state', () {
    final controller = WorkbenchLayoutController();
    final original = controller.layout;

    controller.setSplitRatio('left', 0);
    controller.setSplitRatio('left', 1.1);
    controller.setActiveProfile('');

    expect(controller.layout, original);
  });

  test(
    'built-in profile application replaces layout without document state',
    () {
      final controller = WorkbenchLayoutController();

      controller.applyProfile(WorkbenchLayoutProfiles.minimal);

      expect(controller.layout.activeProfileId, 'minimal');
      expect(
        controller.panel(WorkbenchPanelId.inspector).visibility,
        WorkbenchPanelVisibility.hidden,
      );
      expect(
        controller.panel(WorkbenchPanelId.parameters).visibility,
        WorkbenchPanelVisibility.visible,
      );
      expect(controller.dockedRoot, isNotNull);
    },
  );

  test('manual layout edits move the active profile to Custom', () {
    final controller = WorkbenchLayoutController();
    controller.applyProfile(WorkbenchLayoutProfiles.writing);

    controller.setSplitRatio('left', 0.5);

    expect(controller.layout.activeProfileId, 'custom');
  });

  test('reset restores the standard profile baseline', () {
    final controller = WorkbenchLayoutController();
    controller.setPlacement(
      WorkbenchPanelId.inspector,
      WorkbenchPanelPlacement.floating,
    );

    controller.reset();

    expect(controller.layout.activeProfileId, 'standard');
    expect(controller.dockedRoot, isNotNull);
  });

  test('restore rejects duplicate panel leaves instead of rendering twice', () {
    final layout = WorkbenchLayoutModel.standard();
    final duplicate = DockSplitNode(
      axis: DockAxis.horizontal,
      children: const [
        DockPanelNode(WorkbenchPanelId.editor),
        DockPanelNode(WorkbenchPanelId.editor),
      ],
      ratios: const [0.5, 0.5],
    );
    final controller = WorkbenchLayoutController(initialLayout: layout);

    controller.restore(layout, dockedRoot: duplicate);

    expect(controller.dockedRoot, isNull);
    expect(
      controller.panel(WorkbenchPanelId.editor),
      layout.panels[WorkbenchPanelId.editor],
    );
  });

  test('restore keeps floating panels out of the dock tree', () {
    final standard = WorkbenchLayoutModel.standard();
    final layout = standard.copyWith(
      panels: {
        ...standard.panels,
        WorkbenchPanelId.editor: standard.panels[WorkbenchPanelId.editor]!
            .copyWith(placement: WorkbenchPanelPlacement.floating),
      },
    );
    final root = DockSplitNode(
      axis: DockAxis.horizontal,
      children: const [
        DockPanelNode(WorkbenchPanelId.editor),
        DockPanelNode(WorkbenchPanelId.preview),
      ],
      ratios: const [0.5, 0.5],
    );
    final controller = WorkbenchLayoutController(initialLayout: standard);

    controller.restore(layout, dockedRoot: root);

    expect(controller.dockedRoot, isNull);
    expect(
      controller.panel(WorkbenchPanelId.editor).placement,
      WorkbenchPanelPlacement.floating,
    );
  });

  test('floating the last dock-tree panel clears the tree', () {
    final layout = WorkbenchLayoutModel.standard();
    final controller = WorkbenchLayoutController(initialLayout: layout);
    controller.restore(
      layout,
      dockedRoot: const DockPanelNode(WorkbenchPanelId.editor),
    );

    controller.setPlacement(
      WorkbenchPanelId.editor,
      WorkbenchPanelPlacement.floating,
    );

    expect(controller.dockedRoot, isNull);
    expect(
      controller.panel(WorkbenchPanelId.editor).placement,
      WorkbenchPanelPlacement.floating,
    );
  });

  test('docking menu placement preserves and edits the active nested tree', () {
    final layout = WorkbenchLayoutModel.standard();
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
    final controller = WorkbenchLayoutController(initialLayout: layout);
    controller.restore(layout, dockedRoot: root);

    controller.setPlacement(
      WorkbenchPanelId.inspector,
      WorkbenchPanelPlacement.left,
    );

    expect(controller.dockedRoot, isNotNull);
    expect(DockTreeOperations.isValid(controller.dockedRoot!), isTrue);
    expect((controller.dockedRoot! as DockSplitNode).panels, {
      WorkbenchPanelId.editor,
      WorkbenchPanelId.preview,
      WorkbenchPanelId.inspector,
    });
    expect(
      controller.panel(WorkbenchPanelId.inspector).placement,
      WorkbenchPanelPlacement.left,
    );
    expect(controller.focusRequest, WorkbenchPanelId.inspector);
  });

  test('returning a floating panel by placement command inserts it once', () {
    final standard = WorkbenchLayoutModel.standard();
    final layout = standard.copyWith(
      panels: {
        ...standard.panels,
        WorkbenchPanelId.inspector: standard.panels[WorkbenchPanelId.inspector]!
            .copyWith(placement: WorkbenchPanelPlacement.floating),
      },
      floatingOrder: const [WorkbenchPanelId.inspector],
    );
    final root = DockSplitNode(
      axis: DockAxis.horizontal,
      children: const [
        DockPanelNode(WorkbenchPanelId.editor),
        DockPanelNode(WorkbenchPanelId.preview),
      ],
      ratios: const [0.5, 0.5],
    );
    final controller = WorkbenchLayoutController(initialLayout: layout);
    controller.restore(layout, dockedRoot: root);

    controller.setPlacement(
      WorkbenchPanelId.inspector,
      WorkbenchPanelPlacement.right,
    );

    final dockedRoot = controller.dockedRoot! as DockSplitNode;
    expect(DockTreeOperations.isValid(dockedRoot), isTrue);
    expect(dockedRoot.panels, {
      WorkbenchPanelId.editor,
      WorkbenchPanelId.preview,
      WorkbenchPanelId.inspector,
    });
    expect(controller.layout.floatingOrder, isEmpty);
    expect(
      controller.panel(WorkbenchPanelId.inspector).placement,
      WorkbenchPanelPlacement.right,
    );
  });

  test('dock divider resize uses feature-specific minimum widths', () {
    final layout = WorkbenchLayoutModel.standard();
    final root = DockSplitNode(
      axis: DockAxis.horizontal,
      children: const [
        DockPanelNode(WorkbenchPanelId.editor),
        DockPanelNode(WorkbenchPanelId.preview),
      ],
      ratios: const [0.5, 0.5],
    );
    final controller = WorkbenchLayoutController(initialLayout: layout);
    controller.restore(layout, dockedRoot: root);

    controller.resizeDockDivider(
      const DockDividerLocation(
        splitPath: [],
        axis: DockAxis.horizontal,
        dividerIndex: 0,
      ),
      -1000,
      800,
    );

    expect(
      (controller.dockedRoot! as DockSplitNode).ratios.first,
      closeTo(0.35, 0.0001),
    );
  });

  test('dock divider resize respects feature-specific maximum widths', () {
    final standard = WorkbenchLayoutModel.standard();
    final layout = standard.copyWith(
      panels: {
        ...standard.panels,
        WorkbenchPanelId.editor: standard.panels[WorkbenchPanelId.editor]!
            .copyWith(bounds: const WorkbenchPanelBounds(maxWidth: 400)),
      },
    );
    final root = DockSplitNode(
      axis: DockAxis.horizontal,
      children: const [
        DockPanelNode(WorkbenchPanelId.editor),
        DockPanelNode(WorkbenchPanelId.preview),
      ],
      ratios: const [0.5, 0.5],
    );
    final controller = WorkbenchLayoutController(initialLayout: layout);
    controller.restore(layout, dockedRoot: root);

    controller.resizeDockDivider(
      const DockDividerLocation(
        splitPath: [],
        axis: DockAxis.horizontal,
        dividerIndex: 0,
      ),
      1000,
      800,
    );

    expect(
      (controller.dockedRoot! as DockSplitNode).ratios.first,
      closeTo(0.5, 0.0001),
    );
  });

  test('parameters can be resized within vertical bounds', () {
    final controller = WorkbenchLayoutController();

    controller.resizeParameters(80, 700);
    expect(controller.panel(WorkbenchPanelId.parameters).bounds.height, 140);
    expect(controller.layout.activeProfileId, 'custom');
  });

  test('floating panel movement updates persisted position', () {
    final controller = WorkbenchLayoutController();
    controller.setPlacement(
      WorkbenchPanelId.inspector,
      WorkbenchPanelPlacement.floating,
    );
    controller.setFloatingBounds(
      WorkbenchPanelId.inspector,
      const WorkbenchPanelBounds(left: 32, top: 24, width: 320, height: 240),
    );

    controller.moveFloatingPanel(WorkbenchPanelId.inspector, dx: 16, dy: 12);

    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.left,
      48,
    );
    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.top,
      36,
    );
  });

  test('floating focus updates z-order without changing panel placement', () {
    final controller = WorkbenchLayoutController();
    controller.setPlacement(
      WorkbenchPanelId.editor,
      WorkbenchPanelPlacement.floating,
    );
    controller.setPlacement(
      WorkbenchPanelId.inspector,
      WorkbenchPanelPlacement.floating,
    );

    expect(controller.layout.floatingOrder, const [
      WorkbenchPanelId.editor,
      WorkbenchPanelId.inspector,
    ]);
    controller.focusFloatingPanel(WorkbenchPanelId.editor);

    expect(controller.layout.floatingOrder, const [
      WorkbenchPanelId.inspector,
      WorkbenchPanelId.editor,
    ]);
    expect(
      controller.panel(WorkbenchPanelId.editor).placement,
      WorkbenchPanelPlacement.floating,
    );
  });

  test('floating movement and resize respect canvas bounds', () {
    final controller = WorkbenchLayoutController();
    controller.setPlacement(
      WorkbenchPanelId.inspector,
      WorkbenchPanelPlacement.floating,
    );
    controller.setFloatingBounds(
      WorkbenchPanelId.inspector,
      const WorkbenchPanelBounds(
        left: 40,
        top: 40,
        width: 320,
        height: 240,
        minWidth: 240,
        minHeight: 160,
      ),
    );

    controller.moveFloatingPanel(
      WorkbenchPanelId.inspector,
      dx: 1000,
      dy: 1000,
      canvasWidth: 800,
      canvasHeight: 600,
    );
    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.left,
      480,
    );
    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.top,
      360,
    );

    controller.resizeFloatingPanel(
      WorkbenchPanelId.inspector,
      dx: 1000,
      dy: 1000,
      canvasWidth: 800,
      canvasHeight: 600,
    );
    final bounds =
        controller.layout.floatingBounds[WorkbenchPanelId.inspector]!;
    expect(bounds.width, 320);
    expect(bounds.height, 240);

    controller.setFloatingBounds(
      WorkbenchPanelId.inspector,
      const WorkbenchPanelBounds(
        left: 40,
        top: 40,
        width: 320,
        height: 240,
        minWidth: 240,
        minHeight: 160,
      ),
    );
    controller.resizeFloatingPanel(
      WorkbenchPanelId.inspector,
      dx: 1000,
      dy: 1000,
      canvasWidth: 800,
      canvasHeight: 600,
    );
    final expanded =
        controller.layout.floatingBounds[WorkbenchPanelId.inspector]!;
    expect(expanded.width, 760);
    expect(expanded.height, 560);

    controller.resizeFloatingPanel(
      WorkbenchPanelId.inspector,
      dx: -1000,
      dy: -1000,
      canvasWidth: 800,
      canvasHeight: 600,
    );
    final minimum =
        controller.layout.floatingBounds[WorkbenchPanelId.inspector]!;
    expect(minimum.width, 240);
    expect(minimum.height, 160);
  });

  test('cancelled floating drag restores bounds and z-order', () {
    final controller = WorkbenchLayoutController();
    controller.setPlacement(
      WorkbenchPanelId.inspector,
      WorkbenchPanelPlacement.floating,
    );
    controller.setFloatingBounds(
      WorkbenchPanelId.inspector,
      const WorkbenchPanelBounds(left: 32, top: 24, width: 320, height: 240),
    );
    controller.setPlacement(
      WorkbenchPanelId.preview,
      WorkbenchPanelPlacement.floating,
    );
    final originalOrder = controller.layout.floatingOrder;

    controller.beginFloatingPanelDrag(WorkbenchPanelId.inspector);
    controller.focusFloatingPanel(WorkbenchPanelId.inspector);
    controller.moveFloatingPanel(WorkbenchPanelId.inspector, dx: 120, dy: 80);
    controller.cancelFloatingPanelDrag(WorkbenchPanelId.inspector);

    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector],
      const WorkbenchPanelBounds(left: 32, top: 24, width: 320, height: 240),
    );
    expect(controller.layout.floatingOrder, originalOrder);
  });
}
