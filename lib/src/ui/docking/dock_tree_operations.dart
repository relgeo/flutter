import '../workbench_layout_model.dart';
import 'dock_node.dart';

/// Pure transformations and validation for the workbench dock tree.
class DockTreeOperations {
  const DockTreeOperations._();

  static DockNode insert({
    required DockNode root,
    required WorkbenchPanelId panel,
    required WorkbenchPanelId target,
    required DockZone zone,
    DockAxis centerAxis = DockAxis.vertical,
  }) {
    if (_panelsOf(root).contains(panel)) {
      throw StateError('Panel ${panel.name} already exists in dock tree');
    }
    final inserted = _insertInto(
      root,
      panel: panel,
      target: target,
      zone: zone,
      centerAxis: centerAxis,
    );
    if (inserted == null) {
      throw StateError('Target panel ${target.name} was not found');
    }
    return normalize(inserted);
  }

  static DockNode remove({
    required DockNode root,
    required WorkbenchPanelId panel,
  }) {
    final result = _removeFrom(root, panel);
    if (result == null) {
      throw StateError('Panel ${panel.name} was not found');
    }
    return normalize(result);
  }

  /// Moves a panel to a new dock zone without leaving its previous node in
  /// the tree. This also repairs duplicate instances of the moved panel by
  /// removing every old occurrence before inserting exactly one new leaf.
  static DockNode move({
    required DockNode root,
    required WorkbenchPanelId panel,
    required WorkbenchPanelId target,
    required DockZone zone,
    DockAxis centerAxis = DockAxis.vertical,
  }) {
    if (panel == target) {
      throw ArgumentError.value(
        target,
        'target',
        'A panel cannot dock to itself',
      );
    }
    final rootWithoutPanel = _panelsOf(root).contains(panel)
        ? remove(root: root, panel: panel)
        : root;
    return insert(
      root: rootWithoutPanel,
      panel: panel,
      target: target,
      zone: zone,
      centerAxis: centerAxis,
    );
  }

  /// Resizes two adjacent children in a split without changing tree shape.
  ///
  /// [splitPath] identifies the split by child indexes from the root. A
  /// positive delta increases the first child, so horizontal drags grow the
  /// left side and vertical drags grow the upper side. The operation keeps the
  /// pair's total weight and clamps both sides to [minimumPixels].
  static DockNode resize({
    required DockNode root,
    required List<int> splitPath,
    required int dividerIndex,
    required double deltaPixels,
    required double availablePixels,
    double minimumPixels = 120,
    double? minimumFirstPixels,
    double? minimumSecondPixels,
    double maximumFirstPixels = double.infinity,
    double maximumSecondPixels = double.infinity,
  }) {
    if (!deltaPixels.isFinite ||
        !availablePixels.isFinite ||
        availablePixels <= 0 ||
        !minimumPixels.isFinite ||
        minimumPixels < 0 ||
        (minimumFirstPixels != null &&
            (!minimumFirstPixels.isFinite || minimumFirstPixels < 0)) ||
        (minimumSecondPixels != null &&
            (!minimumSecondPixels.isFinite || minimumSecondPixels < 0)) ||
        maximumFirstPixels.isNaN ||
        maximumFirstPixels < 0 ||
        maximumSecondPixels.isNaN ||
        maximumSecondPixels < 0) {
      throw ArgumentError('Resize dimensions must be finite and valid');
    }
    final minimumFirst = minimumFirstPixels ?? minimumPixels;
    final minimumSecond = minimumSecondPixels ?? minimumPixels;
    final result = _resizeAt(
      root,
      splitPath,
      pathIndex: 0,
      dividerIndex: dividerIndex,
      deltaPixels: deltaPixels,
      availablePixels: availablePixels,
      minimumFirstPixels: minimumFirst,
      minimumSecondPixels: minimumSecond,
      maximumFirstPixels: maximumFirstPixels,
      maximumSecondPixels: maximumSecondPixels,
    );
    if (result == null) {
      throw StateError('Dock split or divider was not found');
    }
    return normalize(result);
  }

  /// Minimum extent a subtree needs along [axis], including its one-pixel
  /// dividers. Orthogonal splits share the maximum child requirement; splits
  /// in the requested axis add child requirements together.
  static double minimumExtent(
    DockNode node,
    DockAxis axis, {
    required double Function(WorkbenchPanelId panel, DockAxis axis)
    panelMinimumExtent,
    double dividerThickness = 1,
  }) {
    if (node is DockPanelNode) {
      return panelMinimumExtent(node.panelId, axis);
    }
    if (node is! DockSplitNode || node.children.isEmpty) return 0;
    final extents = [
      for (final child in node.children)
        minimumExtent(
          child,
          axis,
          panelMinimumExtent: panelMinimumExtent,
          dividerThickness: dividerThickness,
        ),
    ];
    if (node.axis != axis) {
      return extents.reduce((a, b) => a > b ? a : b);
    }
    return extents.fold<double>(0, (sum, value) => sum + value) +
        (node.children.length - 1) * dividerThickness;
  }

  /// Maximum extent a subtree can occupy along [axis], or infinity when its
  /// panel bounds do not define an upper limit. Orthogonal branches must all
  /// fit within the same dimension, so their tightest upper bound wins.
  static double maximumExtent(
    DockNode node,
    DockAxis axis, {
    required double Function(WorkbenchPanelId panel, DockAxis axis)
    panelMaximumExtent,
  }) {
    if (node is DockPanelNode) {
      return panelMaximumExtent(node.panelId, axis);
    }
    if (node is! DockSplitNode || node.children.isEmpty) {
      return double.infinity;
    }
    final extents = [
      for (final child in node.children)
        maximumExtent(child, axis, panelMaximumExtent: panelMaximumExtent),
    ];
    if (node.axis != axis) {
      return extents.reduce((a, b) => a < b ? a : b);
    }
    if (extents.any((extent) => !extent.isFinite)) return double.infinity;
    return extents.fold<double>(0, (sum, value) => sum + value) +
        node.children.length -
        1;
  }

  /// Returns the split at a child-index path, or null for a stale path.
  static DockSplitNode? splitAt(DockNode root, List<int> path) {
    var node = root;
    for (final index in path) {
      if (node is! DockSplitNode ||
          index < 0 ||
          index >= node.children.length) {
        return null;
      }
      node = node.children[index];
    }
    return node is DockSplitNode ? node : null;
  }

  static DockNode normalize(DockNode node) {
    if (node is DockPanelNode) return node;
    if (node is! DockSplitNode) {
      throw ArgumentError.value(node, 'node', 'Unknown dock node');
    }

    final flattenedChildren = <DockNode>[];
    final flattenedWeights = <double>[];
    for (var index = 0; index < node.children.length; index++) {
      final child = normalize(node.children[index]);
      final parentWeight = index < node.ratios.length
          ? node.ratios[index]
          : 1.0;
      if (child is DockSplitNode && child.axis == node.axis) {
        for (
          var childIndex = 0;
          childIndex < child.children.length;
          childIndex++
        ) {
          flattenedChildren.add(child.children[childIndex]);
          final childWeight = childIndex < child.ratios.length
              ? child.ratios[childIndex]
              : 1.0;
          flattenedWeights.add(parentWeight * childWeight);
        }
      } else {
        flattenedChildren.add(child);
        flattenedWeights.add(parentWeight);
      }
    }

    if (flattenedChildren.isEmpty) {
      throw StateError('A dock split must contain at least one child');
    }
    if (flattenedChildren.length == 1) return flattenedChildren.single;
    return DockSplitNode(
      axis: node.axis,
      children: flattenedChildren,
      ratios: _normalizeRatios(flattenedWeights),
    );
  }

  static List<String> validate(DockNode root) {
    final errors = <String>[];
    final seen = <WorkbenchPanelId>{};

    void visit(Object node, String path) {
      if (node is DockPanelNode) {
        if (!seen.add(node.panelId)) {
          errors.add('$path duplicates ${node.panelId.name}');
        }
        return;
      }
      if (node is! DockSplitNode) {
        errors.add('$path is not a known dock node');
        return;
      }
      if (node.children.length < 2) {
        errors.add('$path must contain at least two children');
      }
      if (node.children.length != node.ratios.length) {
        errors.add('$path ratios must match children');
      }
      if (node.ratios.any((ratio) => !ratio.isFinite || ratio <= 0)) {
        errors.add('$path ratios must be finite and greater than zero');
      }
      final ratioSum = node.ratios.fold<double>(0, (sum, ratio) => sum + ratio);
      if (node.ratios.isNotEmpty && ratioSum <= 0) {
        errors.add('$path ratios must have a positive sum');
      }
      for (var index = 0; index < node.children.length; index++) {
        visit(node.children[index], '$path/$index');
      }
    }

    visit(root, 'root');
    return List.unmodifiable(errors);
  }

  static bool isValid(DockNode root) => validate(root).isEmpty;

  static DockNode? _insertInto(
    DockNode node, {
    required WorkbenchPanelId panel,
    required WorkbenchPanelId target,
    required DockZone zone,
    required DockAxis centerAxis,
  }) {
    if (node is DockPanelNode) {
      if (node.panelId != target) return null;
      final axis = switch (zone) {
        DockZone.left || DockZone.right => DockAxis.horizontal,
        DockZone.top || DockZone.bottom => DockAxis.vertical,
        DockZone.center => centerAxis,
      };
      final newPanel = DockPanelNode(panel);
      final children = switch (zone) {
        DockZone.left || DockZone.top || DockZone.center => [newPanel, node],
        DockZone.right || DockZone.bottom => [node, newPanel],
      };
      return DockSplitNode(
        axis: axis,
        children: children,
        ratios: const [1, 1],
      );
    }
    if (node is! DockSplitNode) return null;

    for (var index = 0; index < node.children.length; index++) {
      final replacement = _insertInto(
        node.children[index],
        panel: panel,
        target: target,
        zone: zone,
        centerAxis: centerAxis,
      );
      if (replacement == null) continue;
      final children = [...node.children]..[index] = replacement;
      return DockSplitNode(
        axis: node.axis,
        children: children,
        ratios: node.ratios,
      );
    }
    return null;
  }

  static DockNode? _removeFrom(DockNode node, WorkbenchPanelId panel) {
    if (node is DockPanelNode) {
      return node.panelId == panel ? null : node;
    }
    if (node is! DockSplitNode) return node;

    final children = <DockNode>[];
    final ratios = <double>[];
    for (var index = 0; index < node.children.length; index++) {
      final child = node.children[index];
      if (_panelsOf(child).contains(panel)) {
        final replacement = _removeFrom(child, panel);
        if (replacement != null) {
          children.add(replacement);
          ratios.add(index < node.ratios.length ? node.ratios[index] : 1);
        }
      } else {
        children.add(child);
        ratios.add(index < node.ratios.length ? node.ratios[index] : 1);
      }
    }
    if (children.isEmpty) return null;
    return DockSplitNode(axis: node.axis, children: children, ratios: ratios);
  }

  static DockNode? _resizeAt(
    DockNode node,
    List<int> path, {
    required int pathIndex,
    required int dividerIndex,
    required double deltaPixels,
    required double availablePixels,
    required double minimumFirstPixels,
    required double minimumSecondPixels,
    required double maximumFirstPixels,
    required double maximumSecondPixels,
  }) {
    if (node is! DockSplitNode) return null;
    if (pathIndex < path.length) {
      final childIndex = path[pathIndex];
      if (childIndex < 0 || childIndex >= node.children.length) return null;
      final replacement = _resizeAt(
        node.children[childIndex],
        path,
        pathIndex: pathIndex + 1,
        dividerIndex: dividerIndex,
        deltaPixels: deltaPixels,
        availablePixels: availablePixels,
        minimumFirstPixels: minimumFirstPixels,
        minimumSecondPixels: minimumSecondPixels,
        maximumFirstPixels: maximumFirstPixels,
        maximumSecondPixels: maximumSecondPixels,
      );
      if (replacement == null) return null;
      final children = [...node.children]..[childIndex] = replacement;
      return DockSplitNode(
        axis: node.axis,
        children: children,
        ratios: node.ratios,
      );
    }

    if (dividerIndex < 0 || dividerIndex >= node.children.length - 1) {
      return null;
    }
    final ratios = _normalizeRatios(node.ratios);
    final left = ratios[dividerIndex];
    final right = ratios[dividerIndex + 1];
    final pair = left + right;
    final pairExtent = pair * availablePixels;
    final lowerFirstPixels =
        minimumFirstPixels > pairExtent - maximumSecondPixels
        ? minimumFirstPixels
        : pairExtent - maximumSecondPixels;
    final upperFirstPixels =
        maximumFirstPixels < pairExtent - minimumSecondPixels
        ? maximumFirstPixels
        : pairExtent - minimumSecondPixels;
    if (lowerFirstPixels > upperFirstPixels) {
      return node;
    }
    final minimumFirstRatio = lowerFirstPixels / availablePixels;
    final maximumFirstRatio = upperFirstPixels / availablePixels;
    final nextLeft = (left + deltaPixels / availablePixels).clamp(
      minimumFirstRatio,
      maximumFirstRatio,
    );
    final nextRatios = [...ratios];
    nextRatios[dividerIndex] = nextLeft;
    nextRatios[dividerIndex + 1] = pair - nextLeft;
    return DockSplitNode(
      axis: node.axis,
      children: node.children,
      ratios: _normalizeRatios(nextRatios),
    );
  }

  static List<double> _normalizeRatios(List<double> ratios) {
    final safe = ratios.map((ratio) => ratio.isFinite && ratio > 0 ? ratio : 1);
    final sum = safe.fold<double>(0, (total, ratio) => total + ratio);
    return [for (final ratio in safe) ratio / sum];
  }

  static Set<WorkbenchPanelId> _panelsOf(Object node) => switch (node) {
    DockPanelNode panel => panel.panels,
    DockSplitNode split => split.panels,
    _ => <WorkbenchPanelId>{},
  };
}
