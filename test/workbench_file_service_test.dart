import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_file_service.dart';

void main() {
  late Directory temporaryDirectory;
  late FilePickerWorkbenchFileService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'relgeo-file-service-',
    );
    service = const FilePickerWorkbenchFileService();
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'Save writes to the active path without opening a save picker',
    () async {
      final file = File('${temporaryDirectory.path}/drawing.relgeo');
      await file.writeAsString('old source');

      final saved = await service.saveDocumentWithIdentity(
        'scene:\n  objects: {}\n',
        saveAs: false,
        currentPath: file.path,
        currentName: 'drawing.relgeo',
      );

      expect(saved?.path, file.path);
      expect(saved?.name, 'drawing.relgeo');
      expect(await file.readAsString(), 'scene:\n  objects: {}\n');
    },
  );

  test('opening a missing recent path returns null', () async {
    final document = await service.openDocumentAtPath(
      '${temporaryDirectory.path}/missing.relgeo',
    );

    expect(document, isNull);
  });

  test('opening an existing recent path returns source and identity', () async {
    final file = File('${temporaryDirectory.path}/drawing.relgeo');
    await file.writeAsString('scene: {}');

    final document = await service.openDocumentAtPath(file.path);

    expect(document?.source, 'scene: {}');
    expect(document?.path, file.path);
    expect(document?.name, 'drawing.relgeo');
  });

  test(
    'recent read errors are surfaced instead of deleting the recent entry',
    () async {
      final file = File('${temporaryDirectory.path}/invalid.relgeo');
      await file.writeAsBytes(<int>[0xff, 0xfe]);

      await expectLater(
        service.openDocumentAtPath(file.path),
        throwsA(anything),
      );
    },
  );
}
