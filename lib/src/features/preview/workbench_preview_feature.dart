import 'package:flutter/material.dart';

import '../../ui/workbench_visual_profile.dart';

/// Preview feature surface.
///
/// The panel caption and overlay controls are composed here. Global viewport
/// controls live in the workbench navbar, while scene, transform, overlay, and
/// persistence state remain owned by the page.
class WorkbenchPreviewFeature extends StatelessWidget {
  const WorkbenchPreviewFeature({
    super.key,
    this.toolbar,
    required this.overlayToolbar,
    required this.panel,
    this.visualProfile = WorkbenchVisualProfile.cad,
    this.onCollapse,
    this.onFloat,
  });

  final Widget? toolbar;
  final Widget overlayToolbar;
  final Widget panel;
  final WorkbenchVisualProfile visualProfile;
  final VoidCallback? onCollapse;
  final VoidCallback? onFloat;

  @override
  Widget build(BuildContext context) {
    // Dock renderers may provide a loose cross-axis constraint to a leaf.
    // Preview must occupy the complete dock slot, just like Editor and
    // Inspector, rather than sizing itself to its controls and canvas content.
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controls = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [?toolbar, overlayToolbar],
          );
          final compact = constraints.maxHeight < 700;
          final controlsMaxHeight = (constraints.maxHeight * 0.45)
              .clamp(0.0, 240.0)
              .toDouble();
          final Widget controlsSlot = compact
              ? ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: controlsMaxHeight),
                  // Keep controls non-flex: otherwise Flutter divides the
                  // remaining height with the viewport and can leave the
                  // unused part of this loose flex slot empty below Preview.
                  child: SingleChildScrollView(child: controls),
                )
              : controls;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: visualProfile.overlayBackgroundColor,
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: visualProfile.accentColor,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        color: visualProfile.accentColor,
                      ),
                    ),
                    const Spacer(),
                    if (onFloat != null)
                      IconButton(
                        key: const Key('float-preview-panel'),
                        tooltip: 'Float Preview',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        color: visualProfile.mutedColor,
                        onPressed: onFloat,
                      ),
                    if (onCollapse != null)
                      IconButton(
                        key: const Key('collapse-preview-panel'),
                        tooltip: 'Collapse Preview',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                        color: visualProfile.mutedColor,
                        onPressed: onCollapse,
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: visualProfile.borderColor),
              controlsSlot,
              // This feature owns vertical allocation; the viewport is content
              // and must fill precisely the space left after caption/controls.
              Expanded(child: panel),
            ],
          );
        },
      ),
    );
  }
}
