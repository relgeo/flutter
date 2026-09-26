import 'package:flutter/foundation.dart';
import 'package:re_editor/re_editor.dart';

/// Owns the editor's third-party controller at the workbench boundary.
///
/// The page consumes only the small workbench-facing surface while editor
/// widgets may still receive the native controller required by `re_editor`.
class WorkbenchEditorController {
  WorkbenchEditorController.fromText(String initialText)
      : editingController = CodeLineEditingController.fromText(initialText);

  final CodeLineEditingController editingController;

  String get text => editingController.text.toString();

  void addListener(VoidCallback listener) => editingController.addListener(listener);

  void dispose() => editingController.dispose();
}
