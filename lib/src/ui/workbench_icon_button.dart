import 'package:flutter/material.dart';

class WorkbenchIconButton extends StatelessWidget {
  const WorkbenchIconButton(
    this.icon,
    this.tooltip,
    this.onPressed, {
    super.key,
    this.color,
    this.buttonKey,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: buttonKey,
        icon: Icon(
          icon,
          color: color ?? Theme.of(context).colorScheme.onSurface,
          size: 18,
        ),
        onPressed: onPressed,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}
