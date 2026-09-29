import 'dart:ui';

import '../workbench_layout_model.dart';
import 'dock_node.dart';

enum DockDropPreviewOrientation { horizontal, vertical, none }

/// Immutable preview for a possible docking operation.
class DockDropPreview {
  const DockDropPreview({
    required this.sourcePanel,
    required this.targetPanel,
    required this.targetPath,
    required this.targetRect,
    required this.rect,
    required this.zone,
    required this.orientation,
    required this.isValid,
  });

  final WorkbenchPanelId sourcePanel;
  final WorkbenchPanelId targetPanel;
  final List<int> targetPath;
  final Rect targetRect;
  final Rect rect;
  final DockZone zone;
  final DockDropPreviewOrientation orientation;
  final bool isValid;
}

/// Calculates docking zones from a tree and a pointer position.
///
/// This calculator has no widget or controller mutation. The caller can show
/// [DockDropPreview.rect] during a drag and commit a tree operation only after
/// the gesture ends on a valid preview.
class DockDropPreviewCalculator {
  const DockDropPreviewCalculator._();

  static DockDropPreview? forPointer({
    required DockNode root,
    required Size canvasSize,
    required Offset pointer,
    required WorkbenchPanelId sourcePanel,
    required WorkbenchPanelId targetPanel,
    double dividerThickness = 1,
    double edgeFraction = 0.25,
    Size minimumPanelSize = const Size(120, 120),
    DockAxis centerAxis = DockAxis.vertical,
  }) {
    if (sourcePanel == targetPanel ||
        !canvasSize.width.isFinite ||
        !canvasSize.height.isFinite ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        !edgeFraction.isFinite ||
        edgeFraction <= 0 ||
        edgeFraction >= 0.5 ||
        !minimumPanelSize.width.isFinite ||
        !minimumPanelSize.height.isFinite ||
        minimumPanelSize.width <= 0 ||
        minimumPanelSize.height <= 0) {
      return null;
    }

    final target = _findPanelRect(
      root,
      targetPanel,
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      dividerThickness,
    );
    if (target == null || !target.rect.contains(pointer)) return null;
    final targetRect = target.rect;

    final edgeWidth = targetRect.width * edgeFraction;
    final edgeHeight = targetRect.height * edgeFraction;
    final horizontalEdge = pointer.dx < targetRect.left + edgeWidth
        ? DockZone.left
        : pointer.dx > targetRect.right - edgeWidth
        ? DockZone.right
        : null;
    final verticalEdge = pointer.dy < targetRect.top + edgeHeight
        ? DockZone.top
        : pointer.dy > targetRect.bottom - edgeHeight
        ? DockZone.bottom
        : null;
    final zone = horizontalEdge ?? verticalEdge ?? DockZone.center;
    final orientation = switch (zone) {
      DockZone.left || DockZone.right => DockDropPreviewOrientation.horizontal,
      DockZone.top || DockZone.bottom => DockDropPreviewOrientation.vertical,
      DockZone.center => DockDropPreviewOrientation.none,
    };
    final rect = switch (zone) {
      DockZone.left => Rect.fromLTRB(
        targetRect.left,
        targetRect.top,
        targetRect.center.dx,
        targetRect.bottom,
      ),
      DockZone.right => Rect.fromLTRB(
        targetRect.center.dx,
        targetRect.top,
        targetRect.right,
        targetRect.bottom,
      ),
      DockZone.top => Rect.fromLTRB(
        targetRect.left,
        targetRect.top,
        targetRect.right,
        targetRect.center.dy,
      ),
      DockZone.bottom => Rect.fromLTRB(
        targetRect.left,
        targetRect.center.dy,
        targetRect.right,
        targetRect.bottom,
      ),
      DockZone.center => targetRect.deflate(4),
    };
    final isLargeEnough = _isLargeEnough(
      targetRect,
      zone,
      minimumPanelSize,
      centerAxis,
    );
    return DockDropPreview(
      sourcePanel: sourcePanel,
      targetPanel: targetPanel,
      targetPath: target.path,
      targetRect: targetRect,
      rect: rect,
      zone: zone,
      orientation: orientation,
      isValid: isLargeEnough,
    );
  }

  static bool _isLargeEnough(
    Rect target,
    DockZone zone,
    Size minimum,
    DockAxis centerAxis,
  ) {
    final horizontal = switch (zone) {
      DockZone.left || DockZone.right => true,
      DockZone.top || DockZone.bottom => false,
      DockZone.center => centerAxis == DockAxis.horizontal,
    };
    final childWidth = horizontal ? target.width / 2 : target.width;
    final childHeight = horizontal ? target.height : target.height / 2;
    return childWidth >= minimum.width && childHeight >= minimum.height;
  }

  static _PanelRect? _findPanelRect(
    DockNode node,
    WorkbenchPanelId target,
    Rect rect,
    double dividerThickness, [
    List<int> path = const [],
  ]) {
    if (node is DockPanelNode) {
      return node.panelId == target ? _PanelRect(rect, path) : null;
    }
    if (node is! DockSplitNode || node.children.isEmpty) return null;

    final count = node.children.length;
    final extent = node.axis == DockAxis.horizontal ? rect.width : rect.height;
    final usable = extent - dividerThickness * (count - 1);
    if (usable <= 0) return null;
    final ratios = [
      for (var index = 0; index < count; index++)
        index < node.ratios.length &&
                node.ratios[index].isFinite &&
                node.ratios[index] > 0
            ? node.ratios[index]
            : 1.0,
    ];
    final total = ratios.fold<double>(0, (sum, ratio) => sum + ratio);
    var offset = node.axis == DockAxis.horizontal ? rect.left : rect.top;
    for (var index = 0; index < count; index++) {
      final size = usable * ratios[index] / total;
      final childRect = node.axis == DockAxis.horizontal
          ? Rect.fromLTWH(offset, rect.top, size, rect.height)
          : Rect.fromLTWH(rect.left, offset, rect.width, size);
      final found = _findPanelRect(
        node.children[index],
        target,
        childRect,
        dividerThickness,
        [...path, index],
      );
      if (found != null) return found;
      offset += size + dividerThickness;
    }
    return null;
  }
}

class _PanelRect {
  const _PanelRect(this.rect, this.path);

  final Rect rect;
  final List<int> path;
}
