import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/cad_workbench.dart';
import 'package:relgeo_flutter/src/ui/workbench_file_service.dart';
import 'package:relgeo_flutter/src/ui/workbench_recent_documents.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = '''
scene:
  title: Recent document
  objects:
    point_a:
      type: point
      at: [0, 0]
''';

class _RecentFileService implements WorkbenchRecentDocumentFileService {
  String? openedPath;

  @override
  Future<String?> openDocument() async => _source;

  @override
  Future<WorkbenchDocumentFile?> openDocumentWithIdentity() async =>
      const WorkbenchDocumentFile(
        source: _source,
        path: '/documents/recent.relgeo',
        name: 'recent.relgeo',
      );

  @override
  Future<WorkbenchDocumentFile?> openDocumentAtPath(String path) async {
    openedPath = path;
    return WorkbenchDocumentFile(
      source: _source,
      path: path,
      name: 'recent.relgeo',
    );
  }

  @override
  Future<bool> saveDocument(String source, {required bool saveAs}) async =>
      true;

  @override
  Future<WorkbenchDocumentFile?> saveDocumentWithIdentity(
    String source, {
    required bool saveAs,
    String? currentPath,
    String? currentName,
  }) async => WorkbenchDocumentFile(
    source: source,
    path: currentPath ?? '/documents/recent.relgeo',
    name: currentName ?? 'recent.relgeo',
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('recent store de-duplicates paths and keeps newest first', () async {
    const store = WorkbenchRecentDocumentsStore(maxItems: 2);
    await store.record(
      const WorkbenchRecentDocument(path: '/a.relgeo', name: 'a.relgeo'),
    );
    await store.record(
      const WorkbenchRecentDocument(path: '/b.relgeo', name: 'b.relgeo'),
    );
    await store.record(
      const WorkbenchRecentDocument(path: '/a.relgeo', name: 'a.relgeo'),
    );

    final recent = await store.load();
    expect(recent.map((item) => item.path), <String>['/a.relgeo', '/b.relgeo']);
  });

  testWidgets('File Recent opens a persisted document', (tester) async {
    final encoded = jsonEncode(
      const WorkbenchRecentDocument(
        path: '/documents/recent.relgeo',
        name: 'recent.relgeo',
      ).toJson(),
    );
    SharedPreferences.setMockInitialValues({
      WorkbenchRecentDocumentsStore.storageKey: <String>[encoded],
    });
    final service = _RecentFileService();

    await tester.pumpWidget(
      MaterialApp(
        home: CADWorkbenchPage(initialDsl: _source, fileService: service),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('File'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Recent'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('recent.relgeo'), findsOneWidget);

    await tester.tap(find.text('recent.relgeo'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.openedPath, '/documents/recent.relgeo');
    expect(find.textContaining('Recent document'), findsOneWidget);
  });
}
