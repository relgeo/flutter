import '../workbench_layout_model.dart';
import 'dock_node.dart';

/// Projects the legacy placement model into a renderable dock tree.
///
/// This is intentionally a projection, not persistence. It lets the new
/// renderer be exercised while the controller still owns the compatibility
/// placement model. Hidden and floating panels are excluded from this render
/// tree; their preference state remains untouched in [WorkbenchLayoutModel].
class DockLayoutAdapter {
  const DockLayoutAdapter._();

  static DockNode? fromPlacementLayout(WorkbenchLayoutModel layout) {
    final sidePanels = <DockPanelNode>[];
    final sideRatios = <double>[];
    for (final placement in const [
      WorkbenchPanelPlacement.left,
      WorkbenchPanelPlacement.center,
      WorkbenchPanelPlacement.right,
    ]) {
      for (final panel in WorkbenchPanelId.values) {
        final state = layout.panels[panel];
        if (state == null ||
            state.visibility == WorkbenchPanelVisibility.hidden ||
            state.placement != placement) {
          continue;
        }
        sidePanels.add(DockPanelNode(panel));
        // The placement renderer historically assigns an unspecified panel
        // one third of the split weight (not a full weight). Keep that
        // fallback when projecting to a recursive tree so presets with a
        // hidden/omitted edge panel retain their intended proportions.
        sideRatios.add(layout.splitRatios[placement.storageKey] ?? 1 / 3);
      }
    }

    DockNode? main;
    if (sidePanels.isNotEmpty) {
      main = _split(
        axis: DockAxis.horizontal,
        children: sidePanels,
        ratios: sideRatios,
      );
    }

    final parameters = layout.panels[WorkbenchPanelId.parameters];
    if (parameters != null &&
        parameters.visibility != WorkbenchPanelVisibility.hidden &&
        parameters.placement == WorkbenchPanelPlacement.bottom) {
      final parameterNode = DockPanelNode(WorkbenchPanelId.parameters);
      if (main == null) return parameterNode;
      return DockSplitNode(
        axis: DockAxis.vertical,
        children: [main, parameterNode],
        ratios: const [0.7, 0.3],
      );
    }
    return main;
  }

  static DockNode _split({
    required DockAxis axis,
    required List<DockNode> children,
    required List<double> ratios,
  }) {
    if (children.length == 1) return children.single;
    return DockSplitNode(axis: axis, children: children, ratios: ratios);
  }
}
