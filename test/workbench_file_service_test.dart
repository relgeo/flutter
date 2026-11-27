import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_file_service.dart';

class _FakePicker implements WorkbenchFilePicker {
  WorkbenchPickedFile? pickedFile;
  String? savePath;
  int pickCount = 0;
  int saveCount = 0;

  @override
  Future<WorkbenchPickedFile?> pickDocument({
    required List<String> allowedExtensions,
  }) async {
    pickCount++;
    expect(allowedExtensions, containsAll(<String>['yaml', 'yml', 'relgeo']));
    return pickedFile;
  }

  @override
  Future<String?> saveDocument({
    required String fileName,
    required List<String> allowedExtensions,
  }) async {
    saveCount++;
    expect(fileName, isNotEmpty);
    expect(allowedExtensions, contains('relgeo'));
    return savePath;
  }
}

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

  test('opening an unsupported recent path returns null', () async {
    final file = File('${temporaryDirectory.path}/notes.txt');
    await file.writeAsString('not a RelGeo document');

    final document = await service.openDocumentAtPath(file.path);

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

  test('picker reads a path-backed result when the host omits bytes', () async {
    final file = File('${temporaryDirectory.path}/picked.relgeo');
    await file.writeAsString('scene: {}');
    final picker = _FakePicker()
      ..pickedFile = WorkbenchPickedFile(
        name: 'picked.relgeo',
        path: file.path,
      );
    final pickerService = FilePickerWorkbenchFileService(picker: picker);

    final document = await pickerService.openDocumentWithIdentity();

    expect(picker.pickCount, 1);
    expect(document?.source, 'scene: {}');
    expect(document?.path, file.path);
  });

  test('picker preserves a web-style bytes-only result', () async {
    final picker = _FakePicker()
      ..pickedFile = WorkbenchPickedFile(
        name: 'picked.relgeo',
        bytes: Uint8List.fromList(<int>[115, 99, 101, 110, 101, 58, 32, 123, 125]),
      );
    final pickerService = FilePickerWorkbenchFileService(picker: picker);

    final document = await pickerService.openDocumentWithIdentity();

    expect(document?.source, 'scene: {}');
    expect(document?.path, isNull);
  });

  test('malformed picker bytes use the stable decode error code', () async {
    final picker = _FakePicker()
      ..pickedFile = WorkbenchPickedFile(
        name: 'broken.relgeo',
        bytes: Uint8List.fromList(<int>[0xff, 0xfe]),
      );
    final pickerService = FilePickerWorkbenchFileService(picker: picker);

    await expectLater(
      pickerService.openDocumentWithIdentity(),
      throwsA(
        predicate(
          (error) =>
              error is WorkbenchDocumentFileException &&
              error.code == 'document.decode',
        ),
      ),
    );
  });

  test('save picker cancellation does not write a destination', () async {
    final picker = _FakePicker();
    final pickerService = FilePickerWorkbenchFileService(picker: picker);

    final saved = await pickerService.saveDocumentWithIdentity(
      'scene: {}',
      saveAs: true,
    );

    expect(saved, isNull);
    expect(picker.saveCount, 1);
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
