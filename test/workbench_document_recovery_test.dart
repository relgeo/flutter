import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_document_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecoveryStorage implements WorkbenchRecoveryStorage {
  String? value;
  bool blocked = false;

  @override
  Future<String?> read() async {
    if (blocked) throw StateError('storage blocked');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (blocked) throw StateError('storage blocked');
    this.value = value;
  }

  @override
  Future<void> remove() async {
    if (blocked) throw StateError('storage blocked');
    value = null;
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('recovery store round-trips a dirty draft and identity', () async {
    const store = WorkbenchDocumentRecoveryStore();
    await store.save(
      const WorkbenchRecoveryDraft(
        documentId: 'doc-1',
        source: 'scene: {}',
        path: '/tmp/example.relgeo',
        name: 'example.relgeo',
      ),
    );

    final draft = await store.load();
    expect(draft?.documentId, 'doc-1');
    expect(draft?.source, 'scene: {}');
    expect(draft?.path, '/tmp/example.relgeo');
    expect(draft?.name, 'example.relgeo');
  });

  test(
    'clearing recovery removes stale draft and empty source is ignored',
    () async {
      const store = WorkbenchDocumentRecoveryStore();
      await store.save(
        const WorkbenchRecoveryDraft(documentId: 'doc-1', source: 'draft'),
      );
      await store.clear();
      expect(await store.load(), isNull);

      await store.save(
        const WorkbenchRecoveryDraft(documentId: 'doc-2', source: ''),
      );
      expect(await store.load(), isNull);
    },
  );

  test('corrupt recovery payload is discarded before the next launch', () async {
    final storage = _FakeRecoveryStorage()..value = '{"documentId": 7}';
    final store = WorkbenchDocumentRecoveryStore(storage: storage);

    expect(await store.load(), isNull);
    expect(storage.value, isNull);
  });

  test('blocked recovery storage never blocks editing lifecycle', () async {
    final storage = _FakeRecoveryStorage()..blocked = true;
    final store = WorkbenchDocumentRecoveryStore(storage: storage);

    await store.save(
      const WorkbenchRecoveryDraft(documentId: 'doc-1', source: 'draft'),
    );
    expect(await store.load(), isNull);
    await store.clear();
  });

  test('legacy recovery keys are readable during v2 migration', () async {
    SharedPreferences.setMockInitialValues({
      'relgeo.workbench.recovery.documentId': 'legacy-doc',
      'relgeo.workbench.recovery.source': 'scene: {}',
      'relgeo.workbench.recovery.path': '/tmp/legacy.relgeo',
      'relgeo.workbench.recovery.name': 'legacy.relgeo',
    });
    const store = WorkbenchDocumentRecoveryStore();

    final draft = await store.load();
    expect(draft?.documentId, 'legacy-doc');
    expect(draft?.source, 'scene: {}');
    expect(draft?.path, '/tmp/legacy.relgeo');
    expect(draft?.name, 'legacy.relgeo');
  });
}
