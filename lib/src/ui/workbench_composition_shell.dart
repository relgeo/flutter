import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'workbench_layout_controller.dart';
import 'workbench_layout_model.dart';
import 'workbench_window_policy.dart';

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
        for (var index = 0; index < dockedPanelIds.length; index++) {
          final id = dockedPanelIds[index];
          children.add(
            _buildPanelSlot(context, id, controller, _panelWidget(id)),
          );
          if (index < dockedPanelIds.length - 1) {
            final next = dockedPanelIds[index + 1];
            children.add(
              _WorkbenchPanelDivider(
                key: ValueKey('workbench-divider-${id.name}'),
                onDrag: (delta) =>
                    controller.resizeBoundary(id, next, delta, panelWidth),
              ),
            );
          }
        }

        final panels = SizedBox(
          width: panelWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
              ..._buildFloatingPanels(
                context,
                controller,
                panelIds,
                panelWidth,
                constraints.maxHeight,
              ),
            ],
          ),
        );
        final main = _isCompact(constraints.maxWidth)
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: panels,
              )
            : panels;
        if (parameters == null) return main;
        return Column(
          children: [
            Expanded(child: main),
            if (controller.panel(WorkbenchPanelId.parameters).visibility !=
                    WorkbenchPanelVisibility.hidden &&
                controller.panel(WorkbenchPanelId.parameters).visibility !=
                    WorkbenchPanelVisibility.collapsed)
              _WorkbenchHorizontalDivider(
                key: const ValueKey('workbench-divider-parameters'),
                onDrag: (delta) =>
                    controller.resizeParameters(delta, constraints.maxHeight),
              ),
            _buildParametersSlot(context, controller),
          ],
        );
      },
    );
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
    if (state.visibility == WorkbenchPanelVisibility.collapsed) {
      return SizedBox(
        height: 44,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.toggleCollapsed(WorkbenchPanelId.parameters),
          child: Semantics(
            label: 'parameters panel collapsed',
            button: true,
            onTap: () =>
                controller.toggleCollapsed(WorkbenchPanelId.parameters),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Text('PARAMETERS')),
            ),
          ),
        ),
      );
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
              (controller.panel(id).placement ==
                      WorkbenchPanelPlacement.floating ||
                  controller.panel(id).placement ==
                      WorkbenchPanelPlacement.overlay),
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
    final isCollapsed = state.visibility == WorkbenchPanelVisibility.collapsed;
    final width = isCollapsed ? 44.0 : bounds.width ?? 320;
    final height = isCollapsed ? 44.0 : bounds.height ?? 260;
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
        onFocusChange: (focused) {
          if (focused) controller.focusFloatingPanel(id);
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape &&
              state.placement == WorkbenchPanelPlacement.overlay) {
            controller.setPanelVisibility(id, WorkbenchPanelVisibility.hidden);
            node.unfocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (focusContext) => GestureDetector(
            onTap: () {
              Focus.of(focusContext).requestFocus();
              controller.focusFloatingPanel(id);
              if (isCollapsed) controller.toggleCollapsed(id);
            },
            onPanStart: (_) {
              Focus.of(focusContext).requestFocus();
              controller.focusFloatingPanel(id);
            },
            onPanUpdate: (details) {
              controller.moveFloatingPanel(
                id,
                dx: details.delta.dx,
                dy: details.delta.dy,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
              );
              // Dock as soon as the panel crosses a drop zone. A state update
              // during a drag can dispose this floating layer, so keeping the
              // detection in the update path is more reliable than relying
              // only on a final gesture callback.
              controller.dockFloatingPanelIfDropped(
                id,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
              );
            },
            onPanEnd: (_) => controller.dockFloatingPanelIfDropped(
              id,
              canvasWidth: canvasWidth,
              canvasHeight: canvasHeight,
            ),
            child: Material(
              elevation: state.placement == WorkbenchPanelPlacement.overlay
                  ? 8
                  : 4,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Semantics(
                    label: '${id.name} ${state.placement.name} panel',
                    button: isCollapsed,
                    onTap: isCollapsed
                        ? () => controller.toggleCollapsed(id)
                        : null,
                    child: isCollapsed
                        ? ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Center(child: Text(id.name.toUpperCase())),
                          )
                        : _panelWidget(id),
                  ),
                  if (!isCollapsed)
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
                  if (!isCollapsed &&
                      state.placement == WorkbenchPanelPlacement.overlay)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: IconButton(
                        key: ValueKey('close-overlay-${id.name}'),
                        tooltip: 'Close ${id.name} overlay',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => controller.setPanelVisibility(
                          id,
                          WorkbenchPanelVisibility.hidden,
                        ),
                        icon: const Icon(Icons.close, size: 16),
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
    if (state.visibility == WorkbenchPanelVisibility.collapsed) {
      return SizedBox(
        width: 44,
        child: Focus(
          autofocus: controller.focusRequest == id,
          onFocusChange: (focused) {
            if (focused) controller.clearPanelFocusRequest(id);
          },
          child: Semantics(
            label: '${id.name} panel collapsed',
            button: true,
            onTap: () => controller.toggleCollapsed(id),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.toggleCollapsed(id),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(child: Text(id.name.toUpperCase())),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final ratio =
        controller.layout.splitRatios[state.placement.storageKey] ?? 1 / 3;
    return Expanded(
      flex: (ratio * 1000).round().clamp(1, 1000),
      child: Focus(
        autofocus: controller.focusRequest == id,
        onFocusChange: (focused) {
          if (focused) controller.clearPanelFocusRequest(id);
        },
        child: KeyedSubtree(
          key: ValueKey('workbench-panel-${id.name}'),
          child: child,
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
            label: 'Resize floating workbench panel',
            slider: true,
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
            child: SizedBox(
              width: 8,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ),
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
            child: SizedBox(
              height: 8,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
