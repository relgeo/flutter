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

  WorkbenchLayoutModel get layout => _layout;

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
    _updatePanel(id, panel(id).copyWith(placement: placement));
  }

  void setBounds(WorkbenchPanelId id, WorkbenchPanelBounds bounds) {
    _updatePanel(id, panel(id).copyWith(bounds: bounds));
  }

  void setFloatingBounds(WorkbenchPanelId id, WorkbenchPanelBounds bounds) {
    final floating = <WorkbenchPanelId, WorkbenchPanelBounds>{
      ..._layout.floatingBounds,
      id: bounds,
    };
    _replace(_layout.copyWith(floatingBounds: floating));
  }

  void setSplitRatio(String region, double ratio) {
    if (!ratio.isFinite || ratio <= 0 || ratio > 1) return;
    _replace(
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
    _replace(_layout.copyWith(splitRatios: nextRatios));
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
    _replace(_layout.copyWith(panels: {..._layout.panels, id: value}));
  }

  void _replace(WorkbenchLayoutModel next) {
    if (next == _layout) return;
    _layout = next;
    notifyListeners();
  }
}
