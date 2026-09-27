import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/features/preview/workbench_overlay_toolbar.dart';
import 'package:relgeo_flutter/src/ui/canvas_painter.dart';
import 'package:relgeo_flutter/src/ui/workbench_visual_profile.dart';

void main() {
  testWidgets('overlay toolbar wraps without overflow at narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 416,
          child: WorkbenchOverlayToolbar(
            visualProfile: WorkbenchVisualProfile.cad,
            overlay: const OverlayOptions(),
            hiddenRoles: const {'construction'},
            followProfileOverlay: true,
            followProfileRoleFilter: true,
            onFollowProfileOverlayChanged: (_) {},
            onFollowProfileRoleFilterChanged: (_) {},
            onOverlayChanged: (_) {},
            onHiddenRolesChanged: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('IDE OVERLAY'), findsOneWidget);
    expect(find.text('ROLE FILTER'), findsOneWidget);
  });
}
