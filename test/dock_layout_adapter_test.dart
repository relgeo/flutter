import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_layout_adapter.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';

void main() {
  test(
    'projects standard placement into horizontal main and bottom parameters',
    () {
      final root = DockLayoutAdapter.fromPlacementLayout(
        WorkbenchLayoutModel.standard(),
      );

      expect(root, isA<DockSplitNode>());
      final vertical = root! as DockSplitNode;
      expect(vertical.axis, DockAxis.vertical);
      expect(
        vertical.children.last,
        const DockPanelNode(WorkbenchPanelId.parameters),
      );
      expect(vertical.children.first, isA<DockSplitNode>());
      expect(
        (vertical.children.first as DockSplitNode).axis,
        DockAxis.horizontal,
      );
    },
  );

  test('projection omits hidden and floating panels', () {
    final standard = WorkbenchLayoutModel.standard();
    final layout = standard.copyWith(
      panels: {
        ...standard.panels,
        WorkbenchPanelId.editor: standard.panels[WorkbenchPanelId.editor]!
            .copyWith(visibility: WorkbenchPanelVisibility.hidden),
        WorkbenchPanelId.inspector: standard.panels[WorkbenchPanelId.inspector]!
            .copyWith(visibility: WorkbenchPanelVisibility.hidden),
        WorkbenchPanelId.preview: standard.panels[WorkbenchPanelId.preview]!
            .copyWith(placement: WorkbenchPanelPlacement.floating),
      },
    );

    final root = DockLayoutAdapter.fromPlacementLayout(layout);
    expect(root, const DockPanelNode(WorkbenchPanelId.parameters));
  });
}
