import 'package:shared_preferences/shared_preferences.dart';

class WorkbenchPreferencesData {
  final String workbenchProfileId;
  final bool followProfileOverlay;
  final bool followProfileRoleFilter;
  final bool showAnchors;
  final bool showLabels;
  final bool showBoundingBoxes;
  final Set<String> hiddenRoles;

  const WorkbenchPreferencesData({
    required this.workbenchProfileId,
    required this.followProfileOverlay,
    required this.followProfileRoleFilter,
    required this.showAnchors,
    required this.showLabels,
    required this.showBoundingBoxes,
    required this.hiddenRoles,
  });

  WorkbenchPreferencesData copyWith({
    String? workbenchProfileId,
    bool? followProfileOverlay,
    bool? followProfileRoleFilter,
    bool? showAnchors,
    bool? showLabels,
    bool? showBoundingBoxes,
    Set<String>? hiddenRoles,
  }) {
    return WorkbenchPreferencesData(
      workbenchProfileId: workbenchProfileId ?? this.workbenchProfileId,
      followProfileOverlay: followProfileOverlay ?? this.followProfileOverlay,
      followProfileRoleFilter:
          followProfileRoleFilter ?? this.followProfileRoleFilter,
      showAnchors: showAnchors ?? this.showAnchors,
      showLabels: showLabels ?? this.showLabels,
      showBoundingBoxes: showBoundingBoxes ?? this.showBoundingBoxes,
      hiddenRoles: hiddenRoles ?? this.hiddenRoles,
    );
  }

  static const defaults = WorkbenchPreferencesData(
    workbenchProfileId: 'cad-dark',
    followProfileOverlay: true,
    followProfileRoleFilter: true,
    showAnchors: false,
    showLabels: false,
    showBoundingBoxes: false,
    hiddenRoles: {'construction'},
  );
}

class WorkbenchPreferencesStore {
  static const _profileIdKey = 'relgeo.workbench.profileId';
  static const _followOverlayKey = 'relgeo.workbench.followOverlay';
  static const _followRoleFilterKey = 'relgeo.workbench.followRoleFilter';
  static const _showAnchorsKey = 'relgeo.workbench.overlay.showAnchors';
  static const _showLabelsKey = 'relgeo.workbench.overlay.showLabels';
  static const _showBoundingBoxesKey =
      'relgeo.workbench.overlay.showBoundingBoxes';
  static const _hiddenRolesKey = 'relgeo.workbench.hiddenRoles';

  static Future<WorkbenchPreferencesData?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileId = prefs.getString(_profileIdKey);
      final followOverlay = prefs.getBool(_followOverlayKey);
      final followRoleFilter = prefs.getBool(_followRoleFilterKey);
      final showAnchors = prefs.getBool(_showAnchorsKey);
      final showLabels = prefs.getBool(_showLabelsKey);
      final showBoundingBoxes = prefs.getBool(_showBoundingBoxesKey);
      final hiddenRoles = prefs.getStringList(_hiddenRolesKey);

      if (profileId == null &&
          followOverlay == null &&
          followRoleFilter == null &&
          showAnchors == null &&
          showLabels == null &&
          showBoundingBoxes == null &&
          hiddenRoles == null) {
        return null;
      }

      return WorkbenchPreferencesData(
        workbenchProfileId:
            profileId ?? WorkbenchPreferencesData.defaults.workbenchProfileId,
        followProfileOverlay:
            followOverlay ??
            WorkbenchPreferencesData.defaults.followProfileOverlay,
        followProfileRoleFilter:
            followRoleFilter ??
            WorkbenchPreferencesData.defaults.followProfileRoleFilter,
        showAnchors:
            showAnchors ?? WorkbenchPreferencesData.defaults.showAnchors,
        showLabels: showLabels ?? WorkbenchPreferencesData.defaults.showLabels,
        showBoundingBoxes:
            showBoundingBoxes ??
            WorkbenchPreferencesData.defaults.showBoundingBoxes,
        hiddenRoles: Set<String>.from(
          hiddenRoles ?? WorkbenchPreferencesData.defaults.hiddenRoles,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(WorkbenchPreferencesData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileIdKey, data.workbenchProfileId);
      await prefs.setBool(_followOverlayKey, data.followProfileOverlay);
      await prefs.setBool(_followRoleFilterKey, data.followProfileRoleFilter);
      await prefs.setBool(_showAnchorsKey, data.showAnchors);
      await prefs.setBool(_showLabelsKey, data.showLabels);
      await prefs.setBool(_showBoundingBoxesKey, data.showBoundingBoxes);
      await prefs.setStringList(_hiddenRolesKey, data.hiddenRoles.toList());
    } catch (_) {
      // Ignore persistence failures in unsupported or test environments.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileIdKey);
      await prefs.remove(_followOverlayKey);
      await prefs.remove(_followRoleFilterKey);
      await prefs.remove(_showAnchorsKey);
      await prefs.remove(_showLabelsKey);
      await prefs.remove(_showBoundingBoxesKey);
      await prefs.remove(_hiddenRolesKey);
    } catch (_) {
      // Ignore persistence failures in unsupported or test environments.
    }
  }
}
