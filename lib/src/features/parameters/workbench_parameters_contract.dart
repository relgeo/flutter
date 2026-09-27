import 'package:flutter/foundation.dart';

import '../../ui/workbench_visual_profile.dart';

/// Composition-facing contract for the optional document parameters panel.
///
/// Parameter availability is represented by the composition root by omitting
/// the feature from the shell when the active document has no parameters.
class WorkbenchParametersContract {
  const WorkbenchParametersContract({
    required this.paramValues,
    required this.paramOverrides,
    required this.targetUnit,
    required this.onParamChanged,
    required this.onParamReset,
    required this.visualProfile,
  });

  final Map<String, double> paramValues;
  final Map<String, dynamic> paramOverrides;
  final String targetUnit;
  final void Function(String name, double value) onParamChanged;
  final VoidCallback onParamReset;
  final WorkbenchVisualProfile visualProfile;
}
