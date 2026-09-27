import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_preferences.dart';
import 'package:relgeo_flutter/src/ui/workbench_preferences_controller.dart';

void main() {
  test('loads through the injected storage boundary', () async {
    final controller = WorkbenchPreferencesController(
      load: () async => WorkbenchPreferencesData.defaults,
      save: (_) async {},
    );

    final loaded = await controller.load();
    expect(loaded?.themePreference, RelGeoThemePreference.system);
    expect(loaded?.workbenchProfileId, 'cad-dark');
  });

  test(
    'persists a merged snapshot while preserving unrelated preferences',
    () async {
      WorkbenchPreferencesData? saved;
      final controller = WorkbenchPreferencesController(
        load: () async => WorkbenchPreferencesData.defaults.copyWith(
          themePreference: RelGeoThemePreference.dark,
        ),
        save: (value) async => saved = value,
      );

      await controller.persist(
        workbenchProfileId: 'cad-light',
        followProfileOverlay: true,
        followProfileRoleFilter: false,
        showAnchors: true,
        showLabels: false,
        showBoundingBoxes: true,
        hiddenRoles: {'construction'},
      );

      expect(saved?.themePreference, RelGeoThemePreference.dark);
      expect(saved?.workbenchProfileId, 'cad-light');
      expect(saved?.hiddenRoles, {'construction'});
    },
  );

  test(
    'supports generic updates and clear through the same boundary',
    () async {
      var clearCount = 0;
      WorkbenchPreferencesData? saved;
      final controller = WorkbenchPreferencesController(
        load: () async => WorkbenchPreferencesData.defaults,
        save: (value) async => saved = value,
        clear: () async => clearCount++,
      );

      await controller.update(
        (current) =>
            current.copyWith(themePreference: RelGeoThemePreference.dark),
      );
      await controller.clear();

      expect(saved?.themePreference, RelGeoThemePreference.dark);
      expect(clearCount, 1);
    },
  );
}
