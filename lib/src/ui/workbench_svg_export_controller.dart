import 'dart:io';

import 'package:file_picker/file_picker.dart';

typedef WorkbenchPickSvgFile =
    Future<String?> Function({
      required String dialogTitle,
      required String fileName,
    });

typedef WorkbenchWriteTextFile =
    Future<void> Function(String path, String contents);

Future<String?> _pickSvgFile({
  required String dialogTitle,
  required String fileName,
}) {
  return FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    allowedExtensions: ['svg'],
    type: FileType.custom,
  );
}

Future<void> _writeTextFile(String path, String contents) {
  return File(path).writeAsString(contents);
}

/// Keeps native file selection and filesystem writes outside the composition
/// page while preserving the existing SVG export contract.
class WorkbenchSvgExportController {
  WorkbenchSvgExportController({
    WorkbenchPickSvgFile? pickFile,
    WorkbenchWriteTextFile? writeFile,
  }) : _pickFile = pickFile ?? _pickSvgFile,
       _writeFile = writeFile ?? _writeTextFile;

  final WorkbenchPickSvgFile _pickFile;
  final WorkbenchWriteTextFile _writeFile;

  Future<String?> saveSvg({
    required String dialogTitle,
    required String fileName,
    required String svg,
  }) async {
    final outputFile = await _pickFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
    );
    if (outputFile == null) return null;

    await _writeFile(outputFile, svg);
    return outputFile;
  }
}
