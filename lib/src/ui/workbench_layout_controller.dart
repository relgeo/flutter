import 'package:flutter/foundation.dart';

import 'docking/dock_drop_preview.dart';
import 'docking/dock_layout_adapter.dart';
import 'docking/dock_layout_renderer.dart';
import 'docking/dock_node.dart';
import 'docking/dock_tree_operations.dart';
import 'workbench_layout_model.dart';
import 'workbench_layout_profiles.dart';

/// Owns user-editable workbench layout state without knowing document content.
///
/// Document-specific availability is supplied by callers. An unavailable
/// panel never mutates or deletes its persisted layout, so Parameters can
/// disappear for one document and return with its previous placement later.
class WorkbenchLayoutController extends ChangeNotifier {
  WorkbenchLayoutController({WorkbenchLayoutModel? initialLayout})
    : _layout = initialLayout ?? WorkbenchLayoutModel.standard();

  WorkbenchLayoutModel _layout;
  WorkbenchPanelId? _focusRequest;
  DockDropPreview? _dropPreview;
  DockNode? _dockedRoot;
  bool _usesDockTree = false;
  final Map<WorkbenchPanelId, _FloatingDragSnapshot> _dragSnapshots = {};

  WorkbenchLayoutModel get layout => _layout;

  /// The active recursive dock tree, or null while the compatibility
  /// placement renderer is still in use.
  DockNode? get dockedRoot => _usesDockTree ? _dockedRoot : null;

  /// Identifies a panel that should receive focus after a placement transition.
  ///
  /// The shell consumes this request when the newly docked panel actually
  /// receives focus. Keeping the request here lets a floating layer hand focus
  /// to its docked counterpart without coupling the controller to widgets.
  WorkbenchPanelId? get focusRequest => _focusRequest;

  /// Preview shown while a floating panel is being dragged over a dock target.
  /// It is transient UI state and is never persisted with the layout.
  DockDropPreview? get dropPreview => _dropPreview;

  void setDropPreview(DockDropPreview? preview) {
    if (_dropPreview == preview) return;
    _dropPreview = preview;
    notifyListeners();
  }

  void clearDropPreview() => setDropPreview(null);

  void requestPanelFocus(WorkbenchPanelId id) {
    if (_focusRequest == id) return;
    _focusRequest = id;
    notifyListeners();
  }

  void clearPanelFocusRequest(WorkbenchPanelId id) {
    if (_focusRequest != id) return;
    _focusRequest = null;
    notifyListeners();
  }

  WorkbenchPanelLayout panel(WorkbenchPanelId id) {
    return _layout.panels[id] ?? WorkbenchLayoutModel.standard().panels[id]!;
  }

  bool isPanelAvailable(
    WorkbenchPanelId id,
    WorkbenchPanelAvailability availability,
  ) {
    return availability == WorkbenchPanelAvailability.available;
  }

  bool isPanelVisible(
    WorkbenchPanelId id, {
    WorkbenchPanelAvailability availability =
        WorkbenchPanelAvailability.available,
  }) {
    return isPanelAvailable(id, availability) &&
        panel(id).visibility != WorkbenchPanelVisibility.hidden;
  }

  bool isPanelCollapsed(WorkbenchPanelId id) {
    return panel(id).visibility == WorkbenchPanelVisibility.collapsed;
  }

  void setPanelVisibility(
    WorkbenchPanelId id,
    WorkbenchPanelVisibility visibility, {
    WorkbenchPanelAvailability availability =
        WorkbenchPanelAvailability.available,
  }) {
    if (!isPanelAvailable(id, availability)) return;
    _updatePanel(id, panel(id).copyWith(visibility: visibility));
  }

  void togglePanel(
    WorkbenchPanelId id, {
    WorkbenchPanelAvailability availability =
        WorkbenchPanelAvailability.available,
  }) {
    if (!isPanelAvailable(id, availability)) return;
    final current = panel(id).visibility;
    setPanelVisibility(
      id,
      current == WorkbenchPanelVisibility.hidden
          ? WorkbenchPanelVisibility.visible
          : WorkbenchPanelVisibility.hidden,
    );
  }

  void toggleCollapsed(WorkbenchPanelId id) {
    final current = panel(id).visibility;
    _updatePanel(
      id,
      panel(id).copyWith(
        visibility: current == WorkbenchPanelVisibility.collapsed
            ? WorkbenchPanelVisibility.visible
            : WorkbenchPanelVisibility.collapsed,
      ),
    );
  }

  void setPlacement(WorkbenchPanelId id, WorkbenchPanelPlacement placement) {
    final nextOrder = [..._layout.floatingOrder]..remove(id);
    if (placement == WorkbenchPanelPlacement.floating ||
        placement == WorkbenchPanelPlacement.overlay) {
      nextOrder.add(id);
    }
    if (_usesDockTree &&
        _dockedRoot != null &&
        (placement == WorkbenchPanelPlacement.floating ||
            placement == WorkbenchPanelPlacement.overlay) &&
        _dockedRootPanels.contains(id)) {
      final root = _dockedRoot!;
      if (root is DockPanelNode && root.panelId == id) {
        // Removing the final leaf produces an empty dock tree. Switch back to
        // the placement projection so the panel can still return exactly once.
        _dockedRoot = null;
        _usesDockTree = false;
      } else {
        try {
          _dockedRoot = DockTreeOperations.remove(root: root, panel: id);
        } on Object {
          // The compatibility layout below remains authoritative if the tree
          // was already missing this panel.
        }
      }
    }
    if (_usesDockTree &&
        placement != WorkbenchPanelPlacement.floating &&
        placement != WorkbenchPanelPlacement.overlay &&
        !_dockedRootPanels.contains(id)) {
      _usesDockTree = false;
      _dockedRoot = null;
    }
    // Menu placement commands describe the compatibility layout, not an
    // arbitrary tree drop. Rebuild that authoritative representation rather
    // than leaving a stale recursive tree behind it.
    if (_usesDockTree &&
        placement != WorkbenchPanelPlacement.floating &&
        placement != WorkbenchPanelPlacement.overlay) {
      _usesDockTree = false;
      _dockedRoot = null;
    }
    _replaceAsCustom(
      _layout.copyWith(
        panels: {
          ..._layout.panels,
          id: panel(id).copyWith(placement: placement),
        },
        floatingOrder: nextOrder,
      ),
    );
  }

  Set<WorkbenchPanelId> get _dockedRootPanels => switch (_dockedRoot) {
    DockPanelNode panel => panel.panels,
    DockSplitNode split => split.panels,
    _ => const <WorkbenchPanelId>{},
  };

  void focusFloatingPanel(WorkbenchPanelId id) {
    final placement = panel(id).placement;
    if (placement != WorkbenchPanelPlacement.floating &&
        placement != WorkbenchPanelPlacement.overlay) {
      return;
    }
    final nextOrder = [..._layout.floatingOrder]
      ..remove(id)
      ..add(id);
    _replaceAsCustom(_layout.copyWith(floatingOrder: nextOrder));
  }

  void setBounds(WorkbenchPanelId id, WorkbenchPanelBounds bounds) {
    _updatePanel(id, panel(id).copyWith(bounds: bounds));
  }

  void setFloatingBounds(WorkbenchPanelId id, WorkbenchPanelBounds bounds) {
    final floating = <WorkbenchPanelId, WorkbenchPanelBounds>{
      ..._layout.floatingBounds,
      id: bounds,
    };
    _replaceAsCustom(_layout.copyWith(floatingBounds: floating));
  }

  void moveFloatingPanel(
    WorkbenchPanelId id, {
    required double dx,
    required double dy,
    double? canvasWidth,
    double? canvasHeight,
  }) {
    final current = _layout.floatingBounds[id] ?? panel(id).bounds;
    final width = current.width ?? 320;
    final height = current.height ?? 260;
    final nextLeft = (current.left ?? 24) + dx;
    final nextTop = (current.top ?? 24) + dy;
    setFloatingBounds(
      id,
      current.copyWith(
        left: _clampPosition(nextLeft, canvasWidth, width),
        top: _clampPosition(nextTop, canvasHeight, height),
      ),
    );
  }

  void beginFloatingPanelDrag(WorkbenchPanelId id) {
    _dragSnapshots[id] = _FloatingDragSnapshot(
      bounds: _layout.floatingBounds[id] ?? panel(id).bounds,
      floatingOrder: List.unmodifiable(_layout.floatingOrder),
    );
  }

  void cancelFloatingPanelDrag(WorkbenchPanelId id) {
    final snapshot = _dragSnapshots.remove(id);
    if (snapshot == null) return;
    _replaceAsCustom(
      _layout.copyWith(
        floatingBounds: {..._layout.floatingBounds, id: snapshot.bounds},
        floatingOrder: snapshot.floatingOrder,
      ),
    );
    clearDropPreview();
  }

  void endFloatingPanelDrag(WorkbenchPanelId id) {
    _dragSnapshots.remove(id);
  }

  /// Docks a floating panel when its current center enters a workbench drop
  /// zone. Pointer, touch, and pen gestures can share this placement policy.
  void dockFloatingPanelIfDropped(
    WorkbenchPanelId id, {
    required double canvasWidth,
    required double canvasHeight,
  }) {
    final state = panel(id);
    if (state.placement != WorkbenchPanelPlacement.floating &&
        state.placement != WorkbenchPanelPlacement.overlay) {
      return;
    }
    final bounds = _layout.floatingBounds[id] ?? state.bounds;
    final width = bounds.width ?? 320;
    final height = bounds.height ?? 260;
    final centerX = (bounds.left ?? 24) + width / 2;
    final centerY = (bounds.top ?? 24) + height / 2;
    final bottomZone =
        id == WorkbenchPanelId.parameters && centerY >= canvasHeight * 0.72;
    final nextPlacement = bottomZone
        ? WorkbenchPanelPlacement.bottom
        : centerX <= canvasWidth * 0.22
        ? WorkbenchPanelPlacement.left
        : centerX >= canvasWidth * 0.78
        ? WorkbenchPanelPlacement.right
        : WorkbenchPanelPlacement.center;
    final changed = state.placement != nextPlacement;
    setPlacement(id, nextPlacement);
    if (changed) requestPanelFocus(id);
  }

  /// Commits the exact zone that was shown to the user by the drag preview.
  /// The legacy placement model cannot yet represent arbitrary nested splits,
  /// so this is the compatibility bridge until the persisted dock tree becomes
  /// the controller's primary layout state.
  void dockFloatingPanelFromPreview(
    WorkbenchPanelId id,
    DockDropPreview preview,
  ) {
    if (!preview.isValid || preview.sourcePanel != id) return;
    final root = _dockedRoot ?? DockLayoutAdapter.fromPlacementLayout(_layout);
    if (root == null) return;
    final nextRoot = DockTreeOperations.move(
      root: root,
      panel: id,
      target: preview.targetPanel,
      zone: preview.zone,
    );
    final nextPanels = {
      ..._layout.panels,
      id: panel(id).copyWith(
        placement: WorkbenchPanelPlacement.center,
        visibility: WorkbenchPanelVisibility.visible,
      ),
    };
    _dockedRoot = nextRoot;
    _usesDockTree = true;
    _replace(_layout.copyWith(panels: nextPanels));
    requestPanelFocus(id);
    endFloatingPanelDrag(id);
  }

  /// Resizes a divider in the active recursive dock tree. The legacy
  /// placement renderer remains available until a tree operation occurs.
  void resizeDockDivider(
    DockDividerLocation location,
    double delta,
    double availablePixels,
  ) {
    final root = _dockedRoot;
    if (!_usesDockTree || root == null) return;
    try {
      _dockedRoot = DockTreeOperations.resize(
        root: root,
        splitPath: location.splitPath,
        dividerIndex: location.dividerIndex,
        deltaPixels: delta,
        availablePixels: availablePixels,
      );
      notifyListeners();
    } on Object {
      // A stale divider gesture must not break the workbench. The next build
      // will expose the current tree and a fresh divider path.
    }
  }

  void resizeFloatingPanel(
    WorkbenchPanelId id, {
    required double dx,
    required double dy,
    double? canvasWidth,
    double? canvasHeight,
  }) {
    final current = _layout.floatingBounds[id] ?? panel(id).bounds;
    final minWidth = current.minWidth ?? 240;
    final minHeight = current.minHeight ?? 160;
    final maxWidth = _availableSize(
      canvasWidth,
      640,
      origin: current.left ?? 24,
      minimum: minWidth,
    );
    final maxHeight = _availableSize(
      canvasHeight,
      600,
      origin: current.top ?? 24,
      minimum: minHeight,
    );
    final width = ((current.width ?? 320) + dx)
        .clamp(minWidth, maxWidth)
        .toDouble();
    final height = ((current.height ?? 260) + dy)
        .clamp(minHeight, maxHeight)
        .toDouble();
    setFloatingBounds(id, current.copyWith(width: width, height: height));
  }

  void setSplitRatio(String region, double ratio) {
    if (!ratio.isFinite || ratio <= 0 || ratio > 1) return;
    _replaceAsCustom(
      _layout.copyWith(splitRatios: {..._layout.splitRatios, region: ratio}),
    );
  }

  void resizeBoundary(
    WorkbenchPanelId left,
    WorkbenchPanelId right,
    double delta,
    double availableWidth,
  ) {
    if (!availableWidth.isFinite || availableWidth <= 0 || !delta.isFinite) {
      return;
    }
    final leftRegion = panel(left).placement.storageKey;
    final rightRegion = panel(right).placement.storageKey;
    final leftRatio = _layout.splitRatios[leftRegion];
    final rightRatio = _layout.splitRatios[rightRegion];
    if (leftRatio == null || rightRatio == null) return;

    final combined = leftRatio + rightRatio;
    final minRatio = 120 / availableWidth;
    final nextLeft = (leftRatio + delta / availableWidth).clamp(
      minRatio,
      combined - minRatio,
    );
    final nextRatios = {
      ..._layout.splitRatios,
      leftRegion: nextLeft,
      rightRegion: combined - nextLeft,
    };
    _replaceAsCustom(_layout.copyWith(splitRatios: nextRatios));
  }

  void resizeParameters(double delta, double availableHeight) {
    if (!delta.isFinite || !availableHeight.isFinite || availableHeight <= 0) {
      return;
    }
    final current = panel(WorkbenchPanelId.parameters).bounds.height ?? 220;
    final maxHeight = (availableHeight - 120).clamp(120.0, 420.0);
    // Parameters is anchored to the bottom edge. A positive pointer delta
    // moves the divider down, therefore the bottom panel becomes shorter.
    final next = (current - delta).clamp(120.0, maxHeight);
    if (next == current) return;
    setBounds(
      WorkbenchPanelId.parameters,
      panel(WorkbenchPanelId.parameters).bounds.copyWith(height: next),
    );
  }

  void setActiveProfile(String profileId) {
    if (profileId.isEmpty || profileId == _layout.activeProfileId) return;
    _replace(_layout.copyWith(activeProfileId: profileId));
  }

  void applyProfile(WorkbenchLayoutProfile profile) {
    _usesDockTree = false;
    _dockedRoot = null;
    _replace(profile.layout);
  }

  void restore(WorkbenchLayoutModel layout, {DockNode? dockedRoot}) {
    _dockedRoot = dockedRoot != null &&
            DockTreeOperations.isValid(dockedRoot) &&
            _dockTreeMatchesLayout(dockedRoot, layout)
        ? dockedRoot
        : null;
    _usesDockTree = _dockedRoot != null;
    _layout = layout;
    _dropPreview = null;
    notifyListeners();
  }

  bool _dockTreeMatchesLayout(DockNode root, WorkbenchLayoutModel layout) {
    final treePanels = switch (root) {
      DockPanelNode panel => panel.panels,
      DockSplitNode split => split.panels,
      _ => const <WorkbenchPanelId>{},
    };
    return !treePanels.any((id) {
      final placement = layout.panels[id]?.placement;
      return placement == WorkbenchPanelPlacement.floating ||
          placement == WorkbenchPanelPlacement.overlay;
    });
  }

  void reset() {
    _usesDockTree = false;
    _dockedRoot = null;
    _replace(WorkbenchLayoutModel.standard());
  }

  void _updatePanel(WorkbenchPanelId id, WorkbenchPanelLayout value) {
    if (value == panel(id)) return;
    _replaceAsCustom(_layout.copyWith(panels: {..._layout.panels, id: value}));
  }

  void _replaceAsCustom(WorkbenchLayoutModel next) {
    _replace(
      next.activeProfileId == 'custom'
          ? next
          : next.copyWith(activeProfileId: 'custom'),
    );
  }

  void _replace(WorkbenchLayoutModel next) {
    if (next == _layout) return;
    _layout = next;
    if (!_usesDockTree) {
      _dockedRoot = null;
    }
    notifyListeners();
  }

  double _clampPosition(double value, double? canvasSize, double panelSize) {
    if (canvasSize == null || !canvasSize.isFinite || canvasSize <= 0) {
      return value;
    }
    return value.clamp(
      0.0,
      (canvasSize - panelSize).clamp(0.0, double.infinity),
    );
  }

  double _availableSize(
    double? canvasSize,
    double fallback, {
    required double origin,
    required double minimum,
  }) {
    if (canvasSize == null || !canvasSize.isFinite || canvasSize <= 0) {
      return fallback;
    }
    return (canvasSize - origin).clamp(minimum, double.infinity).toDouble();
  }
}

class _FloatingDragSnapshot {
  const _FloatingDragSnapshot({
    required this.bounds,
    required this.floatingOrder,
  });

  final WorkbenchPanelBounds bounds;
  final List<WorkbenchPanelId> floatingOrder;
}
