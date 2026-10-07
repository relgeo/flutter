import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/canvas_painter.dart';
import 'package:relgeo_flutter/src/ui/workbench_navbar.dart';
import 'package:relgeo_flutter/src/features/preview/workbench_overlay_toolbar.dart';
import 'package:relgeo_flutter/src/ui/workbench_visual_profile.dart';

void main() {
  testWidgets(
    'workbench navbar preserves status without preview export action',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: WorkbenchNavbar(hasError: false))),
      );

      expect(find.text('RelGeo'), findsOneWidget);
      expect(find.text('COMPILED OK'), findsOneWidget);
      expect(find.byKey(const Key('export-svg-button')), findsNothing);
    },
  );

  testWidgets('overlay toolbar preserves semantic toggle contract', (
    WidgetTester tester,
  ) async {
    var overlay = const OverlayOptions();
    var hiddenRoles = <String>{'construction'};
    var followOverlay = true;
    var followRoles = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchOverlayToolbar(
            visualProfile: WorkbenchVisualProfile.byId('cad'),
            overlay: overlay,
            hiddenRoles: hiddenRoles,
            followProfileOverlay: followOverlay,
            followProfileRoleFilter: followRoles,
            onFollowProfileOverlayChanged: (value) => followOverlay = value,
            onFollowProfileRoleFilterChanged: (value) => followRoles = value,
            onOverlayChanged: (value) => overlay = value,
            onHiddenRolesChanged: (value) => hiddenRoles = value,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('overlay-sync-toggle')), findsOneWidget);
    expect(find.byKey(const Key('role-filter-sync-toggle')), findsOneWidget);
    expect(find.byKey(const Key('role-toggle-guide')), findsOneWidget);

    await tester.tap(find.byKey(const Key('overlay-sync-toggle')));
    await tester.tap(find.byKey(const Key('role-toggle-guide')));

    expect(followOverlay, isFalse);
    expect(hiddenRoles, contains('guide'));
  });
}
