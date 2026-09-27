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
        ];
        final visiblePanelIds = panelIds
            .where(
              (id) =>
                  controller.panel(id).visibility !=
                  WorkbenchPanelVisibility.hidden,
            )
            .toList();
        final children = <Widget>[];
        for (var index = 0; index < visiblePanelIds.length; index++) {
          final id = visiblePanelIds[index];
          children.add(
            _buildPanelSlot(context, id, controller, _panelWidget(id)),
          );
          if (index < visiblePanelIds.length - 1) {
            final next = visiblePanelIds[index + 1];
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
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
    return SizedBox(height: 220, child: parameters);
  }

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
