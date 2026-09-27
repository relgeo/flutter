import 'package:flutter/material.dart';

import 'workbench_commands.dart';

class WorkbenchMenuBar extends StatelessWidget {
  const WorkbenchMenuBar({super.key, required this.registry});

  final WorkbenchCommandRegistry registry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final menus = WorkbenchCommandRegistry.menuOrder
        .map(
          (menu) => SubmenuButton(
            menuChildren: registry
                .forMenu(menu)
                .map(
                  (command) => MenuItemButton(
                    shortcut: command.shortcut,
                    onPressed: command.enabled ? command.invoke : null,
                    child: Text(command.label),
                  ),
                )
                .toList(),
            child: Text(menu),
          ),
        )
        .toList();

    return Container(
      height: 32,
      color: colorScheme.surfaceContainer,
      alignment: Alignment.centerLeft,
      child: MenuBar(
        key: const Key('workbench-menu-bar'),
        style: MenuStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 6),
          ),
          backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainer),
        ),
        children: menus,
      ),
    );
  }
}
