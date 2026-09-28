import '../workbench_layout_model.dart';

enum DockAxis { horizontal, vertical }

enum DockZone { left, right, top, bottom, center }

extension DockAxisStorage on DockAxis {
  String get storageKey => name;

  static DockAxis? fromStorageKey(Object? value) {
    if (value is! String) return null;
    for (final axis in DockAxis.values) {
      if (axis.storageKey == value) return axis;
    }
    return null;
  }
}

/// Immutable leaf in the dock tree. A panel remains an independent surface;
/// it is never converted into a workspace tab by docking.
class DockPanelNode {
  const DockPanelNode(this.panelId);

  final WorkbenchPanelId panelId;

  Set<WorkbenchPanelId> get panels => <WorkbenchPanelId>{panelId};

  Map<String, Object> toJson() => <String, Object>{
    'type': 'panel',
    'panelId': panelId.storageKey,
  };

  static DockPanelNode? fromJson(Object? value) {
    if (value is! Map || value['type'] != 'panel') return null;
    final panel = WorkbenchPanelId.fromStorageKey(value['panelId']);
    return panel == null ? null : DockPanelNode(panel);
  }

  @override
  bool operator ==(Object other) =>
      other is DockPanelNode && other.panelId == panelId;

  @override
  int get hashCode => panelId.hashCode;
}

/// Immutable recursive split. Ratios are weights for the corresponding
/// children and are normalized by [DockTreeOperations.normalize].
class DockSplitNode {
  DockSplitNode({
    required this.axis,
    required List<Object> children,
    required List<double> ratios,
  }) : children = List.unmodifiable(children),
       ratios = List.unmodifiable(ratios);

  final DockAxis axis;
  final List<Object> children;
  final List<double> ratios;

  Set<WorkbenchPanelId> get panels => {
    for (final child in children) ..._panelsOf(child),
  };

  Map<String, Object> toJson() => <String, Object>{
    'type': 'split',
    'axis': axis.storageKey,
    'ratios': ratios,
    'children': [for (final child in children) _jsonOf(child)],
  };

  static DockSplitNode? fromJson(Object? value) {
    if (value is! Map || value['type'] != 'split') return null;
    final axis = DockAxisStorage.fromStorageKey(value['axis']);
    final rawChildren = value['children'];
    final rawRatios = value['ratios'];
    if (axis == null || rawChildren is! List || rawRatios is! List) return null;

    final children = <Object>[];
    for (final child in rawChildren) {
      final parsed = DockNodeCodec.fromJson(child);
      if (parsed == null) return null;
      children.add(parsed);
    }
    final ratios = <double>[];
    for (final ratio in rawRatios) {
      if (ratio is! num || !ratio.isFinite) return null;
      ratios.add(ratio.toDouble());
    }
    return DockSplitNode(axis: axis, children: children, ratios: ratios);
  }

  @override
  bool operator ==(Object other) =>
      other is DockSplitNode &&
      other.axis == axis &&
      _listEquals(other.children, children) &&
      _listEquals(other.ratios, ratios);

  @override
  int get hashCode =>
      Object.hash(axis, Object.hashAll(children), Object.hashAll(ratios));
}

typedef DockNode = Object;

class DockNodeCodec {
  const DockNodeCodec._();

  static DockNode? fromJson(Object? value) =>
      DockPanelNode.fromJson(value) ?? DockSplitNode.fromJson(value);
}

/// Versioned root wrapper for persisted docked layout state.
class DockedLayout {
  const DockedLayout({required this.schemaVersion, required this.root});

  final int schemaVersion;
  final DockNode root;

  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': schemaVersion,
    'root': _jsonOf(root),
  };

  static DockedLayout? fromJson(Object? value) {
    if (value is! Map) return null;
    final version = value['schemaVersion'];
    final root = DockNodeCodec.fromJson(value['root']);
    if (version is! int || root == null) return null;
    return DockedLayout(schemaVersion: version, root: root);
  }

  @override
  bool operator ==(Object other) =>
      other is DockedLayout &&
      other.schemaVersion == schemaVersion &&
      other.root == root;

  @override
  int get hashCode => Object.hash(schemaVersion, root);
}

Set<WorkbenchPanelId> _panelsOf(Object node) => switch (node) {
  DockPanelNode panel => panel.panels,
  DockSplitNode split => split.panels,
  _ => <WorkbenchPanelId>{},
};

Map<String, Object> _jsonOf(Object node) => switch (node) {
  DockPanelNode panel => panel.toJson(),
  DockSplitNode split => split.toJson(),
  _ => <String, Object>{},
};

bool _listEquals(List<Object> left, List<Object> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
