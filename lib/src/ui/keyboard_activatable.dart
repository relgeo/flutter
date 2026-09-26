import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Adds consistent keyboard activation and visible focus feedback to a custom
/// workbench control.
class WorkbenchKeyboardActivatable extends StatelessWidget {
  const WorkbenchKeyboardActivatable({
    super.key,
    required this.onActivate,
    required this.focusColor,
    required this.child,
  });

  final VoidCallback onActivate;
  final Color focusColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onActivate();
            return null;
          },
        ),
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return DecoratedBox(
            decoration: BoxDecoration(
              border: hasFocus ? Border.all(color: focusColor, width: 2) : null,
            ),
            child: child,
          );
        },
      ),
    );
  }
}
