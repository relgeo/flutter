import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workbench_visual_profile.dart';

enum RelGeoThemePreference {
  light('light', 'Light'),
  dark('dark', 'Dark');

  const RelGeoThemePreference(this.storageValue, this.label);

  final String storageValue;
  final String label;

  ThemeMode get themeMode {
    switch (this) {
      case RelGeoThemePreference.light:
        return ThemeMode.light;
      case RelGeoThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  static RelGeoThemePreference? fromStorage(String? value) {
    for (final preference in values) {
      if (preference.storageValue == value) return preference;
    }
    // `system` was the old persisted value. Treat it as no override so an
    // existing installation continues to follow the OS without exposing a
    // third choice in the user-facing control.
    return null;
  }
}

class WorkbenchPreferencesData {
  final RelGeoThemePreference? themePreference;
  final String workbenchProfileId;
  final bool followProfileOverlay;
  final bool followProfileRoleFilter;
  final bool showAnchors;
  final bool showLabels;
  final bool showBoundingBoxes;
  final Set<String> hiddenRoles;

  const WorkbenchPreferencesData({
    required this.themePreference,
    required this.workbenchProfileId,
    required this.followProfileOverlay,
    required this.followProfileRoleFilter,
    required this.showAnchors,
    required this.showLabels,
    required this.showBoundingBoxes,
    required this.hiddenRoles,
  });

  WorkbenchPreferencesData copyWith({
    RelGeoThemePreference? themePreference,
    bool clearThemePreference = false,
    String? workbenchProfileId,
    bool? followProfileOverlay,
    bool? followProfileRoleFilter,
    bool? showAnchors,
    bool? showLabels,
    bool? showBoundingBoxes,
    Set<String>? hiddenRoles,
  }) {
    return WorkbenchPreferencesData(
      themePreference: clearThemePreference
          ? null
          : themePreference ?? this.themePreference,
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
    themePreference: null,
    workbenchProfileId: 'cad',
    followProfileOverlay: true,
    followProfileRoleFilter: true,
    showAnchors: false,
    showLabels: false,
    showBoundingBoxes: false,
    hiddenRoles: {'construction'},
  );
}

class WorkbenchPreferencesStore {
  static const _themePreferenceKey = 'relgeo.workbench.themePreference';
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
      final themePreference = prefs.getString(_themePreferenceKey);
      final profileId = prefs.getString(_profileIdKey);
      final followOverlay = prefs.getBool(_followOverlayKey);
      final followRoleFilter = prefs.getBool(_followRoleFilterKey);
      final showAnchors = prefs.getBool(_showAnchorsKey);
      final showLabels = prefs.getBool(_showLabelsKey);
      final showBoundingBoxes = prefs.getBool(_showBoundingBoxesKey);
      final hiddenRoles = prefs.getStringList(_hiddenRolesKey);

      if (themePreference == null &&
          profileId == null &&
          followOverlay == null &&
          followRoleFilter == null &&
          showAnchors == null &&
          showLabels == null &&
          showBoundingBoxes == null &&
          hiddenRoles == null) {
        return null;
      }

      return WorkbenchPreferencesData(
        themePreference: RelGeoThemePreference.fromStorage(themePreference),
        workbenchProfileId: WorkbenchVisualProfile.normalizeId(profileId),
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
      if (data.themePreference == null) {
        await prefs.remove(_themePreferenceKey);
      } else {
        await prefs.setString(
          _themePreferenceKey,
          data.themePreference!.storageValue,
        );
      }
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
      await prefs.remove(_themePreferenceKey);
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
