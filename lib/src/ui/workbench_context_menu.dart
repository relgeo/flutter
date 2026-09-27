import 'package:flutter/material.dart';

import 'workbench_commands.dart';

/// Provides a desktop context menu whose actions come from the workbench
/// command registry.
///
/// The context menu is deliberately small and surface-oriented. It does not
/// create a second action implementation; enabled state, checkmarks, and
/// callbacks are read directly from [WorkbenchCommandRegistry].
class WorkbenchCommandContextMenu extends StatefulWidget {
  const WorkbenchCommandContextMenu({
    super.key,
    required this.registry,
    required this.child,
    this.commandIds = _defaultCommandIds,
  });

  final WorkbenchCommandRegistry registry;
  final Widget child;
  final List<WorkbenchCommandId> commandIds;

  static const _defaultCommandIds = <WorkbenchCommandId>[
    WorkbenchCommandId.copySource,
    WorkbenchCommandId.recompileDocument,
    WorkbenchCommandId.zoomIn,
    WorkbenchCommandId.zoomOut,
    WorkbenchCommandId.fitViewport,
    WorkbenchCommandId.resetViewport,
    WorkbenchCommandId.exportSvgModel,
    WorkbenchCommandId.exportSvgSheet,
  ];

  @override
  State<WorkbenchCommandContextMenu> createState() =>
      _WorkbenchCommandContextMenuState();
}

class _WorkbenchCommandContextMenuState
    extends State<WorkbenchCommandContextMenu> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final commands = widget.commandIds
        .map(widget.registry.find)
        .whereType<WorkbenchCommand>()
        .toList();

    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        for (final command in commands)
          MenuItemButton(
            leadingIcon: command.checked == true
                ? const Icon(Icons.check)
                : null,
            onPressed: command.enabled ? command.invoke : null,
            child: Text(command.label),
          ),
      ],
      builder: (context, controller, child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) {
          controller.open(position: details.localPosition);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}
