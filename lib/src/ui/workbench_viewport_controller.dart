import 'package:flutter/material.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

import 'workbench_viewport_transform.dart';

/// Owns viewport transform lifecycle, size, and zoom navigation state.
class WorkbenchViewportController extends ChangeNotifier {
  WorkbenchViewportController() {
    transformationController.addListener(_handleTransformChanged);
  }

  final TransformationController transformationController =
      TransformationController();

  double _zoomLevel = 1.0;
  Size? _viewportSize;

  double get zoomLevel => _zoomLevel;
  Size? get viewportSize => _viewportSize;

  void setViewportSize(Size size) {
    _viewportSize = size;
  }

  void reset(
    BoundingBox bounds, {
    required Size fallbackViewportSize,
  }) {
    transformationController.value = workbenchViewportCenterTransform(
      viewportSize: _resolvedViewportSize(fallbackViewportSize),
      bounds: bounds,
      scale: 1.0,
    );
  }

  void fit(
    BoundingBox bounds, {
    required Size fallbackViewportSize,
  }) {
    final viewport = _resolvedViewportSize(fallbackViewportSize);
    final scale = workbenchViewportFitScale(
      viewportSize: viewport,
      bounds: bounds,
    );
    transformationController.value = workbenchViewportCenterTransform(
      viewportSize: viewport,
      bounds: bounds,
      scale: scale,
    );
  }

  bool zoomIn({required Size fallbackViewportSize}) {
    if (transformationController.value.getMaxScaleOnAxis() >= 20.0) {
      return false;
    }
    _scaleAroundViewport(1.2, fallbackViewportSize);
    return true;
  }

  bool zoomOut({required Size fallbackViewportSize}) {
    if (transformationController.value.getMaxScaleOnAxis() <= 0.05) {
      return false;
    }
    _scaleAroundViewport(0.8, fallbackViewportSize);
    return true;
  }

  Size _resolvedViewportSize(Size fallback) => _viewportSize ?? fallback;

  void _scaleAroundViewport(double factor, Size fallbackViewportSize) {
    final zoomMatrix = workbenchViewportScaleAroundCenter(
      viewportSize: _resolvedViewportSize(fallbackViewportSize),
      factor: factor,
    );
    transformationController.value =
        zoomMatrix * transformationController.value;
  }

  void _handleTransformChanged() {
    _zoomLevel = transformationController.value.getMaxScaleOnAxis();
    notifyListeners();
  }

  @override
  void dispose() {
    transformationController.removeListener(_handleTransformChanged);
    transformationController.dispose();
    super.dispose();
  }
}
