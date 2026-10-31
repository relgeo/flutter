import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_scene_graph.dart';
import 'package:relgeo_flutter/src/ui/workbench_scene_graph_panel.dart';
import 'package:relgeo_flutter/src/ui/workbench_visual_profile.dart';

void main() {
  testWidgets('graph panel exposes selectable object semantics', (
    tester,
  ) async {
    final graph = const WorkbenchSceneGraph([
      WorkbenchSceneGraphNode(
        id: 'group',
        type: 'group',
        dependencies: ['base'],
      ),
    ]);
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchSceneGraphPanel(
          graph: graph,
          selectedObjectId: null,
          visualProfile: WorkbenchVisualProfile.cad,
          onSelectObject: (value) => selected = value,
          onClose: () {},
        ),
      ),
    );

    expect(find.byType(WorkbenchSceneGraphPanel), findsOneWidget);
    expect(find.byTooltip('Close dependency graph'), findsOneWidget);
    await tester.tap(find.text('group'));
    expect(selected, 'group');
    expect(find.text('group'), findsOneWidget);
  });
}
