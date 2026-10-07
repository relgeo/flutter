import 'package:flutter/widgets.dart';

import 'editor_panel.dart';
import 'workbench_editor_contract.dart';

/// Editor feature surface.
///
/// The page owns the document state and callbacks; this boundary owns only
/// the contract needed to render and operate the editor feature.
class WorkbenchEditorFeature extends StatelessWidget {
  const WorkbenchEditorFeature({
    super.key,
    required this.contract,
    this.onClose,
    this.onFloat,
  });

  final WorkbenchEditorContract contract;
  final VoidCallback? onClose;
  final VoidCallback? onFloat;

  @override
  Widget build(BuildContext context) {
    return EditorPanel(
      controller: contract.controller,
      visualProfile: contract.visualProfile,
      onClose: onClose,
      onFloat: onFloat,
    );
  }
}
