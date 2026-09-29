import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'docking/dock_node.dart';
import 'docking/dock_tree_operations.dart';
import 'workbench_layout_model.dart';

/// The complete user-owned workbench snapshot.
///
/// Older releases persisted only [layout]. Keeping the legacy shape readable
/// lets the dock tree become durable without invalidating existing users'
/// saved profiles.
class WorkbenchLayoutSnapshot {
  const WorkbenchLayoutSnapshot({required this.layout, this.dockedRoot});

  final WorkbenchLayoutModel layout;
  final DockNode? dockedRoot;

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'schemaVersion': 2,
      'layout': layout.toJson(),
    };
    final root = dockedRoot;
    if (root != null) {
      json['dockedLayout'] = DockedLayout(
        schemaVersion: 1,
        root: root,
      ).toJson();
    }
    return json;
  }

  static WorkbenchLayoutSnapshot fromJson(Object value) {
    if (value is Map && value['layout'] is Map) {
      if (value['schemaVersion'] != 2) {
        throw const FormatException('Unsupported workbench snapshot version');
      }
      final layout = WorkbenchLayoutModel.fromJson(value['layout']);
      DockNode? root;
      final dockedLayout = DockedLayout.fromJson(value['dockedLayout']);
      if (dockedLayout != null &&
          DockTreeOperations.isValid(dockedLayout.root)) {
        root = dockedLayout.root;
      }
      return WorkbenchLayoutSnapshot(layout: layout, dockedRoot: root);
    }

    // Migration path for schema v1, which stored WorkbenchLayoutModel directly.
    return WorkbenchLayoutSnapshot(
      layout: WorkbenchLayoutModel.fromJson(value),
    );
  }
}

/// Versioned local persistence for workbench layout preferences.
///
/// The injected raw storage functions make debounce, flush, and corrupted-data
/// behavior testable without requiring a platform channel or SharedPreferences
/// plugin in unit tests.
class WorkbenchLayoutPersistenceController {
  WorkbenchLayoutPersistenceController({
    Future<String?> Function()? loadRaw,
    Future<void> Function(String value)? saveRaw,
    Future<void> Function()? clearRaw,
    this.debounceDuration = const Duration(milliseconds: 400),
  }) : _loadRaw = loadRaw ?? _loadFromPreferences,
       _saveRaw = saveRaw ?? _saveToPreferences,
       _clearRaw = clearRaw ?? _clearFromPreferences;

  static const storageKey = 'relgeo.workbench.layout.v1';

  final Future<String?> Function() _loadRaw;
  final Future<void> Function(String value) _saveRaw;
  final Future<void> Function() _clearRaw;
  final Duration debounceDuration;

  Timer? _timer;
  WorkbenchLayoutSnapshot? _pending;

  Future<WorkbenchLayoutModel?> load() async {
    return (await loadSnapshot())?.layout;
  }

  Future<WorkbenchLayoutSnapshot?> loadSnapshot() async {
    try {
      final raw = await _loadRaw();
      if (raw == null || raw.isEmpty) return null;
      return WorkbenchLayoutSnapshot.fromJson(jsonDecode(raw));
    } catch (_) {
      return WorkbenchLayoutSnapshot(layout: WorkbenchLayoutModel.standard());
    }
  }

  void scheduleSave(WorkbenchLayoutModel layout) {
    scheduleSnapshot(WorkbenchLayoutSnapshot(layout: layout));
  }

  void scheduleSnapshot(WorkbenchLayoutSnapshot snapshot) {
    _pending = snapshot;
    _timer?.cancel();
    _timer = Timer(debounceDuration, () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final snapshot = _pending;
    _pending = null;
    if (snapshot == null) return;
    try {
      await _saveRaw(jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Preferences are non-critical; the in-memory layout remains valid.
    }
  }

  Future<void> clear() async {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    await _clearRaw();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<String?> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  static Future<void> _saveToPreferences(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
  }

  static Future<void> _clearFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
