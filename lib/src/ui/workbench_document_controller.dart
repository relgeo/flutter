import 'package:flutter/foundation.dart';

import '../geometry/types.dart';

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
  Map<String, Map<String, dynamic>> _profiles =
      <String, Map<String, dynamic>>{};
  String? _activeProfile;
  String? _selectedSheetId;
  LengthUnit _targetUnit = LengthUnit.mm;

  String? get yamlError => _yamlError;
  String? get compilerError => _compilerError;
  ResolvedScene? get scene => _scene;
  Map<String, double> get paramValues => Map.unmodifiable(_paramValues);
  Map<String, dynamic> get paramOverrides => Map.unmodifiable(_paramOverrides);
  Map<String, Map<String, dynamic>> get profiles => Map.unmodifiable(
    _profiles.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.unmodifiable(value)),
    ),
  );
  String? get activeProfile => _activeProfile;
  String? get selectedSheetId => _selectedSheetId;
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
  }) {
    _paramValues = Map<String, double>.from(values);
    _paramOverrides = Map<String, dynamic>.from(overrides);
    notifyListeners();
  }

  void setParamValues(Map<String, double> values) {
    _paramValues = Map<String, double>.from(values);
    notifyListeners();
  }

  void setParamOverride(String name, dynamic value) {
    _paramOverrides[name] = value;
    notifyListeners();
  }

  void clearParamOverrides() {
    _paramOverrides.clear();
    notifyListeners();
  }

  void setParamOverrides(Map<String, dynamic> overrides) {
    _paramOverrides = Map<String, dynamic>.from(overrides);
    notifyListeners();
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
    _selectedSheetId = sheetId;
    notifyListeners();
  }

  void setTargetUnit(LengthUnit unit) {
    _targetUnit = unit;
    notifyListeners();
  }
}
