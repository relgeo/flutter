import 'package:flutter/material.dart';
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
    this.editorFlex = 32,
    this.viewportFlex = 43,
    this.inspectorFlex = 25,
  });

  final Widget navbar;
  final Widget? menuBar;
  final Widget editor;
  final Widget viewport;
  final Widget inspector;
  final int editorFlex;
  final int viewportFlex;
  final int inspectorFlex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ?menuBar,
          navbar,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact =
                    WorkbenchWindowPolicy.layoutModeForWidth(
                      constraints.maxWidth,
                    ) ==
                    WorkbenchLayoutMode.compact;
                final panelWidth =
                    isCompact &&
                        constraints.maxWidth <
                            WorkbenchWindowPolicy.minimumWindowSize.width
                    ? WorkbenchWindowPolicy.minimumWindowSize.width
                    : constraints.maxWidth;

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

                return isCompact
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: panels,
                      )
                    : panels;
              },
            ),
          ),
        ],
      ),
    );
  }
}
