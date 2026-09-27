import 'package:flutter/widgets.dart';

import 'editor_panel.dart';
import 'workbench_editor_contract.dart';

/// Editor feature surface.
///
/// The page owns the document state and callbacks; this boundary owns only
/// the contract needed to render and operate the editor feature.
class WorkbenchEditorFeature extends StatelessWidget {
  const WorkbenchEditorFeature({super.key, required this.contract});

  final WorkbenchEditorContract contract;

  @override
  Widget build(BuildContext context) {
    return EditorPanel(
      controller: contract.controller,
      visualProfile: contract.visualProfile,
    );
  }
}
