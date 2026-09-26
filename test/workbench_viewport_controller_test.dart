import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'package:relgeo_flutter/src/ui/workbench_viewport_controller.dart';

void main() {
  test('viewport controller owns transform, size, and zoom state', () {
    final controller = WorkbenchViewportController();
    addTearDown(controller.dispose);
    const bounds = BoundingBox(x: 0, y: 0, width: 100, height: 50);

    controller.setViewportSize(const Size(400, 300));
    controller.fit(bounds, fallbackViewportSize: const Size(100, 100));

    expect(controller.viewportSize, const Size(400, 300));
    expect(controller.zoomLevel, 2.8);

    expect(
      controller.zoomIn(fallbackViewportSize: const Size(100, 100)),
      isTrue,
    );
    final zoomedInLevel = controller.zoomLevel;
    expect(zoomedInLevel, greaterThan(2.8));

    expect(
      controller.zoomOut(fallbackViewportSize: const Size(100, 100)),
      isTrue,
    );
    expect(controller.zoomLevel, lessThan(zoomedInLevel));
  });
}
