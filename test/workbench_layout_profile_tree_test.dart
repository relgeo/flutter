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
                entry.value.placement != WorkbenchPanelPlacement.floating &&
                entry.value.placement != WorkbenchPanelPlacement.overlay,
          )
          .map((entry) => entry.key)
          .toSet();

      expect(first, isNotNull);
      expect(first, second);
      expect(DockTreeOperations.isValid(first!), isTrue);
      expect(_panelsIn(first), expectedPanels);
    });
  }
}

Set<WorkbenchPanelId> _panelsIn(DockNode node) => switch (node) {
  DockPanelNode panel => panel.panels,
  DockSplitNode split => split.panels,
  _ => const <WorkbenchPanelId>{},
};
