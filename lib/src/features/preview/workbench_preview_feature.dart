import 'package:flutter/widgets.dart';

/// Preview feature surface.
///
/// The viewport controls and rendered panel are composed here, while scene,
/// transform, overlay, and persistence state remain owned by the page.
class WorkbenchPreviewFeature extends StatelessWidget {
  const WorkbenchPreviewFeature({
    super.key,
    required this.toolbar,
    required this.overlayToolbar,
    required this.panel,
  });

  final Widget toolbar;
  final Widget overlayToolbar;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [toolbar, overlayToolbar],
        );
        final controlsSlot = constraints.maxHeight < 700
            ? Flexible(
                fit: FlexFit.loose,
                // The two control bands can become tall at compact widths.
                // Let them scroll instead of overflowing a short window.
                child: SingleChildScrollView(child: controls),
              )
            : controls;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            controlsSlot,
            // The viewport panel owns the remaining flex slot.
            panel,
          ],
        );
      },
    );
  }
}
