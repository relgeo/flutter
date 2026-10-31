import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_document_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
