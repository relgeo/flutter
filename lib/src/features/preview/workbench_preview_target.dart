import 'package:flutter/foundation.dart';

/// Describes which renderable surface the Preview panel should display.
///
/// Model and sheet/view targets are currently renderable. Component targets
/// reserve an explicit identity for the planned per-component preview without
/// pretending that renderer support already exists.
@immutable
class WorkbenchPreviewTarget {
  const WorkbenchPreviewTarget.model()
    : kind = WorkbenchPreviewTargetKind.model,
      id = null;

  const WorkbenchPreviewTarget.sheet(String sheetId)
    : kind = WorkbenchPreviewTargetKind.sheet,
      id = sheetId;

  const WorkbenchPreviewTarget.component(String componentId)
    : kind = WorkbenchPreviewTargetKind.component,
      id = componentId;

  final WorkbenchPreviewTargetKind kind;
  final String? id;

  String get label => switch (kind) {
    WorkbenchPreviewTargetKind.model => 'Model',
    WorkbenchPreviewTargetKind.sheet => 'Sheet/View: $id',
    WorkbenchPreviewTargetKind.component => 'Component: $id',
  };

  String? get sheetId => kind == WorkbenchPreviewTargetKind.sheet ? id : null;

  @override
  bool operator ==(Object other) =>
      other is WorkbenchPreviewTarget && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

enum WorkbenchPreviewTargetKind { model, sheet, component }
