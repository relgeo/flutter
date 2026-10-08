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

  /// Replaces the active document and prevents undo from crossing document
  /// boundaries. User edits continue to use the editor's normal undo history.
  void replaceDocument(String source) {
    editingController.text = source;
    editingController.clearHistory();
  }

  /// Replaces the active source once and preserves the editor undo history.
  ///
  /// Session/document guards belong to the MCP bridge; this method is only
  /// the editor-side atomic operation used after those guards pass.
  void applyAgentSource(String source) {
    if (text == source) return;
    editingController.text = source;
  }

  void addListener(VoidCallback listener) =>
      editingController.addListener(listener);

  void dispose() => editingController.dispose();
}
