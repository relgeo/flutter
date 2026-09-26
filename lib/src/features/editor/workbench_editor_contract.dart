import 'package:flutter/foundation.dart';
import 'package:re_editor/re_editor.dart';

import '../../ui/workbench_visual_profile.dart';

/// Composition-facing contract for the editor feature.
///
/// The composition root owns the document controller; the editor receives only
/// the snapshot and callbacks required to render and edit it.
class WorkbenchEditorContract {
  const WorkbenchEditorContract({
    required this.controller,
    required this.paramValues,
    required this.paramOverrides,
    required this.targetUnit,
    required this.onParamChanged,
    required this.onParamReset,
    required this.visualProfile,
  });

  final CodeLineEditingController controller;
  final Map<String, double> paramValues;
  final Map<String, dynamic> paramOverrides;
  final String targetUnit;
  final void Function(String name, double value) onParamChanged;
  final VoidCallback onParamReset;
  final WorkbenchVisualProfile visualProfile;
}
