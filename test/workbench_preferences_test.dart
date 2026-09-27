import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('theme preference defaults to no override and maps explicitly', () {
    expect(WorkbenchPreferencesData.defaults.themePreference, isNull);
    expect(RelGeoThemePreference.light.themeMode, ThemeMode.light);
    expect(RelGeoThemePreference.dark.themeMode, ThemeMode.dark);
  });

  test('theme preference round-trips through shared preferences', () async {
    await WorkbenchPreferencesStore.save(
      WorkbenchPreferencesData.defaults.copyWith(
        themePreference: RelGeoThemePreference.dark,
      ),
    );

    final loaded = await WorkbenchPreferencesStore.load();
    expect(loaded?.themePreference, RelGeoThemePreference.dark);
  });

  test('clearing the theme override removes the stored value', () async {
    await WorkbenchPreferencesStore.save(
      WorkbenchPreferencesData.defaults.copyWith(
        themePreference: RelGeoThemePreference.dark,
      ),
    );

    await WorkbenchPreferencesStore.save(
      WorkbenchPreferencesData.defaults.copyWith(clearThemePreference: true),
    );

    final loaded = await WorkbenchPreferencesStore.load();
    expect(loaded?.themePreference, isNull);
  });

  test(
    'legacy or unknown stored theme preference safely follows system',
    () async {
      SharedPreferences.setMockInitialValues({
        'relgeo.workbench.themePreference': 'future-mode',
      });

      final loaded = await WorkbenchPreferencesStore.load();
      expect(loaded?.themePreference, isNull);
    },
  );
}
