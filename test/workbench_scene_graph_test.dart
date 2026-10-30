import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/geometry/types.dart';
import 'package:relgeo_flutter/src/ui/workbench_scene_graph.dart';

ResolvedScene _scene() {
  final base = ResolvedRect(
    id: 'base',
    meta: Meta(),
    x: 10,
    y: 20,
    width: 40,
    height: 30,
  );
  final group = ResolvedGroup(
    id: 'group',
    meta: Meta(),
    children: const ['base'],
  );
  return ResolvedScene(
    unit: LengthUnit.mm,
    objects: {'base': base, 'group': group},
    parameters: const {},
    values: const {},
    bbox: const BoundingBox(x: 10, y: 20, width: 40, height: 30),
  );
}

void main() {
  test('resolved graph exposes stable group relationships', () {
    final graph = WorkbenchSceneGraph.fromScene(_scene());

    expect(graph.nodes.map((node) => node.id), ['base', 'group']);
    expect(graph.nodes.last.dependencies, ['base']);
    expect(graph.nodes.last.type, 'group');
  });

  test('selection hit testing selects visible objects and respects roles', () {
    final scene = _scene();
    final selection = WorkbenchSelectionController();
    addTearDown(selection.dispose);

    expect(selection.hitTest(scene, (x: 20, y: 30)), 'group');
    expect(selection.hitTest(scene, (x: 200, y: 200)), isNull);
    expect(
      selection.hitTest(scene, (x: 20, y: 30), hiddenRoles: {'final'}),
      isNull,
    );

    selection.select('base');
    expect(selection.selectedObjectId, 'base');
    selection.clear();
    expect(selection.selectedObjectId, isNull);
  });
}
