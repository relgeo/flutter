import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'workbench_layout_model.dart';

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
  WorkbenchLayoutModel? _pending;

  Future<WorkbenchLayoutModel?> load() async {
    try {
      final raw = await _loadRaw();
      if (raw == null || raw.isEmpty) return null;
      return WorkbenchLayoutModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return WorkbenchLayoutModel.standard();
    }
  }

  void scheduleSave(WorkbenchLayoutModel layout) {
    _pending = layout;
    _timer?.cancel();
    _timer = Timer(debounceDuration, () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final layout = _pending;
    _pending = null;
    if (layout == null) return;
    try {
      await _saveRaw(jsonEncode(layout.toJson()));
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
