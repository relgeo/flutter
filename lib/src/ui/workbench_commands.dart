import 'package:flutter/material.dart';

enum WorkbenchCommandId {
  newDocument,
  openDocument,
  saveDocument,
  exportSvg,
  copySource,
  recompileDocument,
  resetDocumentParameters,
  aboutRelGeo,
  zoomIn,
  zoomOut,
  fitViewport,
  resetViewport,
  toggleEditorPanel,
  togglePreviewPanel,
  toggleInspectorPanel,
  toggleParametersPanel,
  resetLayout,
  dockEditorLeft,
  dockPreviewCenter,
  dockInspectorRight,
  dockParametersBottom,
  floatEditor,
  floatPreview,
  floatInspector,
  floatParameters,
  overlayEditor,
  overlayPreview,
  overlayInspector,
  overlayParameters,
  standardLayoutProfile,
  writingLayoutProfile,
  previewLayoutProfile,
  inspectLayoutProfile,
  minimalLayoutProfile,
  lightTheme,
  darkTheme,
  followSystemTheme,
  resetPreferences,
}

class WorkbenchCommand {
  const WorkbenchCommand({
    required this.id,
    required this.menu,
    required this.label,
    required this.onInvoke,
    this.enabled = true,
    this.checked,
    this.shortcut,
  });

  final WorkbenchCommandId id;
  final String menu;
  final String label;
  final VoidCallback onInvoke;
  final bool enabled;
  final bool? checked;
  final MenuSerializableShortcut? shortcut;

  void invoke() {
    if (enabled) onInvoke();
  }
}

/// Shared action model for menus, toolbar buttons, shortcuts, and a future
/// command palette. Feature state remains owned by the workbench page.
class WorkbenchCommandRegistry {
  const WorkbenchCommandRegistry(this.commands);

  static const menuOrder = <String>[
    'File',
    'Edit',
    'View',
    'Appearance',
    'Document',
    'Workbench',
    'Help',
  ];

  final List<WorkbenchCommand> commands;

  Iterable<WorkbenchCommand> forMenu(String menu) =>
      commands.where((command) => command.menu == menu);

  WorkbenchCommand? find(WorkbenchCommandId id) {
    for (final command in commands) {
      if (command.id == id) return command;
    }
    return null;
  }
}
