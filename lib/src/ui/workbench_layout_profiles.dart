import 'workbench_layout_model.dart';
import 'docking/dock_layout_adapter.dart';
import 'docking/dock_node.dart';

/// Built-in workbench arrangements. A profile keeps its compatibility layout
/// and exposes a deterministic dock-tree projection for the recursive shell.
/// Profiles never contain document source, parameter values, or compile
/// results.
class WorkbenchLayoutProfile {
  const WorkbenchLayoutProfile({
    required this.id,
    required this.label,
    required this.layout,
  });

  final String id;
  final String label;
  final WorkbenchLayoutModel layout;

  /// Canonical dock-tree baseline derived from this profile's layout.
  ///
  /// This remains a projection until tree profiles have equivalent compact
  /// layout constraints; deriving it on demand prevents two profile sources
  /// of truth from drifting during the migration.
  DockNode? get dockedRoot => DockLayoutAdapter.fromPlacementLayout(layout);
}

class WorkbenchLayoutProfiles {
  static final standard = WorkbenchLayoutProfile(
    id: 'standard',
    label: 'Standard',
    layout: WorkbenchLayoutModel.standard(),
  );

  static final writing = WorkbenchLayoutProfile(
    id: 'writing',
    label: 'Writing',
    layout: _layout(
      profileId: 'writing',
      ratios: {'left': 0.55, 'center': 0.35, 'right': 0.10},
      panels: {
        WorkbenchPanelId.editor: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.visible,
          placement: WorkbenchPanelPlacement.left,
          bounds: WorkbenchPanelBounds(width: 560, minWidth: 280),
        ),
        WorkbenchPanelId.preview: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.visible,
          placement: WorkbenchPanelPlacement.center,
          bounds: WorkbenchPanelBounds(minWidth: 360),
        ),
        WorkbenchPanelId.inspector: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.collapsed,
          placement: WorkbenchPanelPlacement.right,
          bounds: WorkbenchPanelBounds(width: 320, minWidth: 240),
        ),
      },
    ),
  );

  static final preview = WorkbenchLayoutProfile(
    id: 'preview',
    label: 'Preview',
    layout: _layout(
      profileId: 'preview',
      ratios: {'left': 0.70, 'center': 0.30},
      panels: {
        WorkbenchPanelId.editor: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.hidden,
          placement: WorkbenchPanelPlacement.left,
          bounds: WorkbenchPanelBounds(width: 420, minWidth: 280),
        ),
        WorkbenchPanelId.preview: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.visible,
          placement: WorkbenchPanelPlacement.center,
          bounds: WorkbenchPanelBounds(minWidth: 360),
        ),
        WorkbenchPanelId.inspector: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.collapsed,
          placement: WorkbenchPanelPlacement.right,
          bounds: WorkbenchPanelBounds(width: 320, minWidth: 240),
        ),
      },
    ),
  );

  static final inspect = WorkbenchLayoutProfile(
    id: 'inspect',
    label: 'Inspect',
    layout: _layout(
      profileId: 'inspect',
      ratios: {'left': 0.62, 'center': 0.38},
      panels: {
        WorkbenchPanelId.editor: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.hidden,
          placement: WorkbenchPanelPlacement.left,
          bounds: WorkbenchPanelBounds(width: 420, minWidth: 280),
        ),
        WorkbenchPanelId.preview: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.visible,
          placement: WorkbenchPanelPlacement.center,
          bounds: WorkbenchPanelBounds(minWidth: 360),
        ),
        WorkbenchPanelId.inspector: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.visible,
          placement: WorkbenchPanelPlacement.right,
          bounds: WorkbenchPanelBounds(width: 420, minWidth: 240),
        ),
      },
    ),
  );

  static final minimal = WorkbenchLayoutProfile(
    id: 'minimal',
    label: 'Minimal',
    layout: _layout(
      profileId: 'minimal',
      ratios: {'left': 0.42, 'center': 0.58},
      panels: {
        WorkbenchPanelId.editor: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.visible,
          placement: WorkbenchPanelPlacement.left,
          bounds: WorkbenchPanelBounds(width: 420, minWidth: 280),
        ),
        WorkbenchPanelId.preview: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.visible,
          placement: WorkbenchPanelPlacement.center,
          bounds: WorkbenchPanelBounds(minWidth: 360),
        ),
        WorkbenchPanelId.inspector: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.hidden,
          placement: WorkbenchPanelPlacement.right,
          bounds: WorkbenchPanelBounds(width: 320, minWidth: 240),
        ),
      },
    ),
  );

  static final all = <WorkbenchLayoutProfile>[
    standard,
    writing,
    preview,
    inspect,
    minimal,
  ];

  static WorkbenchLayoutProfile? byId(String id) {
    for (final profile in all) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  static WorkbenchLayoutModel _layout({
    required String profileId,
    required Map<String, double> ratios,
    required Map<WorkbenchPanelId, WorkbenchPanelLayout> panels,
  }) {
    final standard = WorkbenchLayoutModel.standard(profileId: profileId);
    return standard.copyWith(
      panels: {...standard.panels, ...panels},
      splitRatios: ratios,
    );
  }
}
