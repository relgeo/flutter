import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('theme preference defaults to system and maps to Flutter ThemeMode', () {
    expect(
      WorkbenchPreferencesData.defaults.themePreference,
      RelGeoThemePreference.system,
    );
    expect(RelGeoThemePreference.system.themeMode, ThemeMode.system);
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

  test('unknown stored theme preference safely falls back to system', () async {
    SharedPreferences.setMockInitialValues({
      'relgeo.workbench.themePreference': 'future-mode',
    });

    final loaded = await WorkbenchPreferencesStore.load();
    expect(loaded?.themePreference, RelGeoThemePreference.system);
  });
}
