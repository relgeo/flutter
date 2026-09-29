import 'package:flutter/material.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

import '../../ui/grid_painter.dart';
import '../../ui/relgeo_theme_extension.dart';
import '../../ui/workbench_bounds_badge.dart';
import '../../ui/workbench_status_badge.dart';
import '../../ui/workbench_visual_profile.dart';

/// Presents the interactive workbench viewport without owning scene state.
class WorkbenchViewportPanel extends StatelessWidget {
  const WorkbenchViewportPanel({
    super.key,
    required this.visualProfile,
    required this.viewportController,
    required this.scene,
    required this.displayBounds,
    required this.overlay,
    required this.zoomLevel,
    required this.selectedSheetId,
    required this.hiddenRoles,
    required this.onViewportSizeChanged,
    required this.activeSheetPhysicalTargetLabel,
    required this.activeSheetViewSummaryLabel,
  });

  final WorkbenchVisualProfile visualProfile;
  final TransformationController viewportController;
  final ResolvedScene? scene;
  final BoundingBox? displayBounds;
  final OverlayOptions overlay;
  final double zoomLevel;
  final String? selectedSheetId;
  final Set<String> hiddenRoles;
  final ValueChanged<Size> onViewportSizeChanged;
  final String? activeSheetPhysicalTargetLabel;
  final String? activeSheetViewSummaryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: visualProfile.viewportBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          onViewportSizeChanged(
            Size(constraints.maxWidth, constraints.maxHeight),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(
                    transform: viewportController.value.clone(),
                    bbox: displayBounds,
                    minorColor: visualProfile.gridMinorColor,
                    majorColor: visualProfile.gridMajorColor,
                    baseWorldStep: visualProfile.behavior.baseGridWorldStep,
                  ),
                ),
              ),
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: viewportController,
                  boundaryMargin: const EdgeInsets.all(10000),
                  minScale: 0.0001,
                  maxScale: 10000.0,
                  child: scene != null
                      ? SizedBox(
                          width: displayBounds!.width,
                          height: displayBounds!.height,
                          child: CustomPaint(
                            key: const Key('scene-canvas'),
                            painter: CanvasPainter(
                              scene: scene!,
                              backgroundColor:
                                  visualProfile.viewportBackgroundColor,
                              overlay: overlay,
                              zoomScale: zoomLevel,
                              sheetId: selectedSheetId,
                              hiddenRoles: hiddenRoles,
                              visualProfile: visualProfile,
                              themeTokens: Theme.of(
                                context,
                              ).extension<RelGeoThemeExtension>(),
                            ),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00FFCC),
                          ),
                        ),
                ),
              ),
              if (scene != null)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: WorkbenchBoundsBadge(
                    bounds: Rect.fromLTWH(
                      displayBounds!.x,
                      displayBounds!.y,
                      displayBounds!.width,
                      displayBounds!.height,
                    ),
                    unit: scene!.unit.name,
                    backgroundColor: visualProfile.toolbarBackgroundColor,
                    borderColor: visualProfile.borderColor,
                  ),
                ),
              if (scene != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: WorkbenchStatusBadge(
                    key: const Key('preview-surface-badge'),
                    label: selectedSheetId != null
                        ? 'PHYSICAL PREVIEW · $selectedSheetId'
                        : 'MODEL PREVIEW',
                    backgroundColor: visualProfile.toolbarBackgroundColor,
                    borderColor: selectedSheetId != null
                        ? const Color(0xFF10B981)
                        : visualProfile.borderColor,
                    textColor: selectedSheetId != null
                        ? const Color(0xFF10B981)
                        : visualProfile.accentColor,
                  ),
                ),
              if (activeSheetPhysicalTargetLabel != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: WorkbenchStatusBadge(
                    key: const Key('physical-target-badge'),
                    label: activeSheetPhysicalTargetLabel!,
                    backgroundColor: visualProfile.toolbarBackgroundColor,
                    borderColor: const Color(0x5510B981),
                    textColor: const Color(0xFF10B981),
                  ),
                ),
              if (activeSheetViewSummaryLabel != null)
                Positioned(
                  top: 44,
                  right: 12,
                  child: WorkbenchStatusBadge(
                    key: const Key('physical-view-summary-badge'),
                    label: activeSheetViewSummaryLabel!,
                    backgroundColor: visualProfile.toolbarBackgroundColor,
                    borderColor: visualProfile.borderColor,
                    textColor: visualProfile.accentColor,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
