import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'package:relgeo_flutter/src/ui/workbench_viewport_transform.dart';

void main() {
  const bounds = BoundingBox(x: 0, y: 0, width: 100, height: 50);

  test('fit scale respects viewport padding and bounds ratio', () {
    final scale = workbenchViewportFitScale(
      viewportSize: const Size(400, 300),
      bounds: bounds,
    );

    expect(scale, 2.8);
  });

  test('center transform uses requested scale and viewport center', () {
    final transform = workbenchViewportCenterTransform(
      viewportSize: const Size(400, 300),
      bounds: bounds,
      scale: 2.0,
    );

    expect(transform.getMaxScaleOnAxis(), 2.0);
    expect(transform.entry(0, 3), 100.0);
    expect(transform.entry(1, 3), 100.0);
  });

  test('scale transform is centered around the viewport', () {
    final transform = workbenchViewportScaleAroundCenter(
      viewportSize: const Size(400, 300),
      factor: 1.2,
    );

    expect(transform.getMaxScaleOnAxis(), 1.2);
    expect(transform.entry(0, 3), -40.0);
    expect(transform.entry(1, 3), -30.0);
  });
}
