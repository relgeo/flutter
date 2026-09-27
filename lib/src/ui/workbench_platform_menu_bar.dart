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
            menus: [
              for (final command in registry.forMenu(menu))
                PlatformMenuItem(
                  label: command.label,
                  shortcut: command.shortcut,
                  onSelected: command.enabled ? command.invoke : null,
                ),
            ],
          ),
      ],
      child: child,
    );
  }
}
