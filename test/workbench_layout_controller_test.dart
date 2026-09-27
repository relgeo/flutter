import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_controller.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_profiles.dart';

void main() {
  test(
    'panel visibility changes are observable and document availability is respected',
    () {
      final controller = WorkbenchLayoutController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.togglePanel(WorkbenchPanelId.inspector);
      expect(controller.isPanelVisible(WorkbenchPanelId.inspector), isFalse);
      expect(notifications, 1);

      controller.togglePanel(
        WorkbenchPanelId.parameters,
        availability: WorkbenchPanelAvailability.unavailable,
      );
      expect(
        controller.panel(WorkbenchPanelId.parameters).visibility,
        WorkbenchPanelVisibility.visible,
      );
      expect(notifications, 1);
    },
  );

  test(
    'collapse, placement, bounds, split ratio, and profile are independent operations',
    () {
      final controller = WorkbenchLayoutController();

      controller.toggleCollapsed(WorkbenchPanelId.preview);
      controller.setPlacement(
        WorkbenchPanelId.preview,
        WorkbenchPanelPlacement.floating,
      );
      controller.setBounds(
        WorkbenchPanelId.preview,
        const WorkbenchPanelBounds(width: 720, height: 480),
      );
      controller.setFloatingBounds(
        WorkbenchPanelId.preview,
        const WorkbenchPanelBounds(width: 720, height: 480),
      );
      controller.setSplitRatio('left', 0.4);
      controller.setActiveProfile('custom');

      expect(controller.isPanelCollapsed(WorkbenchPanelId.preview), isTrue);
      expect(
        controller.panel(WorkbenchPanelId.preview).placement,
        WorkbenchPanelPlacement.floating,
      );
      expect(controller.layout.splitRatios['left'], 0.4);
      expect(controller.layout.activeProfileId, 'custom');
    },
  );

  test('invalid split ratios and empty profile ids do not mutate state', () {
    final controller = WorkbenchLayoutController();
    final original = controller.layout;

    controller.setSplitRatio('left', 0);
    controller.setSplitRatio('left', 1.1);
    controller.setActiveProfile('');

    expect(controller.layout, original);
  });

  test(
    'built-in profile application replaces layout without document state',
    () {
      final controller = WorkbenchLayoutController();

      controller.applyProfile(WorkbenchLayoutProfiles.minimal);

      expect(controller.layout.activeProfileId, 'minimal');
      expect(
        controller.panel(WorkbenchPanelId.inspector).visibility,
        WorkbenchPanelVisibility.hidden,
      );
      expect(
        controller.panel(WorkbenchPanelId.parameters).visibility,
        WorkbenchPanelVisibility.visible,
      );
    },
  );

  test('manual layout edits move the active profile to Custom', () {
    final controller = WorkbenchLayoutController();
    controller.applyProfile(WorkbenchLayoutProfiles.writing);

    controller.setSplitRatio('left', 0.5);

    expect(controller.layout.activeProfileId, 'custom');
  });

  test('parameters can be resized within vertical bounds', () {
    final controller = WorkbenchLayoutController();

    controller.resizeParameters(80, 700);
    expect(controller.panel(WorkbenchPanelId.parameters).bounds.height, 300);
    expect(controller.layout.activeProfileId, 'custom');
  });
}
