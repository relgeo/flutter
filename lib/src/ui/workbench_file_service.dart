import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Host boundary for opening and saving RelGeo source documents.
///
/// The workbench owns editor and compile state; a host owns the platform file
/// picker and any document identity/bookkeeping. Returning `null` means the
/// user cancelled the operation.
abstract interface class WorkbenchFileService {
  Future<String?> openDocument();

  Future<bool> saveDocument(String source, {required bool saveAs});
}

/// Portable file-picker implementation for YAML/RelGeo source files.
///
/// New/Close/Quit remain application lifecycle concerns and stay as host
/// callbacks on [CADWorkbenchPage].
class FilePickerWorkbenchFileService implements WorkbenchFileService {
  const FilePickerWorkbenchFileService({this.defaultFileName = 'relgeo.yaml'});

  final String defaultFileName;

  static const _extensions = <String>['yaml', 'yml', 'relgeo'];

  @override
  Future<String?> openDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensions,
      withData: true,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  @override
  Future<bool> saveDocument(String source, {required bool saveAs}) async {
    final bytes = Uint8List.fromList(utf8.encode(source));
    final path = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: _extensions,
      fileName: defaultFileName,
      bytes: bytes,
      lockParentWindow: true,
    );
    return path != null;
  }
}
