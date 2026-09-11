import 'package:flutter/material.dart';
import 'src/ui/cad_workbench.dart';
import 'src/ui/workbench_preferences.dart';
import 'src/ui/workbench_visual_profile.dart';

void main() {
  runApp(const RelGeoCADApp());
}

class RelGeoCADApp extends StatefulWidget {
  const RelGeoCADApp({super.key, this.initialDsl});

  final String? initialDsl;

  @override
  State<RelGeoCADApp> createState() => _RelGeoCADAppState();
}

class _RelGeoCADAppState extends State<RelGeoCADApp> {
  String _workbenchProfileId = WorkbenchVisualProfile.cadDark.id;

  @override
  void initState() {
    super.initState();
    _loadWorkbenchPreferences();
  }

  WorkbenchVisualProfile get _workbenchProfile =>
      WorkbenchVisualProfile.byId(_workbenchProfileId);

  Future<void> _loadWorkbenchPreferences() async {
    final data = await WorkbenchPreferencesStore.load();
    if (!mounted || data == null) return;
    setState(() {
      _workbenchProfileId = data.workbenchProfileId;
    });
  }

  Future<void> _persistProfilePreference(String value) async {
    final current =
        await WorkbenchPreferencesStore.load() ??
        WorkbenchPreferencesData.defaults;
    await WorkbenchPreferencesStore.save(
      current.copyWith(workbenchProfileId: value),
    );
  }

  Future<void> _resetWorkbenchPreferences() async {
    await WorkbenchPreferencesStore.clear();
    if (!mounted) return;
    setState(() {
      _workbenchProfileId =
          WorkbenchPreferencesData.defaults.workbenchProfileId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RelGeo CAD Workbench',
      debugShowCheckedModeBanner: false,
      theme: _workbenchProfile.materialTheme(),
      home: CADWorkbenchPage(
        initialDsl: widget.initialDsl,
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
