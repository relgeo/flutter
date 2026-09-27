import 'package:flutter/foundation.dart';

/// The panels that can participate in a RelGeo workbench layout.
enum WorkbenchPanelId {
  editor,
  preview,
  inspector,
  parameters;

  String get storageKey => name;

  static WorkbenchPanelId? fromStorageKey(Object? value) {
    if (value is! String) return null;
    for (final panel in values) {
      if (panel.storageKey == value) return panel;
    }
    return null;
  }
}

/// Runtime availability is derived from the active document, not persisted as
/// part of the user's layout preference.
enum WorkbenchPanelAvailability { available, unavailable }

enum WorkbenchPanelVisibility { visible, hidden, collapsed }

enum WorkbenchPanelPlacement { left, center, right, bottom, floating, overlay }

extension WorkbenchPanelVisibilityStorage on WorkbenchPanelVisibility {
  String get storageKey => name;
}

extension WorkbenchPanelPlacementStorage on WorkbenchPanelPlacement {
  String get storageKey => name;
}

@immutable
class WorkbenchPanelBounds {
  const WorkbenchPanelBounds({
    this.left,
    this.top,
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  });

  final double? left;
  final double? top;
  final double? width;
  final double? height;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;

  static const empty = WorkbenchPanelBounds();

  WorkbenchPanelBounds copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
    double? minWidth,
    double? maxWidth,
    double? minHeight,
    double? maxHeight,
  }) {
    return WorkbenchPanelBounds(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      minHeight: minHeight ?? this.minHeight,
      maxHeight: maxHeight ?? this.maxHeight,
    );
  }

  Map<String, Object> toJson() {
    final json = <String, Object>{};
    void add(String key, double? value) {
      if (value != null && value.isFinite && value >= 0) {
        json[key] = value;
      }
    }

    add('left', left);
    add('top', top);
    add('width', width);
    add('height', height);
    add('minWidth', minWidth);
    add('maxWidth', maxWidth);
    add('minHeight', minHeight);
    add('maxHeight', maxHeight);
    return json;
  }

  static WorkbenchPanelBounds? fromJson(Object? value) {
    if (value is! Map) return null;
    double? read(String key) {
      final candidate = value[key];
      if (candidate is num && candidate.isFinite && candidate >= 0) {
        return candidate.toDouble();
      }
      return null;
    }

    return WorkbenchPanelBounds(
      left: read('left'),
      top: read('top'),
      width: read('width'),
      height: read('height'),
      minWidth: read('minWidth'),
      maxWidth: read('maxWidth'),
      minHeight: read('minHeight'),
      maxHeight: read('maxHeight'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkbenchPanelBounds &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height &&
      other.minWidth == minWidth &&
      other.maxWidth == maxWidth &&
      other.minHeight == minHeight &&
      other.maxHeight == maxHeight;

  @override
  int get hashCode => Object.hash(
    left,
    top,
    width,
    height,
    minWidth,
    maxWidth,
    minHeight,
    maxHeight,
  );
}

@immutable
class WorkbenchPanelLayout {
  const WorkbenchPanelLayout({
    required this.visibility,
    required this.placement,
    this.bounds = WorkbenchPanelBounds.empty,
  });

  final WorkbenchPanelVisibility visibility;
  final WorkbenchPanelPlacement placement;
  final WorkbenchPanelBounds bounds;

  WorkbenchPanelLayout copyWith({
    WorkbenchPanelVisibility? visibility,
    WorkbenchPanelPlacement? placement,
    WorkbenchPanelBounds? bounds,
  }) {
    return WorkbenchPanelLayout(
      visibility: visibility ?? this.visibility,
      placement: placement ?? this.placement,
      bounds: bounds ?? this.bounds,
    );
  }

  Map<String, Object> toJson() => {
    'visibility': visibility.name,
    'placement': placement.name,
    'bounds': bounds.toJson(),
  };

  static WorkbenchPanelLayout? fromJson(Object? value) {
    if (value is! Map) return null;
    final visibility = WorkbenchPanelVisibilityExtension.fromStorageKey(
      value['visibility'],
    );
    final placement = WorkbenchPanelPlacementExtension.fromStorageKey(
      value['placement'],
    );
    if (visibility == null || placement == null) return null;
    return WorkbenchPanelLayout(
      visibility: visibility,
      placement: placement,
      bounds:
          WorkbenchPanelBounds.fromJson(value['bounds']) ??
          WorkbenchPanelBounds.empty,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkbenchPanelLayout &&
      other.visibility == visibility &&
      other.placement == placement &&
      other.bounds == bounds;

  @override
  int get hashCode => Object.hash(visibility, placement, bounds);
}

// Named helpers keep call sites readable while avoiding a dependency on
// generated enum serializers.
extension WorkbenchPanelVisibilityExtension on WorkbenchPanelVisibility {
  static WorkbenchPanelVisibility? fromStorageKey(Object? value) {
    if (value is! String) return null;
    for (final visibility in WorkbenchPanelVisibility.values) {
      if (visibility.name == value) return visibility;
    }
    return null;
  }
}

extension WorkbenchPanelPlacementExtension on WorkbenchPanelPlacement {
  static WorkbenchPanelPlacement? fromStorageKey(Object? value) {
    if (value is! String) return null;
    for (final placement in WorkbenchPanelPlacement.values) {
      if (placement.name == value) return placement;
    }
    return null;
  }
}

@immutable
class WorkbenchLayoutModel {
  WorkbenchLayoutModel({
    required this.schemaVersion,
    required this.activeProfileId,
    required Map<WorkbenchPanelId, WorkbenchPanelLayout> panels,
    required Map<String, double> splitRatios,
    required Map<WorkbenchPanelId, WorkbenchPanelBounds> floatingBounds,
  }) : panels = Map.unmodifiable(panels),
       splitRatios = Map.unmodifiable(splitRatios),
       floatingBounds = Map.unmodifiable(floatingBounds);

  static const currentSchemaVersion = 1;
  static const standardProfileId = 'standard';

  final int schemaVersion;
  final String activeProfileId;
  final Map<WorkbenchPanelId, WorkbenchPanelLayout> panels;
  final Map<String, double> splitRatios;
  final Map<WorkbenchPanelId, WorkbenchPanelBounds> floatingBounds;

  factory WorkbenchLayoutModel.standard({
    String profileId = standardProfileId,
  }) {
    return WorkbenchLayoutModel(
      schemaVersion: currentSchemaVersion,
      activeProfileId: profileId,
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
          visibility: WorkbenchPanelVisibility.visible,
          placement: WorkbenchPanelPlacement.right,
          bounds: WorkbenchPanelBounds(width: 320, minWidth: 240),
        ),
        WorkbenchPanelId.parameters: const WorkbenchPanelLayout(
          visibility: WorkbenchPanelVisibility.visible,
          placement: WorkbenchPanelPlacement.bottom,
          bounds: WorkbenchPanelBounds(height: 220, minHeight: 120),
        ),
      },
      splitRatios: const {'left': 0.32, 'center': 0.43, 'right': 0.25},
      floatingBounds: const {},
    );
  }

  WorkbenchLayoutModel copyWith({
    int? schemaVersion,
    String? activeProfileId,
    Map<WorkbenchPanelId, WorkbenchPanelLayout>? panels,
    Map<String, double>? splitRatios,
    Map<WorkbenchPanelId, WorkbenchPanelBounds>? floatingBounds,
  }) {
    return WorkbenchLayoutModel(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      panels: panels ?? this.panels,
      splitRatios: splitRatios ?? this.splitRatios,
      floatingBounds: floatingBounds ?? this.floatingBounds,
    );
  }

  /// Returns a storage-safe JSON structure. Availability is deliberately not
  /// included because it belongs to the active document, not the preference.
  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'activeProfileId': activeProfileId,
    'panels': {
      for (final entry in panels.entries)
        entry.key.storageKey: entry.value.toJson(),
    },
    'splitRatios': splitRatios,
    'floatingBounds': {
      for (final entry in floatingBounds.entries)
        entry.key.storageKey: entry.value.toJson(),
    },
  };

  /// Invalid or future data falls back to a complete Standard layout rather
  /// than producing a partially restored workbench.
  static WorkbenchLayoutModel fromJson(Object? value) {
    if (value is! Map || value['schemaVersion'] != currentSchemaVersion) {
      return WorkbenchLayoutModel.standard();
    }

    final profile = value['activeProfileId'];
    final rawPanels = value['panels'];
    final rawRatios = value['splitRatios'];
    final rawFloating = value['floatingBounds'];
    if (profile is! String || profile.isEmpty || rawPanels is! Map) {
      return WorkbenchLayoutModel.standard();
    }

    final panels = <WorkbenchPanelId, WorkbenchPanelLayout>{};
    for (final panel in WorkbenchPanelId.values) {
      final parsed = WorkbenchPanelLayout.fromJson(rawPanels[panel.storageKey]);
      if (parsed == null) return WorkbenchLayoutModel.standard();
      panels[panel] = parsed;
    }

    final ratios = <String, double>{};
    if (rawRatios is Map) {
      for (final entry in rawRatios.entries) {
        if (entry.key is! String || entry.value is! num) {
          return WorkbenchLayoutModel.standard();
        }
        final ratio = (entry.value as num).toDouble();
        if (!ratio.isFinite || ratio <= 0 || ratio > 1) {
          return WorkbenchLayoutModel.standard();
        }
        ratios[entry.key as String] = ratio;
      }
    }

    final floating = <WorkbenchPanelId, WorkbenchPanelBounds>{};
    if (rawFloating is Map) {
      for (final entry in rawFloating.entries) {
        final panel = WorkbenchPanelId.fromStorageKey(entry.key);
        final bounds = WorkbenchPanelBounds.fromJson(entry.value);
        if (panel == null || bounds == null) {
          return WorkbenchLayoutModel.standard();
        }
        floating[panel] = bounds;
      }
    }

    return WorkbenchLayoutModel(
      schemaVersion: currentSchemaVersion,
      activeProfileId: profile,
      panels: panels,
      splitRatios: ratios,
      floatingBounds: floating,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkbenchLayoutModel &&
      other.schemaVersion == schemaVersion &&
      other.activeProfileId == activeProfileId &&
      mapEquals(other.panels, panels) &&
      mapEquals(other.splitRatios, splitRatios) &&
      mapEquals(other.floatingBounds, floatingBounds);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    activeProfileId,
    Object.hashAll(panels.entries),
    Object.hashAll(splitRatios.entries),
    Object.hashAll(floatingBounds.entries),
  );
}
