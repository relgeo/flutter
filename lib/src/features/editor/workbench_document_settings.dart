import '../../geometry/types.dart';

/// Parsed document settings consumed by the editor and composition root.
///
/// This model keeps profile/parameter/unit parsing out of the page widget while
/// preserving the existing document-controller contract and fallback behavior.
class WorkbenchDocumentSettings {
  const WorkbenchDocumentSettings({
    required this.profiles,
    required this.paramValues,
    required this.paramOverrides,
    required this.targetUnit,
  });

  final Map<String, Map<String, dynamic>> profiles;
  final Map<String, double> paramValues;
  final Map<String, dynamic> paramOverrides;
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

    final paramValues = <String, double>{};
    final paramOverrides = <String, dynamic>{};
    final rawParameters = document['parameters'];
    if (rawParameters is Map) {
      for (final entry in rawParameters.entries) {
        final id = entry.key.toString();
        final value = entry.value;
        final parsedValue = value is num
            ? value.toDouble()
            : (value is Map && value['default'] is num
                  ? (value['default'] as num).toDouble()
                  : double.tryParse(value.toString()) ?? 50.0);
        paramValues[id] = parsedValue;
      }

      for (final id in paramValues.keys) {
        paramOverrides[id] = existingParamOverrides.containsKey(id)
            ? existingParamOverrides[id]
            : paramValues[id];
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

    return WorkbenchDocumentSettings(
      profiles: profiles,
      paramValues: paramValues,
      paramOverrides: paramOverrides,
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
