import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_scene_graph.dart';
import 'package:relgeo_flutter/src/ui/workbench_scene_graph_panel.dart';
import 'package:relgeo_flutter/src/ui/workbench_visual_profile.dart';

void main() {
  testWidgets('graph nodes expose selection semantics and keyboard activation',
      (tester) async {
    String? selected;
    final graph = const WorkbenchSceneGraph([
      WorkbenchSceneGraphNode(
        id: 'panel',
        type: 'rect',
        dependencies: <String>[],
      ),
      WorkbenchSceneGraphNode(
        id: 'group',
        type: 'group',
        dependencies: <String>['panel'],
      ),
    ]);
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchSceneGraphPanel(
            graph: graph,
            selectedObjectId: selected,
            visualProfile: WorkbenchVisualProfile.cad,
            onSelectObject: (id) => selected = id,
            onClose: () {},
          ),
        ),
      ),
    );

    final panelSemantics = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Object panel',
      ),
    );
    expect(panelSemantics.value, 'rect, no dependencies');
    expect(
      panelSemantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );

    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, 'panel');
    semanticsHandle.dispose();
  });
}
