import 'package:flutter/foundation.dart';

import 'canvas_painter.dart';

/// Owns overlay and semantic-role filter state for the workbench.
///
/// The widget tree remains responsible for presenting this state. Persistence
/// stays outside the controller so the controller can be reused by desktop,
/// web, and future host shells without coupling it to storage.
class WorkbenchOverlayController extends ChangeNotifier {
  WorkbenchOverlayController({
    OverlayOptions overlay = const OverlayOptions(),
    Set<String> hiddenRoles = const {'construction'},
    bool followProfileOverlay = true,
    bool followProfileRoleFilter = true,
  })  : _overlay = overlay,
        _hiddenRoles = Set<String>.from(hiddenRoles),
        _followProfileOverlay = followProfileOverlay,
        _followProfileRoleFilter = followProfileRoleFilter;

  OverlayOptions _overlay;
  Set<String> _hiddenRoles;
  bool _followProfileOverlay;
  bool _followProfileRoleFilter;

  OverlayOptions get overlay => _overlay;
  Set<String> get hiddenRoles => Set<String>.unmodifiable(_hiddenRoles);
  bool get followProfileOverlay => _followProfileOverlay;
  bool get followProfileRoleFilter => _followProfileRoleFilter;

  /// Applies the profile values selected by the caller.
  void applyProfile({
    required OverlayOptions overlay,
    required Set<String> hiddenRoles,
    bool includeOverlay = true,
    bool includeRoleFilter = true,
  }) {
    if (includeOverlay) _overlay = overlay;
    if (includeRoleFilter) _hiddenRoles = Set<String>.from(hiddenRoles);
    notifyListeners();
  }

  void restore({
    required OverlayOptions overlay,
    required Set<String> hiddenRoles,
    required bool followProfileOverlay,
    required bool followProfileRoleFilter,
  }) {
    _overlay = overlay;
    _hiddenRoles = Set<String>.from(hiddenRoles);
    _followProfileOverlay = followProfileOverlay;
    _followProfileRoleFilter = followProfileRoleFilter;
    notifyListeners();
  }

  void setFollowProfileOverlay(
    bool value, {
    required OverlayOptions profileOverlay,
  }) {
    _followProfileOverlay = value;
    if (value) _overlay = profileOverlay;
    notifyListeners();
  }

  void setFollowProfileRoleFilter(
    bool value, {
    required Set<String> profileHiddenRoles,
  }) {
    _followProfileRoleFilter = value;
    if (value) _hiddenRoles = Set<String>.from(profileHiddenRoles);
    notifyListeners();
  }

  void setOverlayManual(OverlayOptions overlay) {
    _followProfileOverlay = false;
    _overlay = overlay;
    notifyListeners();
  }

  void setHiddenRolesManual(Set<String> hiddenRoles) {
    _followProfileRoleFilter = false;
    _hiddenRoles = Set<String>.from(hiddenRoles);
    notifyListeners();
  }
}
