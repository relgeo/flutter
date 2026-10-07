import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'workbench_layout_controller.dart';
import 'workbench_layout_model.dart';
import 'workbench_panel_interaction.dart';
import 'workbench_window_policy.dart';
import 'docking/dock_drop_preview.dart';
import 'docking/dock_drop_preview_overlay.dart';
import 'docking/dock_layout_adapter.dart';
import 'docking/dock_layout_renderer.dart';
import 'docking/dock_node.dart';
import 'docking/dock_tree_operations.dart';

/// Owns the workbench's high-level shell layout without owning feature state.
///
/// Feature widgets remain injected by `CADWorkbenchPage`, which keeps this
/// boundary presentational and makes the eventual composition split explicit.
class WorkbenchCompositionShell extends StatelessWidget {
  const WorkbenchCompositionShell({
    super.key,
    required this.navbar,
    this.menuBar,
    required this.editor,
    required this.viewport,
    required this.inspector,
    this.parameters,
    this.layoutController,
    this.editorFlex = 32,
    this.viewportFlex = 43,
    this.inspectorFlex = 25,
  });

  final Widget navbar;
  final Widget? menuBar;
  final Widget editor;
  final Widget viewport;
  final Widget inspector;
  final Widget? parameters;
  final WorkbenchLayoutController? layoutController;
  final int editorFlex;
  final int viewportFlex;
  final int inspectorFlex;

  @override
  Widget build(BuildContext context) {
    final body = layoutController == null
        ? _buildLegacyPanelLayout()
        : AnimatedBuilder(
            animation: layoutController!,
            builder: (context, _) =>
                _buildInteractivePanelLayout(layoutController!),
          );

    return Scaffold(
      body: Column(
        children: [
          ?menuBar,
          navbar,
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildLegacyPanelLayout() {
    final panelLayout = LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = _panelWidthFor(constraints.maxWidth);
        final panels = SizedBox(
          width: panelWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: editorFlex, child: editor),
              Expanded(flex: viewportFlex, child: viewport),
              Expanded(flex: inspectorFlex, child: inspector),
            ],
          ),
        );
        return _isCompact(constraints.maxWidth)
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: panels,
              )
            : panels;
      },
    );
    if (parameters == null) return panelLayout;
    return Column(
      children: [
        Expanded(child: panelLayout),
        SizedBox(height: 220, child: parameters),
      ],
    );
  }

  Widget _buildInteractivePanelLayout(WorkbenchLayoutController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = _panelWidthFor(constraints.maxWidth);
        final panelIds = [
          WorkbenchPanelId.editor,
          WorkbenchPanelId.preview,
          WorkbenchPanelId.inspector,
          if (parameters != null) WorkbenchPanelId.parameters,
        ];
        final dockedPanelIds = panelIds
            .where(
              (id) =>
                  controller.panel(id).visibility !=
                      WorkbenchPanelVisibility.hidden &&
                  _isSideDocked(controller.panel(id).placement),
            )
            .toList();
        final children = <Widget>[];
        final dividerIds = <WorkbenchPanelId>[];
        for (var index = 0; index < dockedPanelIds.length; index++) {
          final id = dockedPanelIds[index];
          children.add(
            _buildPanelSlot(context, id, controller, _panelWidget(id)),
          );
          if (index < dockedPanelIds.length - 1) {
            dividerIds.add(id);
            children.add(
              _WorkbenchPanelDividerVisual(
                key: ValueKey('workbench-divider-visual-${id.name}'),
              ),
            );
          }
        }

        final activeTree = _treeForShell(controller);
        final parametersInDockTree = switch (activeTree) {
          DockPanelNode panel => panel.panelId == WorkbenchPanelId.parameters,
          DockSplitNode split => split.panels.contains(
            WorkbenchPanelId.parameters,
          ),
          _ => false,
        };
        final panels = activeTree == null
            ? SizedBox(
                width: panelWidth,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                    ..._buildPanelDividerHitTargets(
                      controller,
                      dockedPanelIds,
                      dividerIds,
                      panelWidth,
                    ),
                  ],
                ),
              )
            : SizedBox(
                width: panelWidth,
                child: LayoutBuilder(
                  builder: (context, treeConstraints) => DockLayoutRenderer(
                    node: activeTree,
                    panelBuilder: (context, id) =>
                        _buildPanelSurface(context, id, controller),
                    onDividerDrag: (location, delta) {
                      final availablePixels = location.availablePixels > 0
                          ? location.availablePixels
                          : location.axis == DockAxis.horizontal
                          ? treeConstraints.maxWidth
                          : treeConstraints.maxHeight;
                      controller.resizeDockDivider(
                        location,
                        delta,
                        availablePixels,
                      );
                    },
                  ),
                ),
              );
        final main = _isCompact(constraints.maxWidth)
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: panels,
              )
            : panels;
        final parameterHeight = parametersInDockTree
            ? 0.0
            : _parametersSlotHeight(controller);
        final dividerVisible = parameters != null && parameterHeight > 0;
        final dockedBody = parameters == null
            ? main
            : Column(
                children: [
                  Expanded(child: main),
                  if (dividerVisible)
                    const _WorkbenchHorizontalDividerVisual(
                      key: ValueKey('workbench-divider-visual-parameters'),
                    ),
                  if (!parametersInDockTree)
                    _buildParametersSlot(context, controller),
                ],
              );
        return Stack(
          fit: StackFit.expand,
          children: [
            dockedBody,
            if (dividerVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: parameterHeight - 4,
                height: 8,
                child: _WorkbenchHorizontalDivider(
                  key: const ValueKey('workbench-divider-parameters'),
                  onDrag: (delta) =>
                      controller.resizeParameters(delta, constraints.maxHeight),
                ),
              ),
            // The floating layer deliberately wraps the complete workbench,
            // including Parameters. This keeps a floating panel above every
            // docked surface instead of painting it underneath the bottom
            // region.
            ..._buildFloatingPanels(
              context,
              controller,
              panelIds,
              panelWidth,
              constraints.maxHeight,
            ),
            DockDropPreviewOverlay(preview: controller.dropPreview),
          ],
        );
      },
    );
  }

  DockNode? _treeForShell(WorkbenchLayoutController controller) {
    var root = controller.dockedRoot;
    if (root == null) return null;

    final panelsToRemove = <WorkbenchPanelId>{
      for (final id in WorkbenchPanelId.values)
        if (controller.panel(id).visibility == WorkbenchPanelVisibility.hidden)
          id,
    };
    if (parameters == null) panelsToRemove.add(WorkbenchPanelId.parameters);

    for (final id in panelsToRemove) {
      final contains = switch (root) {
        DockPanelNode panel => panel.panelId == id,
        DockSplitNode split => split.panels.contains(id),
        _ => false,
      };
      if (!contains) continue;
      try {
        root = DockTreeOperations.remove(root: root!, panel: id);
      } on Object {
        // A transient visibility change must not make the shell disappear.
      }
    }
    return root;
  }

  double _parametersSlotHeight(WorkbenchLayoutController controller) {
    final state = controller.panel(WorkbenchPanelId.parameters);
    if (parameters == null ||
        state.placement != WorkbenchPanelPlacement.bottom ||
        state.visibility == WorkbenchPanelVisibility.hidden) {
      return 0;
    }
    return state.bounds.height ?? 220;
  }

  List<Widget> _buildPanelDividerHitTargets(
    WorkbenchLayoutController controller,
    List<WorkbenchPanelId> panelIds,
    List<WorkbenchPanelId> dividerIds,
    double panelWidth,
  ) {
    if (dividerIds.isEmpty) return const [];
    final totalRatio = panelIds.fold<double>(0, (sum, id) {
      return sum +
          (controller.layout.splitRatios[controller
                  .panel(id)
                  .placement
                  .storageKey] ??
              1 / 3);
    });
    final availableWidth = panelWidth - dividerIds.length.toDouble();
    var x = 0.0;
    final targets = <Widget>[];
    for (final id in panelIds) {
      final state = controller.panel(id);
      final ratio =
          controller.layout.splitRatios[state.placement.storageKey] ?? 1 / 3;
      x += availableWidth * ratio / totalRatio;
      if (dividerIds.contains(id)) {
        final next = panelIds[panelIds.indexOf(id) + 1];
        targets.add(
          Positioned(
            left: x - 4,
            top: 0,
            bottom: 0,
            width: 9,
            child: _WorkbenchPanelDivider(
              key: ValueKey('workbench-divider-${id.name}'),
              onDrag: (delta) =>
                  controller.resizeBoundary(id, next, delta, availableWidth),
            ),
          ),
        );
        x += 1;
      }
    }
    return targets;
  }

  Widget _buildParametersSlot(
    BuildContext context,
    WorkbenchLayoutController controller,
  ) {
    final state = controller.panel(WorkbenchPanelId.parameters);
    if (parameters == null ||
        state.placement != WorkbenchPanelPlacement.bottom) {
      return const SizedBox.shrink();
    }
    if (state.visibility == WorkbenchPanelVisibility.hidden) {
      return const SizedBox.shrink();
    }
    return SizedBox(height: state.bounds.height ?? 220, child: parameters);
  }

  List<Widget> _buildFloatingPanels(
    BuildContext context,
    WorkbenchLayoutController controller,
    List<WorkbenchPanelId> panelIds,
    double canvasWidth,
    double canvasHeight,
  ) {
    final floatingIds = panelIds
        .where(
          (id) =>
              controller.panel(id).visibility !=
                  WorkbenchPanelVisibility.hidden &&
              controller.panel(id).placement ==
                  WorkbenchPanelPlacement.floating,
        )
        .toList();
    final order = controller.layout.floatingOrder;
    floatingIds.sort((a, b) {
      final aIndex = order.indexOf(a);
      final bIndex = order.indexOf(b);
      return (aIndex < 0 ? order.length : aIndex).compareTo(
        bIndex < 0 ? order.length : bIndex,
      );
    });
    return [
      for (final id in floatingIds)
        _buildFloatingPanel(context, controller, id, canvasWidth, canvasHeight),
    ];
  }

  Widget _buildFloatingPanel(
    BuildContext context,
    WorkbenchLayoutController controller,
    WorkbenchPanelId id,
    double canvasWidth,
    double canvasHeight,
  ) {
    final state = controller.panel(id);
    final bounds = controller.layout.floatingBounds[id] ?? state.bounds;
    final width = bounds.width ?? 320;
    final height = bounds.height ?? 260;
    final left = (bounds.left ?? 24).clamp(
      0.0,
      (canvasWidth - width).clamp(0.0, double.infinity),
    );
    final top = (bounds.top ?? 24).clamp(
      0.0,
      (canvasHeight - height).clamp(0.0, double.infinity),
    );
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape &&
              controller.isFloatingPanelDragActive(id)) {
            controller.cancelFloatingPanelDrag(id);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        onFocusChange: (focused) {
          if (focused) controller.focusFloatingPanel(id);
        },
        child: Builder(
          builder: (focusContext) => GestureDetector(
            onTap: () {
              Focus.of(focusContext).requestFocus();
              controller.focusFloatingPanel(id);
            },
            child: Material(
              key: ValueKey('floating-panel-${id.name}'),
              elevation: 16,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Semantics(
                    container: true,
                    label: '${id.name} ${state.placement.name} panel',
                    child: WorkbenchPanelInteractionScope(
                      isFloating: true,
                      onDragStart: () {
                        controller.beginFloatingPanelDrag(id);
                        Focus.of(focusContext).requestFocus();
                        controller.focusFloatingPanel(id);
                      },
                      onDragUpdate: (details) {
                        if (!controller.isFloatingPanelDragActive(id)) return;
                        controller.moveFloatingPanel(
                          id,
                          dx: details.delta.dx,
                          dy: details.delta.dy,
                          canvasWidth: canvasWidth,
                          canvasHeight: canvasHeight,
                        );
                        final renderObject = context.findRenderObject();
                        if (renderObject is RenderBox) {
                          _updateDropPreview(
                            controller,
                            id,
                            pointer: renderObject.globalToLocal(
                              details.globalPosition,
                            ),
                            canvasWidth: canvasWidth,
                            canvasHeight: canvasHeight,
                          );
                        } else {
                          controller.clearDropPreview();
                        }
                      },
                      onDragEnd: () {
                        final preview = controller.dropPreview;
                        if (preview != null) {
                          controller.dockFloatingPanelFromPreview(id, preview);
                        }
                        controller.endFloatingPanelDrag(id);
                        controller.clearDropPreview();
                      },
                      onDragCancel: () =>
                          controller.cancelFloatingPanelDrag(id),
                      child: _panelWidget(id),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _FloatingPanelResizeHandle(
                      onDrag: (delta) => controller.resizeFloatingPanel(
                        id,
                        dx: delta.dx,
                        dy: delta.dy,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateDropPreview(
    WorkbenchLayoutController controller,
    WorkbenchPanelId sourcePanel, {
    required Offset pointer,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    final root =
        controller.dockedRoot ??
        DockLayoutAdapter.fromPlacementLayout(controller.layout);
    if (root == null || canvasWidth <= 0 || canvasHeight <= 0) {
      controller.clearDropPreview();
      return;
    }

    DockDropPreview? preview;
    for (final target in WorkbenchPanelId.values) {
      final containsTarget = switch (root) {
        DockPanelNode panel => panel.panelId == target,
        DockSplitNode split => split.panels.contains(target),
        _ => false,
      };
      if (target == sourcePanel || !containsTarget) continue;
      preview = DockDropPreviewCalculator.forPointer(
        root: root,
        canvasSize: Size(canvasWidth, canvasHeight),
        pointer: pointer,
        sourcePanel: sourcePanel,
        targetPanel: target,
        minimumPanelSize: Size(
          math.max(
            controller.panel(sourcePanel).bounds.minWidth ?? 120,
            controller.panel(target).bounds.minWidth ?? 120,
          ),
          math.max(
            controller.panel(sourcePanel).bounds.minHeight ?? 120,
            controller.panel(target).bounds.minHeight ?? 120,
          ),
        ),
      );
      if (preview != null) break;
    }
    controller.setDropPreview(preview);
  }

  bool _isSideDocked(WorkbenchPanelPlacement placement) =>
      placement == WorkbenchPanelPlacement.left ||
      placement == WorkbenchPanelPlacement.center ||
      placement == WorkbenchPanelPlacement.right;

  Widget _buildPanelSlot(
    BuildContext context,
    WorkbenchPanelId id,
    WorkbenchLayoutController controller,
    Widget child,
  ) {
    final state = controller.panel(id);
    final ratio =
        controller.layout.splitRatios[state.placement.storageKey] ?? 1 / 3;
    return Expanded(
      flex: (ratio * 1000).round().clamp(1, 1000),
      child: Focus(
        autofocus: controller.focusRequest == id,
        onFocusChange: (focused) {
          if (focused) controller.clearPanelFocusRequest(id);
        },
        child: WorkbenchPanelInteractionScope(
          isFloating: false,
          child: KeyedSubtree(
            key: ValueKey('workbench-panel-${id.name}'),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _panelWidget(WorkbenchPanelId id) {
    switch (id) {
      case WorkbenchPanelId.editor:
        return editor;
      case WorkbenchPanelId.preview:
        return viewport;
      case WorkbenchPanelId.inspector:
        return inspector;
      case WorkbenchPanelId.parameters:
        return parameters ?? const SizedBox.shrink();
    }
  }

  Widget _buildPanelSurface(
    BuildContext context,
    WorkbenchPanelId id,
    WorkbenchLayoutController controller,
  ) {
    return Focus(
      autofocus: controller.focusRequest == id,
      onFocusChange: (focused) {
        if (focused) controller.clearPanelFocusRequest(id);
      },
      child: WorkbenchPanelInteractionScope(
        isFloating: false,
        child: KeyedSubtree(
          key: ValueKey('workbench-panel-${id.name}'),
          child: _panelWidget(id),
        ),
      ),
    );
  }

  bool _isCompact(double width) =>
      WorkbenchWindowPolicy.layoutModeForWidth(width) ==
      WorkbenchLayoutMode.compact;

  double _panelWidthFor(double width) =>
      _isCompact(width) && width < WorkbenchWindowPolicy.minimumWindowSize.width
      ? WorkbenchWindowPolicy.minimumWindowSize.width
      : width;
}

class _FloatingPanelResizeHandle extends StatelessWidget {
  const _FloatingPanelResizeHandle({required this.onDrag});

  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final delta = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowLeft => const Offset(-16, 0),
          LogicalKeyboardKey.arrowRight => const Offset(16, 0),
          LogicalKeyboardKey.arrowUp => const Offset(0, -16),
          LogicalKeyboardKey.arrowDown => const Offset(0, 16),
          _ => null,
        };
        if (delta == null) return KeyEventResult.ignored;
        onDrag(delta);
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => onDrag(details.delta),
          child: Semantics(
            key: const Key('resize-floating-workbench-panel'),
            label: 'Resize floating workbench panel',
            slider: true,
            hint: 'Increase or decrease panel size',
            onIncrease: () => onDrag(const Offset(16, 16)),
            onDecrease: () => onDrag(const Offset(-16, -16)),
            child: SizedBox(
              width: 20,
              height: 20,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.drag_handle,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkbenchPanelDivider extends StatelessWidget {
  const _WorkbenchPanelDivider({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final delta = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowLeft => -16.0,
          LogicalKeyboardKey.arrowRight => 16.0,
          _ => null,
        };
        if (delta == null) return KeyEventResult.ignored;
        onDrag(delta);
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
          child: Semantics(
            label: 'Resize workbench panels',
            slider: true,
            hint: 'Increase or decrease the left panel width',
            onIncrease: () => onDrag(16),
            onDecrease: () => onDrag(-16),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _WorkbenchPanelDividerVisual extends StatelessWidget {
  const _WorkbenchPanelDividerVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      child: ColoredBox(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _WorkbenchHorizontalDivider extends StatelessWidget {
  const _WorkbenchHorizontalDivider({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final delta = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowUp => -16.0,
          LogicalKeyboardKey.arrowDown => 16.0,
          _ => null,
        };
        if (delta == null) return KeyEventResult.ignored;
        onDrag(delta);
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
          child: Semantics(
            label: 'Resize parameters panel',
            slider: true,
            hint: 'Increase or decrease the parameters panel height',
            onIncrease: () => onDrag(-16),
            onDecrease: () => onDrag(16),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _WorkbenchHorizontalDividerVisual extends StatelessWidget {
  const _WorkbenchHorizontalDividerVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: ColoredBox(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}
