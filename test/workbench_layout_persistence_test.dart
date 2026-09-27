import 'package:flutter_test/flutter_test.dart';
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
}
