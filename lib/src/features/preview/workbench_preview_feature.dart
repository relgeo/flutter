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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // The viewport panel already owns the flex slot required by the
      // composition row. Do not attach a second ParentDataWidget here.
      children: [toolbar, overlayToolbar, panel],
    );
  }
}
