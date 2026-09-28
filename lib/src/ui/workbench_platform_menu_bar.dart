import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'workbench_commands.dart';

/// Installs the workbench command surface in the host OS menu when Flutter has
/// a native menu implementation for the current platform.
///
/// The in-window [WorkbenchMenuBar] remains the cross-platform fallback. This
/// adapter deliberately only activates on macOS for now: Linux and Windows
/// still need native runtime validation before we promise platform menus there.
class WorkbenchPlatformMenuBar extends StatelessWidget {
  const WorkbenchPlatformMenuBar({
    super.key,
    required this.registry,
    required this.child,
  });

  final WorkbenchCommandRegistry registry;
  final Widget child;

  static bool get usesNativeMenu =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (!usesNativeMenu) {
      return child;
    }

    return PlatformMenuBar(
      menus: [
        for (final menu in WorkbenchCommandRegistry.menuOrder)
          PlatformMenu(
            label: menu,
            menus: _buildMenus(registry.forMenu(menu).toList()),
          ),
      ],
      child: child,
    );
  }

  List<PlatformMenuItem> _buildMenus(List<WorkbenchCommand> commands) {
    final menus = <PlatformMenuItem>[];
    for (final command in commands.where(
      (command) => command.submenuPath.isEmpty,
    )) {
      menus.add(
        PlatformMenuItem(
          label: _labelFor(command),
          shortcut: command.shortcut,
          onSelected: command.enabled ? command.invoke : null,
        ),
      );
    }

    final groups = <String>[];
    for (final command in commands) {
      if (command.submenuPath.isNotEmpty &&
          !groups.contains(command.submenuPath.first)) {
        groups.add(command.submenuPath.first);
      }
    }
    for (final group in groups) {
      menus.add(
        PlatformMenu(label: group, menus: _buildNestedMenus(commands, [group])),
      );
    }
    return menus;
  }

  List<PlatformMenuItem> _buildNestedMenus(
    List<WorkbenchCommand> commands,
    List<String> prefix,
  ) {
    final menus = <PlatformMenuItem>[];
    for (final command in commands.where(
      (command) => _samePath(command.submenuPath, prefix),
    )) {
      menus.add(
        PlatformMenuItem(
          label: _labelFor(command),
          shortcut: command.shortcut,
          onSelected: command.enabled ? command.invoke : null,
        ),
      );
    }

    final groups = <String>[];
    for (final command in commands) {
      if (command.submenuPath.length > prefix.length &&
          _startsWith(command.submenuPath, prefix)) {
        final group = command.submenuPath[prefix.length];
        if (!groups.contains(group)) groups.add(group);
      }
    }
    for (final group in groups) {
      menus.add(
        PlatformMenu(
          label: group,
          menus: _buildNestedMenus(commands, [...prefix, group]),
        ),
      );
    }
    return menus;
  }

  bool _samePath(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    return _startsWith(left, right);
  }

  // Flutter's built-in PlatformMenuItem API does not expose a checked-state
  // property. Prefixing the native label keeps the state visible on macOS,
  // while the in-window MenuBar uses a true leading check icon.
  String _labelFor(WorkbenchCommand command) =>
      command.checked == true ? '\u2713 ${command.label}' : command.label;

  bool _startsWith(List<String> value, List<String> prefix) {
    if (value.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (value[index] != prefix[index]) return false;
    }
    return true;
  }
}
