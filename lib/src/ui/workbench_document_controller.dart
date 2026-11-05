import 'package:flutter/foundation.dart';

import '../geometry/types.dart';
import '../features/preview/workbench_preview_target.dart';
import '../features/editor/workbench_document_settings.dart';

/// Owns the compiled document state consumed by workbench surfaces.
///
/// Editor text and persistence remain outside this controller. This boundary
/// keeps compilation results, parameter overrides, profiles, sheet selection,
/// and target units independent from the page composition widget.
class WorkbenchDocumentController extends ChangeNotifier {
  String? _yamlError;
  String? _compilerError;
  ResolvedScene? _scene;
  Map<String, double> _paramValues = <String, double>{};
  Map<String, dynamic> _paramOverrides = <String, dynamic>{};
  Map<String, WorkbenchParameterSpec> _parameterSpecs =
      <String, WorkbenchParameterSpec>{};
  Map<String, Map<String, dynamic>> _profiles =
      <String, Map<String, dynamic>>{};
  String? _activeProfile;
  WorkbenchPreviewTarget _previewTarget = const WorkbenchPreviewTarget.model();
  LengthUnit _targetUnit = LengthUnit.mm;

  String? get yamlError => _yamlError;
  String? get compilerError => _compilerError;
  ResolvedScene? get scene => _scene;
  Map<String, double> get paramValues => Map.unmodifiable(_paramValues);
  Map<String, dynamic> get paramOverrides => Map.unmodifiable(_paramOverrides);
  Map<String, WorkbenchParameterSpec> get parameterSpecs =>
      Map.unmodifiable(_parameterSpecs);
  Map<String, Map<String, dynamic>> get profiles => Map.unmodifiable(
    _profiles.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.unmodifiable(value)),
    ),
  );
  String? get activeProfile => _activeProfile;
  WorkbenchPreviewTarget get previewTarget => _previewTarget;
  String? get selectedSheetId => _previewTarget.sheetId;
  LengthUnit get targetUnit => _targetUnit;

  void beginCompile() {
    _yamlError = null;
    _compilerError = null;
    notifyListeners();
  }

  void setProfiles(Map<String, Map<String, dynamic>> profiles) {
    _profiles = profiles.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
    );
    if (_activeProfile != null && !_profiles.containsKey(_activeProfile)) {
      _activeProfile = null;
    }
    notifyListeners();
  }

  void setParameters({
    required Map<String, double> values,
    required Map<String, dynamic> overrides,
    Map<String, WorkbenchParameterSpec> specs =
        const <String, WorkbenchParameterSpec>{},
  }) {
    _paramValues = Map<String, double>.from(values);
    _parameterSpecs = Map<String, WorkbenchParameterSpec>.from(specs);
    _paramOverrides = _sanitizeOverrides(overrides);
    notifyListeners();
  }

  void setParamValues(Map<String, double> values) {
    _paramValues = Map<String, double>.from(values);
    _paramOverrides = _sanitizeOverrides(_paramOverrides);
    notifyListeners();
  }

  void setParamOverride(String name, dynamic value) {
    if (!_paramValues.containsKey(name)) return;
    final normalized = _normalizeOverride(name, value);
    if (normalized == null) return;
    _paramOverrides[name] = normalized;
    notifyListeners();
  }

  void clearParamOverrides() {
    _paramOverrides.clear();
    notifyListeners();
  }

  void setParamOverrides(Map<String, dynamic> overrides) {
    _paramOverrides = _sanitizeOverrides(overrides);
    notifyListeners();
  }

  Map<String, dynamic> _sanitizeOverrides(Map<String, dynamic> overrides) {
    final sanitized = <String, dynamic>{};
    for (final entry in overrides.entries) {
      final normalized = _normalizeOverride(entry.key, entry.value);
      if (normalized != null) sanitized[entry.key] = normalized;
    }
    return sanitized;
  }

  double? _normalizeOverride(String name, dynamic value) {
    if (!_paramValues.containsKey(name) || value is! num || !value.isFinite) {
      return null;
    }
    final normalized = value.toDouble();
    final spec = _parameterSpecs[name];
    if (spec != null && !spec.accepts(normalized)) return null;
    return normalized;
  }

  void setScene(ResolvedScene? scene) {
    _scene = scene;
    notifyListeners();
  }

  void setYamlError(String? error) {
    _yamlError = error;
    notifyListeners();
  }

  void setCompilerError(String? error) {
    _compilerError = error;
    notifyListeners();
  }

  void setActiveProfile(String? profileName) {
    _activeProfile = profileName;
    notifyListeners();
  }

  void setSelectedSheetId(String? sheetId) {
    setPreviewTarget(
      sheetId == null
          ? const WorkbenchPreviewTarget.model()
          : WorkbenchPreviewTarget.sheet(sheetId),
    );
  }

  void setPreviewTarget(WorkbenchPreviewTarget target) {
    if (_previewTarget == target) return;
    _previewTarget = target;
    notifyListeners();
  }

  void setTargetUnit(LengthUnit unit) {
    _targetUnit = unit;
    notifyListeners();
  }
}
