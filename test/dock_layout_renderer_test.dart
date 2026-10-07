import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_layout_renderer.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';

void main() {
  Widget host(DockNode node) {
    return MaterialApp(
      home: SizedBox(
        width: 800,
        height: 600,
        child: DockLayoutRenderer(
          node: node,
          panelBuilder: (context, panelId) => ColoredBox(
            key: ValueKey('dock-panel-${panelId.name}'),
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }

  testWidgets('renders a horizontal split as independent panel surfaces', (
    tester,
  ) async {
    final node = DockSplitNode(
      axis: DockAxis.horizontal,
      children: const [
        DockPanelNode(WorkbenchPanelId.editor),
        DockPanelNode(WorkbenchPanelId.preview),
      ],
      ratios: const [0.35, 0.65],
    );

    await tester.pumpWidget(host(node));

    expect(find.byKey(const ValueKey('dock-split-horizontal')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-panel-editor')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-panel-preview')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dock-divider-horizontal-0')),
      findsOneWidget,
    );
  });

  testWidgets('renders nested vertical splits without creating tabs', (
    tester,
  ) async {
    final node = DockSplitNode(
      axis: DockAxis.horizontal,
      children: [
        const DockPanelNode(WorkbenchPanelId.editor),
        DockSplitNode(
          axis: DockAxis.vertical,
          children: const [
            DockPanelNode(WorkbenchPanelId.preview),
            DockPanelNode(WorkbenchPanelId.inspector),
          ],
          ratios: const [0.6, 0.4],
        ),
      ],
      ratios: const [0.4, 0.6],
    );

    await tester.pumpWidget(host(node));

    expect(find.byKey(const ValueKey('dock-split-horizontal')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-split-vertical')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-panel-editor')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-panel-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-panel-inspector')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dock-divider-vertical-0')),
      findsOneWidget,
    );
  });

  testWidgets('uses a custom divider builder for future resize interaction', (
    tester,
  ) async {
    final node = DockSplitNode(
      axis: DockAxis.vertical,
      children: const [
        DockPanelNode(WorkbenchPanelId.preview),
        DockPanelNode(WorkbenchPanelId.parameters),
      ],
      ratios: const [0.75, 0.25],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DockLayoutRenderer(
          node: node,
          panelBuilder: (context, panelId) =>
              SizedBox(key: ValueKey('panel-${panelId.name}')),
          dividerBuilder: (context, location) => SizedBox(
            key: ValueKey(
              'custom-divider-${location.axis.name}-${location.dividerIndex}',
            ),
            height: location.axis == DockAxis.vertical ? 9 : null,
            width: location.axis == DockAxis.horizontal ? 9 : null,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('custom-divider-vertical-0')),
      findsOneWidget,
    );
  });

  testWidgets('keeps a one-pixel visual divider and separate resize hit area', (
    tester,
  ) async {
    DockDividerLocation? received;
    double? delta;
    final node = DockSplitNode(
      axis: DockAxis.horizontal,
      children: const [
        DockPanelNode(WorkbenchPanelId.editor),
        DockPanelNode(WorkbenchPanelId.preview),
      ],
      ratios: const [0.5, 0.5],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 400,
          child: DockLayoutRenderer(
            node: node,
            panelBuilder: (context, panelId) => const SizedBox.expand(),
            onDividerDrag: (location, value) {
              received = location;
              delta = (delta ?? 0) + value;
            },
          ),
        ),
      ),
    );

    final visual = tester.getSize(
      find.byKey(const ValueKey('dock-divider-horizontal-0')),
    );
    expect(visual.width, 1);
    await tester.drag(
      find.byKey(const ValueKey('dock-divider-handle-horizontal--0')),
      const Offset(24, 0),
    );
    expect(received?.axis, DockAxis.horizontal);
    expect(received?.dividerIndex, 0);
    expect(delta, 24);
  });

  testWidgets('exposes dock splitters as operable semantic sliders', (
    tester,
  ) async {
    final deltas = <double>[];
    final node = DockSplitNode(
      axis: DockAxis.vertical,
      children: const [
        DockPanelNode(WorkbenchPanelId.preview),
        DockPanelNode(WorkbenchPanelId.inspector),
      ],
      ratios: const [0.6, 0.4],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 500,
          height: 500,
          child: DockLayoutRenderer(
            node: node,
            panelBuilder: (context, panelId) => const SizedBox.expand(),
            onDividerDrag: (_, delta) => deltas.add(delta),
          ),
        ),
      ),
    );

    final divider = find.bySemanticsLabel('Resize docked panels vertically');
    expect(divider, findsOneWidget);
    final semanticsNode = tester.semantics.find(divider);
    semanticsNode.owner!.performAction(
      semanticsNode.id,
      ui.SemanticsAction.increase,
    );
    expect(deltas, [16]);
  });
}
