import 'package:flutter/foundation.dart';
import '../geometry/types.dart';
import '../geometry/utils.dart' as geom;

/// A stable, presentation-neutral node in the workbench scene graph.
class WorkbenchSceneGraphNode {
  const WorkbenchSceneGraphNode({
    required this.id,
    required this.type,
    required this.dependencies,
  });

  final String id;
  final String type;
  final List<String> dependencies;
}

/// Builds the user-facing graph from the resolved scene without re-parsing DSL.
///
/// Group/collection/component children and clone targets are the resolved
/// relationships available at the Flutter boundary. Parser-level dependency
/// semantics remain owned by the core resolver.
class WorkbenchSceneGraph {
  const WorkbenchSceneGraph(this.nodes);

  final List<WorkbenchSceneGraphNode> nodes;

  factory WorkbenchSceneGraph.fromScene(ResolvedScene scene) {
    final nodes = <WorkbenchSceneGraphNode>[];
    for (final entry in scene.objects.entries) {
      final object = entry.value;
      final dependencies = <String>[];
      if (object is BaseResolvedGroup) {
        dependencies.addAll(object.children);
      }
      if (object is ResolvedClone && !dependencies.contains(object.of)) {
        dependencies.add(object.of);
      }
      nodes.add(
        WorkbenchSceneGraphNode(
          id: entry.key,
          type: _typeName(object),
          dependencies: List.unmodifiable(dependencies),
        ),
      );
    }
    return WorkbenchSceneGraph(List.unmodifiable(nodes));
  }

  static String _typeName(ResolvedObject object) => switch (object) {
    ResolvedPoint() => 'point',
    ResolvedLine() => 'line',
    ResolvedRect() => 'rect',
    ResolvedCircle() => 'circle',
    ResolvedEllipse() => 'ellipse',
    ResolvedArc() => 'arc',
    ResolvedQuadratic() => 'quadratic',
    ResolvedCubic() => 'cubic',
    ResolvedPath() => 'path',
    ResolvedPolygon() => 'polygon',
    ResolvedBoolean() => 'boolean',
    ResolvedText() => 'text',
    ResolvedDimension() => 'dimension',
    ResolvedAnnotation() => 'annotation',
    ResolvedClone() => 'clone',
    ResolvedCollection() => 'collection',
    ResolvedComponent() => 'component',
    ResolvedGroup() => 'group',
  };
}

/// Owns transient object selection for the active resolved scene.
class WorkbenchSelectionController extends ChangeNotifier {
  String? _selectedObjectId;

  String? get selectedObjectId => _selectedObjectId;

  void select(String? objectId) {
    if (_selectedObjectId == objectId) return;
    _selectedObjectId = objectId;
    notifyListeners();
  }

  void clear() => select(null);

  /// Returns the top-most visible object whose resolved bounds contain [point].
  /// A small tolerance keeps zero-width lines and points selectable.
  String? hitTest(
    ResolvedScene scene,
    Point2D point, {
    Set<String> hiddenRoles = const <String>{},
    double tolerance = 6.0,
  }) {
    final entries = scene.objects.entries.toList().reversed;
    for (final entry in entries) {
      final object = entry.value;
      if (!object.meta.visible || hiddenRoles.contains(object.meta.role)) {
        continue;
      }
      final bounds = geom.calculateBoundingBox(
        scene.objects,
        targetIds: <String>[entry.key],
      );
      final xTolerance = tolerance;
      final yTolerance = tolerance;
      if (point.x >= bounds.x - xTolerance &&
          point.x <= bounds.right + xTolerance &&
          point.y >= bounds.y - yTolerance &&
          point.y <= bounds.bottom + yTolerance) {
        return entry.key;
      }
    }
    return null;
  }
}
