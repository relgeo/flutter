import 'package:flutter/material.dart';

enum WorkbenchCommandId {
  newDocument,
  openDocument,
  saveDocument,
  saveAsDocument,
  closeDocument,
  quitApplication,
  exportSvg,
  exportSvgModel,
  exportSvgSheet,
  undo,
  redo,
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
  collapseEditorPanel,
  collapsePreviewPanel,
  collapseInspectorPanel,
  collapseParametersPanel,
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
    this.shortcutActivator,
    this.submenuPath = const [],
  });

  final WorkbenchCommandId id;
  final String menu;
  final String label;
  final VoidCallback onInvoke;
  final bool enabled;
  final bool? checked;
  final MenuSerializableShortcut? shortcut;
  final ShortcutActivator? shortcutActivator;
  final List<String> submenuPath;

  void invoke() {
    if (enabled) onInvoke();
  }
}

/// Intent used by the application-wide shortcut surface.
///
/// Keeping this intent separate from menu widgets makes keyboard activation
/// use the same enabled-state and callback path as menus and toolbars.
class WorkbenchCommandIntent extends Intent {
  const WorkbenchCommandIntent(this.commandId);

  final WorkbenchCommandId commandId;
}

/// Installs the registry's keyboard bindings around the workbench.
///
/// Flutter's [MenuItemButton] handles shortcuts while a menu is active, but
/// desktop users also expect common commands to work while editing the canvas
/// or a panel. This widget provides that global path without duplicating
/// command callbacks in individual feature widgets.
class WorkbenchCommandSurface extends StatelessWidget {
  const WorkbenchCommandSurface({
    super.key,
    required this.registry,
    required this.child,
  });

  final WorkbenchCommandRegistry registry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{};
    final actions = <Type, Action<Intent>>{};
    for (final command in registry.commands) {
      final shortcut = command.shortcutActivator;
      if (shortcut == null) continue;
      shortcuts[shortcut] = WorkbenchCommandIntent(command.id);
      actions[WorkbenchCommandIntent] = CallbackAction<WorkbenchCommandIntent>(
        onInvoke: (intent) {
          registry.find(intent.commandId)?.invoke();
          return null;
        },
      );
    }

    if (shortcuts.isEmpty) return child;
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(actions: actions, child: child),
    );
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
