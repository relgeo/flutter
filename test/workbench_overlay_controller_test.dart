import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/canvas_painter.dart';
import 'package:relgeo_flutter/src/ui/workbench_overlay_controller.dart';

void main() {
  test('manual overlay changes stop following the profile', () {
    final controller = WorkbenchOverlayController();
    addTearDown(controller.dispose);

    controller.setOverlayManual(
      const OverlayOptions(showAnchors: true, showLabels: true),
    );

    expect(controller.followProfileOverlay, isFalse);
    expect(controller.overlay.showAnchors, isTrue);
    expect(controller.overlay.showLabels, isTrue);
  });

  test('role filter state is copied defensively', () {
    final hiddenRoles = {'construction'};
    final controller = WorkbenchOverlayController(hiddenRoles: hiddenRoles);
    addTearDown(controller.dispose);

    hiddenRoles.add('debug');
    expect(controller.hiddenRoles, {'construction'});

    final exposed = controller.hiddenRoles;
    expect(() => exposed.add('mutated'), throwsUnsupportedError);
  });

  test('profile application can update one overlay concern at a time', () {
    final controller = WorkbenchOverlayController();
    addTearDown(controller.dispose);

    controller.setOverlayManual(const OverlayOptions(showAnchors: true));
    controller.setHiddenRolesManual({'construction', 'debug'});
    controller.applyProfile(
      overlay: const OverlayOptions(showLabels: true),
      hiddenRoles: {'construction'},
      includeOverlay: true,
      includeRoleFilter: false,
    );

    expect(controller.overlay.showLabels, isTrue);
    expect(controller.hiddenRoles, {'construction', 'debug'});
    expect(controller.followProfileOverlay, isFalse);
    expect(controller.followProfileRoleFilter, isFalse);
  });
}
