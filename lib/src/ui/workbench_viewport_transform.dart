import 'package:flutter/material.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

/// Builds a transform that centers a drawing bounds rectangle in the viewport.
Matrix4 workbenchViewportCenterTransform({
  required Size viewportSize,
  required BoundingBox bounds,
  required double scale,
}) {
  final boundsCenterX = bounds.width / 2;
  final boundsCenterY = bounds.height / 2;

  return Matrix4.identity()
    ..translateByDouble(viewportSize.width / 2, viewportSize.height / 2, 0, 1.0)
    ..scaleByDouble(scale, scale, scale, 1.0)
    ..translateByDouble(-boundsCenterX, -boundsCenterY, 0, 1.0);
}

/// Calculates a fit scale while preserving the workbench's viewport padding.
double workbenchViewportFitScale({
  required Size viewportSize,
  required BoundingBox bounds,
  double padding = 60.0,
}) {
  if (bounds.width < 1 || bounds.height < 1) return 0.0001;

  final scaleX = (viewportSize.width - padding * 2) / bounds.width;
  final scaleY = (viewportSize.height - padding * 2) / bounds.height;
  return (scaleX < scaleY ? scaleX : scaleY).clamp(0.0001, 10000.0).toDouble();
}

/// Builds a scale transform around the center of the viewport.
Matrix4 workbenchViewportScaleAroundCenter({
  required Size viewportSize,
  required double factor,
}) {
  final centerX = viewportSize.width / 2;
  final centerY = viewportSize.height / 2;

  return Matrix4.identity()
    ..translateByDouble(centerX, centerY, 0, 1.0)
    ..scaleByDouble(factor, factor, 1.0, 1.0)
    ..translateByDouble(-centerX, -centerY, 0, 1.0);
}
