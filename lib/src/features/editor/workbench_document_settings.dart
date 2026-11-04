import '../../core/units.dart';
import '../../geometry/types.dart';

/// Numeric parameter metadata shared by the parameter editor and inspector.
///
/// The resolver remains authoritative for evaluation. This metadata only
/// describes the editable UI envelope declared by the active document.
class WorkbenchParameterSpec {
  const WorkbenchParameterSpec({
    required this.id,
    required this.type,
    this.label,
    this.category,
    this.description,
    this.min,
    this.max,
    this.step,
  });

  final String id;
  final String type;
  final String? label;
  final String? category;
  final String? description;
  final double? min;
  final double? max;
  final double? step;

  String get displayLabel => label == null || label!.isEmpty ? id : label!;
}

/// Parsed document settings consumed by the editor and composition root.
///
/// This model keeps profile/parameter/unit parsing out of the page widget while
/// preserving the existing document-controller contract and fallback behavior.
class WorkbenchDocumentSettings {
  const WorkbenchDocumentSettings({
    required this.profiles,
    required this.paramValues,
    required this.paramOverrides,
    this.parameterSpecs = const <String, WorkbenchParameterSpec>{},
    required this.targetUnit,
  });

  final Map<String, Map<String, dynamic>> profiles;
  final Map<String, double> paramValues;
  final Map<String, dynamic> paramOverrides;
  final Map<String, WorkbenchParameterSpec> parameterSpecs;
  final LengthUnit targetUnit;

  factory WorkbenchDocumentSettings.fromDocument(
    Map<dynamic, dynamic> document, {
    required Map<String, dynamic> existingParamOverrides,
    required LengthUnit currentTargetUnit,
  }) {
    final profiles = <String, Map<String, dynamic>>{};
    final rawProfiles = document['profiles'];
    if (rawProfiles is Map) {
      for (final entry in rawProfiles.entries) {
        if (entry.value is Map) {
          profiles[entry.key.toString()] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
      }
    }

    var targetUnit = currentTargetUnit;
    final scene = document['scene'];
    if (scene is Map && scene['unit'] != null) {
      targetUnit = LengthUnit.values.firstWhere(
        (unit) => unit.name == scene['unit'].toString(),
        orElse: () => LengthUnit.mm,
      );
    }

    final paramValues = <String, double>{};
    final paramOverrides = <String, dynamic>{};
    final parameterSpecs = <String, WorkbenchParameterSpec>{};
    final rawParameters = document['parameters'];
    if (rawParameters is Map) {
      for (final entry in rawParameters.entries) {
        final id = entry.key.toString();
        final value = entry.value;
        final rawDefault = value is Map && value.containsKey('default')
            ? value['default']
            : value;
        final normalizedDefault = normalizeUnit(rawDefault, targetUnit);
        if (normalizedDefault is! num || !normalizedDefault.isFinite) {
          continue;
        }

        double? numericField(String key) {
          if (value is! Map || !value.containsKey(key)) return null;
          final normalized = normalizeUnit(value[key], targetUnit);
          return normalized is num && normalized.isFinite
              ? normalized.toDouble()
              : null;
        }

        paramValues[id] = normalizedDefault.toDouble();
        parameterSpecs[id] = WorkbenchParameterSpec(
          id: id,
          type: value is Map && value['type'] != null
              ? value['type'].toString()
              : 'number',
          label: value is Map ? value['label']?.toString() : null,
          category: value is Map ? value['category']?.toString() : null,
          description: value is Map ? value['description']?.toString() : null,
          min: numericField('min'),
          max: numericField('max'),
          step: numericField('step'),
        );
      }

      for (final id in paramValues.keys) {
        paramOverrides[id] = existingParamOverrides.containsKey(id)
            ? existingParamOverrides[id]
            : paramValues[id];
      }
    }

    return WorkbenchDocumentSettings(
      profiles: profiles,
      paramValues: paramValues,
      paramOverrides: paramOverrides,
      parameterSpecs: parameterSpecs,
      targetUnit: targetUnit,
    );
  }

  /// Returns overrides after selecting a document profile.
  ///
  /// Existing behavior is intentionally retained: selecting a profile updates
  /// only parameters present in that profile; clearing the profile resets all
  /// overrides.
  Map<String, dynamic> overridesForProfile(String? profileName) {
    if (profileName == null || !profiles.containsKey(profileName)) {
      return <String, dynamic>{};
    }

    final overrides = <String, dynamic>{...paramOverrides};
    for (final entry in profiles[profileName]!.entries) {
      if (paramValues.containsKey(entry.key)) {
        overrides[entry.key] = entry.value is num
            ? (entry.value as num).toDouble()
            : entry.value;
      }
    }
    return overrides;
  }
}
