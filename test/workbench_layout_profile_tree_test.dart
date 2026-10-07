import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_tree_operations.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_profiles.dart';

void main() {
  for (final profile in WorkbenchLayoutProfiles.all) {
    test('${profile.id} exposes a deterministic valid dock-tree baseline', () {
      final first = profile.dockedRoot;
      final second = profile.dockedRoot;
      final expectedPanels = profile.layout.panels.entries
          .where(
            (entry) =>
                entry.value.visibility != WorkbenchPanelVisibility.hidden &&
                entry.value.placement != WorkbenchPanelPlacement.floating,
          )
          .map((entry) => entry.key)
          .toSet();

      expect(first, isNotNull);
      expect(first, second);
      expect(DockTreeOperations.isValid(first!), isTrue);
      expect(_panelsIn(first), expectedPanels);
    });
  }

  test('profile tree preserves compatibility split fallback weights', () {
    final root = WorkbenchLayoutProfiles.inspect.dockedRoot as DockSplitNode;
    final inspect = root.children.first as DockSplitNode;

    expect(root.axis, DockAxis.vertical);
    expect(inspect.axis, DockAxis.horizontal);
    expect(inspect.ratios, [0.38, 1 / 3]);
  });
}

Set<WorkbenchPanelId> _panelsIn(DockNode node) => switch (node) {
  DockPanelNode panel => panel.panels,
  DockSplitNode split => split.panels,
  _ => const <WorkbenchPanelId>{},
};
