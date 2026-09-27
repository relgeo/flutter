import 'package:flutter/material.dart';
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
        child: Semantics(
          label: 'parameters panel collapsed',
          button: true,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Text('PARAMETERS')),
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
    return [
      for (final id in panelIds)
        if (controller.panel(id).visibility !=
                WorkbenchPanelVisibility.hidden &&
            (controller.panel(id).placement ==
                    WorkbenchPanelPlacement.floating ||
                controller.panel(id).placement ==
                    WorkbenchPanelPlacement.overlay))
          _buildFloatingPanel(
            context,
            controller,
            id,
            canvasWidth,
            canvasHeight,
          ),
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
      child: GestureDetector(
        onPanUpdate: (details) => controller.moveFloatingPanel(
          id,
          dx: details.delta.dx,
          dy: details.delta.dy,
        ),
        child: Material(
          elevation: state.placement == WorkbenchPanelPlacement.overlay ? 8 : 4,
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            label: '${id.name} ${state.placement.name} panel',
            child: _panelWidget(id),
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
        child: Semantics(
          label: '${id.name} panel collapsed',
          button: true,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: RotatedBox(
              quarterTurns: 3,
              child: Center(child: Text(id.name.toUpperCase())),
            ),
          ),
        ),
      );
    }

    final ratio =
        controller.layout.splitRatios[state.placement.storageKey] ?? 1 / 3;
    return Expanded(
      flex: (ratio * 1000).round().clamp(1, 1000),
      child: KeyedSubtree(
        key: ValueKey('workbench-panel-${id.name}'),
        child: child,
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

class _WorkbenchPanelDivider extends StatelessWidget {
  const _WorkbenchPanelDivider({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
    );
  }
}

class _WorkbenchHorizontalDivider extends StatelessWidget {
  const _WorkbenchHorizontalDivider({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
    );
  }
}
