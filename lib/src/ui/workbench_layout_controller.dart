import 'package:flutter/foundation.dart';

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

  WorkbenchLayoutModel get layout => _layout;

  /// Identifies a panel that should receive focus after a placement transition.
  ///
  /// The shell consumes this request when the newly docked panel actually
  /// receives focus. Keeping the request here lets a floating layer hand focus
  /// to its docked counterpart without coupling the controller to widgets.
  WorkbenchPanelId? get focusRequest => _focusRequest;

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
    final next = (current + delta).clamp(120.0, maxHeight);
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
    _replace(profile.layout);
  }

  void restore(WorkbenchLayoutModel layout) {
    _replace(layout);
  }

  void reset() {
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
