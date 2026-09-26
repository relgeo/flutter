import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_editor_controller.dart';

void main() {
  test('exposes initial text through the workbench boundary', () {
    final controller = WorkbenchEditorController.fromText('scene: demo');

    expect(controller.text, 'scene: demo');

    controller.dispose();
  });

  test('forwards editor notifications', () {
    final controller = WorkbenchEditorController.fromText('scene: demo');
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.editingController.text = 'scene: updated';

    expect(notifications, greaterThan(0));
    expect(controller.text, 'scene: updated');

    controller.dispose();
  });
}
