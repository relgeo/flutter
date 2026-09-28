import 'package:flutter/material.dart';

import '../workbench_layout_model.dart';
import 'dock_node.dart';

/// Builds one independent dock surface from a [DockPanelNode].
typedef DockPanelBuilder =
    Widget Function(BuildContext context, WorkbenchPanelId panelId);

/// Identifies one divider in the recursive dock tree.
class DockDividerLocation {
  const DockDividerLocation({
    required this.splitPath,
    required this.axis,
    required this.dividerIndex,
  });

  final List<int> splitPath;
  final DockAxis axis;
  final int dividerIndex;
}

/// Builds the visual divider between two children of a [DockSplitNode].
typedef DockDividerBuilder =
    Widget Function(BuildContext context, DockDividerLocation location);

/// Receives logical-pixel movement for a divider's adjacent children.
typedef DockDividerDragCallback =
    void Function(DockDividerLocation location, double delta);

/// Renders the recursive dock tree without turning panels into tabs.
///
/// A horizontal split lays children out from left to right and a vertical
/// split lays them out from top to bottom. Ratios are weights, so the renderer
/// remains independent of the actual available size. The visible divider is
/// one logical pixel; when [onDividerDrag] is supplied, a separate hit target
/// is painted over it without adding layout width or height.
class DockLayoutRenderer extends StatelessWidget {
  const DockLayoutRenderer({
    super.key,
    required this.node,
    required this.panelBuilder,
    this.dividerBuilder = _defaultDivider,
    this.onDividerDrag,
    this.dividerHitExtent = 9,
  });

  final DockNode node;
  final DockPanelBuilder panelBuilder;
  final DockDividerBuilder dividerBuilder;
  final DockDividerDragCallback? onDividerDrag;
  final double dividerHitExtent;

  @override
  Widget build(BuildContext context) => _buildNode(context, node, const []);

  Widget _buildNode(BuildContext context, DockNode current, List<int> path) {
    if (current is DockPanelNode) {
      return panelBuilder(context, current.panelId);
    }
    if (current is DockSplitNode) {
      return _buildSplit(context, current, path);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSplit(
    BuildContext context,
    DockSplitNode split,
    List<int> path,
  ) {
    final children = <Widget>[];
    for (var index = 0; index < split.children.length; index++) {
      final ratio = index < split.ratios.length ? split.ratios[index] : 1.0;
      children.add(
        Expanded(
          flex: _flexFor(ratio),
          child: _buildNode(context, split.children[index], [...path, index]),
        ),
      );
      if (index < split.children.length - 1) {
        children.add(
          dividerBuilder(
            context,
            DockDividerLocation(
              splitPath: List.unmodifiable(path),
              axis: split.axis,
              dividerIndex: index,
            ),
          ),
        );
      }
    }

    final key = ValueKey('dock-split-${split.axis.name}');
    final content = split.axis == DockAxis.horizontal
        ? Row(
            key: key,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          )
        : Column(
            key: key,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );

    if (onDividerDrag == null || split.children.length < 2) return content;

    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = split.axis == DockAxis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        if (!extent.isFinite || extent <= 0) return content;
        final dividerCount = split.children.length - 1;
        final usableExtent = extent - dividerCount;
        if (usableExtent <= 0) return content;
        final ratios = _safeRatios(split.ratios, split.children.length);
        final totalRatio = ratios.fold<double>(0, (sum, ratio) => sum + ratio);
        var offset = 0.0;
        final handles = <Widget>[];
        for (var index = 0; index < split.children.length - 1; index++) {
          offset += usableExtent * ratios[index] / totalRatio;
          final location = DockDividerLocation(
            splitPath: List.unmodifiable(path),
            axis: split.axis,
            dividerIndex: index,
          );
          handles.add(
            _DockDividerHandle(
              key: ValueKey(
                'dock-divider-handle-${split.axis.name}-${path.join('-')}-$index',
              ),
              axis: split.axis,
              hitExtent: dividerHitExtent,
              onDrag: (delta) => onDividerDrag!(location, delta),
            ),
          );
          offset += 1;
        }

        var handleIndex = 0;
        offset = 0;
        final positioned = <Widget>[];
        for (var index = 0; index < split.children.length - 1; index++) {
          offset += usableExtent * ratios[index] / totalRatio;
          final handle = handles[handleIndex++];
          positioned.add(
            split.axis == DockAxis.horizontal
                ? Positioned(
                    left: offset - dividerHitExtent / 2,
                    top: 0,
                    bottom: 0,
                    width: dividerHitExtent,
                    child: handle,
                  )
                : Positioned(
                    left: 0,
                    right: 0,
                    top: offset - dividerHitExtent / 2,
                    height: dividerHitExtent,
                    child: handle,
                  ),
          );
          offset += 1;
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [content, ...positioned],
        );
      },
    );
  }

  int _flexFor(double ratio) {
    if (!ratio.isFinite || ratio <= 0) return 1;
    return (ratio * 1000).round().clamp(1, 100000);
  }

  List<double> _safeRatios(List<double> ratios, int childCount) {
    return [
      for (var index = 0; index < childCount; index++)
        index < ratios.length && ratios[index].isFinite && ratios[index] > 0
            ? ratios[index]
            : 1.0,
    ];
  }

  static Widget _defaultDivider(
    BuildContext context,
    DockDividerLocation location,
  ) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return location.axis == DockAxis.horizontal
        ? SizedBox(
            key: ValueKey(
              'dock-divider-${location.axis.name}-${location.dividerIndex}',
            ),
            width: 1,
            child: ColoredBox(color: color),
          )
        : SizedBox(
            key: ValueKey(
              'dock-divider-${location.axis.name}-${location.dividerIndex}',
            ),
            height: 1,
            child: ColoredBox(color: color),
          );
  }
}

class _DockDividerHandle extends StatelessWidget {
  const _DockDividerHandle({
    super.key,
    required this.axis,
    required this.hitExtent,
    required this.onDrag,
  });

  final DockAxis axis;
  final double hitExtent;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == DockAxis.horizontal;
    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: isHorizontal
            ? (details) => onDrag(details.delta.dx)
            : null,
        onVerticalDragUpdate: isHorizontal
            ? null
            : (details) => onDrag(details.delta.dy),
        child: Semantics(
          label: isHorizontal
              ? 'Resize docked panels horizontally'
              : 'Resize docked panels vertically',
          slider: true,
          hint: 'Use arrow keys or drag to resize adjacent panels',
          onIncrease: () => onDrag(16),
          onDecrease: () => onDrag(-16),
          child: SizedBox(
            width: isHorizontal ? hitExtent : double.infinity,
            height: isHorizontal ? double.infinity : hitExtent,
          ),
        ),
      ),
    );
  }
}
