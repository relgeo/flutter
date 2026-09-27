import 'workbench_preferences.dart';

/// Coordinates workbench preference reads/writes without owning widget state.
///
/// The storage format remains in [WorkbenchPreferencesStore]. Injected
/// functions keep this boundary deterministic in tests and replaceable for a
/// future platform-specific store.
class WorkbenchPreferencesController {
  WorkbenchPreferencesController({
    Future<WorkbenchPreferencesData?> Function()? load,
    Future<void> Function(WorkbenchPreferencesData data)? save,
    Future<void> Function()? clear,
  }) : _load = load ?? WorkbenchPreferencesStore.load,
       _save = save ?? WorkbenchPreferencesStore.save,
       _clear = clear ?? WorkbenchPreferencesStore.clear;

  final Future<WorkbenchPreferencesData?> Function() _load;
  final Future<void> Function(WorkbenchPreferencesData data) _save;
  final Future<void> Function() _clear;

  Future<WorkbenchPreferencesData?> load() => _load();

  Future<void> update(
    WorkbenchPreferencesData Function(WorkbenchPreferencesData current)
    transform,
  ) async {
    final current = await _load() ?? WorkbenchPreferencesData.defaults;
    await _save(transform(current));
  }

  Future<void> clear() => _clear();

  Future<void> persist({
    required String workbenchProfileId,
    required bool followProfileOverlay,
    required bool followProfileRoleFilter,
    required bool showAnchors,
    required bool showLabels,
    required bool showBoundingBoxes,
    required Set<String> hiddenRoles,
  }) async {
    await update(
      (current) => current.copyWith(
        workbenchProfileId: workbenchProfileId,
        followProfileOverlay: followProfileOverlay,
        followProfileRoleFilter: followProfileRoleFilter,
        showAnchors: showAnchors,
        showLabels: showLabels,
        showBoundingBoxes: showBoundingBoxes,
        hiddenRoles: hiddenRoles,
      ),
    );
  }
}
