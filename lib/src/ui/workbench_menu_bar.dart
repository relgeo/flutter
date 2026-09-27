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
            menuChildren: _buildMenuChildren(registry.forMenu(menu).toList()),
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

  List<Widget> _buildMenuChildren(List<WorkbenchCommand> commands) {
    final direct = commands.where((command) => command.submenuPath.isEmpty);
    final groups = <String>[];
    for (final command in commands) {
      if (command.submenuPath.isEmpty) continue;
      final root = command.submenuPath.first;
      if (!groups.contains(root)) groups.add(root);
    }

    return [
      ...direct.map(_menuItem),
      ...groups.map(
        (group) => SubmenuButton(
          menuChildren: _buildNestedMenu(commands, [group]),
          child: Text(group),
        ),
      ),
    ];
  }

  List<Widget> _buildNestedMenu(
    List<WorkbenchCommand> commands,
    List<String> prefix,
  ) {
    final direct = commands.where(
      (command) => _samePath(command.submenuPath, prefix),
    );
    final groups = <String>[];
    for (final command in commands) {
      if (command.submenuPath.length <= prefix.length ||
          !_startsWith(command.submenuPath, prefix)) {
        continue;
      }
      final group = command.submenuPath[prefix.length];
      if (!groups.contains(group)) groups.add(group);
    }

    return [
      ...direct.map(_menuItem),
      ...groups.map(
        (group) => SubmenuButton(
          menuChildren: _buildNestedMenu(commands, [...prefix, group]),
          child: Text(group),
        ),
      ),
    ];
  }

  Widget _menuItem(WorkbenchCommand command) {
    return MenuItemButton(
      shortcut: command.shortcut,
      onPressed: command.enabled ? command.invoke : null,
      leadingIcon: command.checked == true ? const Icon(Icons.check) : null,
      child: Text(command.label),
    );
  }

  bool _samePath(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    return _startsWith(left, right);
  }

  bool _startsWith(List<String> value, List<String> prefix) {
    if (value.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (value[index] != prefix[index]) return false;
    }
    return true;
  }
}
