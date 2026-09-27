import 'package:re_editor/re_editor.dart';

import '../../ui/workbench_visual_profile.dart';

/// Composition-facing contract for the editor feature.
///
/// The composition root owns the document controller; the editor receives only
/// the snapshot and callbacks required to render and edit it.
class WorkbenchEditorContract {
  const WorkbenchEditorContract({
    required this.controller,
    required this.visualProfile,
  });

  final CodeLineEditingController controller;
  final WorkbenchVisualProfile visualProfile;
}
