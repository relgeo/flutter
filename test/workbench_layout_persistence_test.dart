import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_persistence.dart';

void main() {
  test('persists a versioned layout and restores it', () async {
    String? raw;
    final writer = WorkbenchLayoutPersistenceController(
      loadRaw: () async => raw,
      saveRaw: (value) async => raw = value,
      clearRaw: () async => raw = null,
    );
    final layout = WorkbenchLayoutModel.standard(profileId: 'custom');

    writer.scheduleSave(layout);
    await writer.flush();

    final restored = await WorkbenchLayoutPersistenceController(
      loadRaw: () async => raw,
      saveRaw: (_) async {},
      clearRaw: () async {},
    ).load();

    expect(restored, layout);
    expect(raw, contains('schemaVersion'));
    writer.dispose();
  });

  test('debounce keeps only the latest layout', () async {
    final saved = <String>[];
    final writer = WorkbenchLayoutPersistenceController(
      saveRaw: (value) async => saved.add(value),
      debounceDuration: const Duration(milliseconds: 1),
    );

    writer.scheduleSave(WorkbenchLayoutModel.standard(profileId: 'first'));
    writer.scheduleSave(WorkbenchLayoutModel.standard(profileId: 'latest'));
    await writer.flush();

    expect(saved, hasLength(1));
    expect(saved.single, contains('latest'));
    writer.dispose();
  });

  test('corrupted persisted data safely falls back to Standard', () async {
    final writer = WorkbenchLayoutPersistenceController(
      loadRaw: () async => '{not-json',
      saveRaw: (_) async {},
      clearRaw: () async {},
    );

    expect(await writer.load(), WorkbenchLayoutModel.standard());
    writer.dispose();
  });

  test('persists and restores the recursive dock tree', () async {
    String? raw;
    final root = DockSplitNode(
      axis: DockAxis.horizontal,
      children: const [
        DockPanelNode(WorkbenchPanelId.editor),
        DockPanelNode(WorkbenchPanelId.inspector),
      ],
      ratios: const [0.6, 0.4],
    );
    final writer = WorkbenchLayoutPersistenceController(
      loadRaw: () async => raw,
      saveRaw: (value) async => raw = value,
      clearRaw: () async => raw = null,
    );

    writer.scheduleSnapshot(
      WorkbenchLayoutSnapshot(
        layout: WorkbenchLayoutModel.standard(profileId: 'custom'),
        dockedRoot: root,
      ),
    );
    await writer.flush();

    final restored = await WorkbenchLayoutPersistenceController(
      loadRaw: () async => raw,
      saveRaw: (_) async {},
      clearRaw: () async {},
    ).loadSnapshot();

    expect(restored?.layout.activeProfileId, 'custom');
    expect(restored?.dockedRoot, root);
    expect(raw, contains('dockedLayout'));
    writer.dispose();
  });

  test('reads the schema v1 layout payload without a dock tree', () async {
    final legacy = WorkbenchLayoutModel.standard(profileId: 'legacy');
    final reader = WorkbenchLayoutPersistenceController(
      loadRaw: () async => jsonEncode(legacy.toJson()),
      saveRaw: (_) async {},
      clearRaw: () async {},
    );

    final restored = await reader.loadSnapshot();

    expect(restored?.layout, legacy);
    expect(restored?.dockedRoot, isNull);
    reader.dispose();
  });

  test('unknown snapshot versions fall back safely', () async {
    final reader = WorkbenchLayoutPersistenceController(
      loadRaw: () async => jsonEncode({
        'schemaVersion': 999,
        'layout': WorkbenchLayoutModel.standard().toJson(),
      }),
      saveRaw: (_) async {},
      clearRaw: () async {},
    );

    final restored = await reader.loadSnapshot();
    expect(restored?.layout, WorkbenchLayoutModel.standard());
    expect(restored?.dockedRoot, isNull);
    reader.dispose();
  });

  test('unknown dock-tree versions preserve the layout and drop the tree', () {
    final layout = WorkbenchLayoutModel.standard(profileId: 'custom');
    final snapshot = WorkbenchLayoutSnapshot.fromJson({
      'schemaVersion': 2,
      'layout': layout.toJson(),
      'dockedLayout': {
        'schemaVersion': 999,
        'root': const DockPanelNode(WorkbenchPanelId.editor).toJson(),
      },
    });

    expect(snapshot.layout, layout);
    expect(snapshot.dockedRoot, isNull);
  });
}
