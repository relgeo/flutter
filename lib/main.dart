import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'src/ui/cad_workbench.dart';
import 'src/ui/app_theme.dart';
import 'src/ui/workbench_preferences.dart';
import 'src/ui/workbench_preferences_controller.dart';
import 'src/ui/workbench_visual_profile.dart';
import 'src/ui/workbench_window_host.dart';
import 'src/ui/workbench_method_channel_window_host.dart';
import 'src/ui/workbench_window_policy.dart';

void main() {
  runApp(
    RelGeoCADApp(
      windowHost: kIsWeb ? null : const MethodChannelWorkbenchWindowHost(),
    ),
  );
}

class RelGeoCADApp extends StatefulWidget {
  const RelGeoCADApp({super.key, this.initialDsl, this.windowHost});

  final String? initialDsl;
  final WorkbenchWindowHost? windowHost;

  @override
  State<RelGeoCADApp> createState() => _RelGeoCADAppState();
}

class _RelGeoCADAppState extends State<RelGeoCADApp> {
  final WorkbenchPreferencesController _preferencesController =
      WorkbenchPreferencesController();
  RelGeoThemePreference _themePreference =
      WorkbenchPreferencesData.defaults.themePreference;
  String _workbenchProfileId = WorkbenchVisualProfile.cad.id;

  @override
  void initState() {
    super.initState();
    _loadWorkbenchPreferences();
    _configureWindowHost();
  }

  Future<void> _configureWindowHost() async {
    await widget.windowHost?.configure(
      WorkbenchWindowPolicy.defaultConfiguration,
    );
  }

  @override
  void didUpdateWidget(covariant RelGeoCADApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowHost != widget.windowHost) {
      _configureWindowHost();
    }
  }

  Future<void> _loadWorkbenchPreferences() async {
    final data = await _preferencesController.load();
    if (!mounted || data == null) return;
    setState(() {
      _themePreference = data.themePreference;
      _workbenchProfileId = data.workbenchProfileId;
    });
  }

  Future<void> _persistProfilePreference(String value) async {
    await _preferencesController.update(
      (current) => current.copyWith(workbenchProfileId: value),
    );
  }

  Future<void> _persistThemePreference(RelGeoThemePreference value) async {
    await _preferencesController.update(
      (current) => current.copyWith(themePreference: value),
    );
  }

  Future<void> _resetWorkbenchPreferences() async {
    await _preferencesController.clear();
    if (!mounted) return;
    setState(() {
      _themePreference = WorkbenchPreferencesData.defaults.themePreference;
      _workbenchProfileId =
          WorkbenchPreferencesData.defaults.workbenchProfileId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RelGeo CAD Workbench',
      debugShowCheckedModeBanner: false,
      theme: buildRelGeoLightTheme(),
      darkTheme: buildRelGeoDarkTheme(),
      themeMode: _themePreference.themeMode,
      home: CADWorkbenchPage(
        initialDsl: widget.initialDsl,
        themePreference: _themePreference,
        onThemePreferenceChanged: (value) {
          setState(() {
            _themePreference = value;
          });
          _persistThemePreference(value);
        },
        workbenchProfileId: _workbenchProfileId,
        onWorkbenchProfileChanged: (value) {
          setState(() {
            _workbenchProfileId = value;
          });
          _persistProfilePreference(value);
        },
        onResetWorkbenchPreferences: _resetWorkbenchPreferences,
      ),
    );
  }
}
