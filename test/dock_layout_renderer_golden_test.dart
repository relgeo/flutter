@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_layout_renderer.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';

const _panelColors = <WorkbenchPanelId, Color>{
  WorkbenchPanelId.editor: Color(0xFF172554),
  WorkbenchPanelId.preview: Color(0xFF134E4A),
  WorkbenchPanelId.inspector: Color(0xFF3F3F46),
  WorkbenchPanelId.parameters: Color(0xFF713F12),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> verifyTreeGolden(
    WidgetTester tester, {
    required DockNode root,
    required Size size,
    required String name,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFF090D17),
          body: DockLayoutRenderer(
            node: root,
            panelBuilder: (context, panelId) => ColoredBox(
              key: ValueKey('golden-panel-${panelId.name}'),
              color: _panelColors[panelId]!,
              child: Center(
                child: Text(
                  panelId.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/dock_tree_$name.png'),
    );
  }

  testWidgets('standard horizontal tree golden', (tester) async {
    await verifyTreeGolden(
      tester,
      size: const Size(1200, 720),
      name: 'standard',
      root: DockSplitNode(
        axis: DockAxis.horizontal,
        children: const [
          DockPanelNode(WorkbenchPanelId.editor),
          DockPanelNode(WorkbenchPanelId.preview),
          DockPanelNode(WorkbenchPanelId.inspector),
        ],
        ratios: const [0.32, 0.43, 0.25],
      ),
    );
  });

  testWidgets('nested split tree golden', (tester) async {
    await verifyTreeGolden(
      tester,
      size: const Size(1200, 720),
      name: 'nested',
      root: DockSplitNode(
        axis: DockAxis.horizontal,
        children: [
          const DockPanelNode(WorkbenchPanelId.editor),
          DockSplitNode(
            axis: DockAxis.vertical,
            children: const [
              DockPanelNode(WorkbenchPanelId.preview),
              DockPanelNode(WorkbenchPanelId.inspector),
            ],
            ratios: const [0.62, 0.38],
          ),
        ],
        ratios: const [0.38, 0.62],
      ),
    );
  });

  testWidgets('compact vertical tree golden', (tester) async {
    await verifyTreeGolden(
      tester,
      size: const Size(420, 780),
      name: 'compact',
      root: DockSplitNode(
        axis: DockAxis.vertical,
        children: const [
          DockPanelNode(WorkbenchPanelId.editor),
          DockPanelNode(WorkbenchPanelId.preview),
          DockPanelNode(WorkbenchPanelId.inspector),
        ],
        ratios: const [0.38, 0.40, 0.22],
      ),
    );
  });
}
