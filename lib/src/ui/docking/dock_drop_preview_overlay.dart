import 'package:flutter/material.dart';

import 'dock_drop_preview.dart';
import 'dock_node.dart';

/// Visualizes a valid dock preview without mutating the active layout.
class DockDropPreviewOverlay extends StatelessWidget {
  const DockDropPreviewOverlay({super.key, this.preview});

  final DockDropPreview? preview;

  @override
  Widget build(BuildContext context) {
    final value = preview;
    if (value == null || !value.isValid || value.rect.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    return Positioned.fromRect(
      key: const ValueKey('dock-drop-preview'),
      rect: value.rect,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            border: Border.all(color: accent, width: 2),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text(
                    _label(value),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(DockDropPreview value) {
    if (value.zone == DockZone.center) return 'Dock inside target';
    return 'Dock ${value.zone.name}';
  }
}
