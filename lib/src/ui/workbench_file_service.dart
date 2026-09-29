import 'dart:io';
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

/// Request passed to a host-owned asynchronous Save or Save As operation.
class WorkbenchDocumentSaveRequest {
  const WorkbenchDocumentSaveRequest({
    required this.source,
    required this.saveAs,
    this.currentPath,
    this.currentName,
  });

  final String source;
  final bool saveAs;
  final String? currentPath;
  final String? currentName;
}

/// Result returned by a host-owned asynchronous Save operation.
class WorkbenchDocumentSaveResult {
  const WorkbenchDocumentSaveResult({
    required this.saved,
    this.path,
    this.name,
  });

  final bool saved;
  final String? path;
  final String? name;
}

typedef WorkbenchDocumentSaveHandler =
    Future<WorkbenchDocumentSaveResult> Function(
      WorkbenchDocumentSaveRequest request,
    );

/// Source and identity returned by a file service that can track documents.
///
/// Web hosts may not have a filesystem path, so [path] is intentionally
/// nullable. [name] remains useful for a tab, window title, or suggested save
/// filename in those hosts.
class WorkbenchDocumentFile {
  const WorkbenchDocumentFile({required this.source, this.path, this.name});

  final String source;
  final String? path;
  final String? name;
}

/// Optional extension for hosts that can preserve document identity.
///
/// Implementing this extension does not replace [WorkbenchFileService], so
/// existing integrations can migrate without a breaking API change.
abstract interface class WorkbenchDocumentFileService
    implements WorkbenchFileService {
  Future<WorkbenchDocumentFile?> openDocumentWithIdentity();

  Future<WorkbenchDocumentFile?> saveDocumentWithIdentity(
    String source, {
    required bool saveAs,
    String? currentPath,
    String? currentName,
  });
}

/// Optional extension used by the File → Recent menu.
abstract interface class WorkbenchRecentDocumentFileService
    implements WorkbenchDocumentFileService {
  Future<WorkbenchDocumentFile?> openDocumentAtPath(String path);
}

/// Portable file-picker implementation for YAML/RelGeo source files.
///
/// New/Close/Quit remain application lifecycle concerns and stay as host
/// callbacks on [CADWorkbenchPage].
class FilePickerWorkbenchFileService
    implements WorkbenchRecentDocumentFileService {
  const FilePickerWorkbenchFileService({this.defaultFileName = 'relgeo.yaml'});

  final String defaultFileName;

  static const _extensions = <String>['yaml', 'yml', 'relgeo'];

  @override
  Future<String?> openDocument() async {
    final document = await openDocumentWithIdentity();
    return document?.source;
  }

  @override
  Future<WorkbenchDocumentFile?> openDocumentWithIdentity() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensions,
      withData: true,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw FileSystemException('The selected document could not be read.');
    }
    return WorkbenchDocumentFile(
      source: utf8.decode(bytes),
      path: file.path,
      name: file.name,
    );
  }

  @override
  Future<WorkbenchDocumentFile?> openDocumentAtPath(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return WorkbenchDocumentFile(
      source: await file.readAsString(),
      path: path,
      name: _fileName(path) ?? path,
    );
  }

  @override
  Future<bool> saveDocument(String source, {required bool saveAs}) async {
    return await saveDocumentWithIdentity(source, saveAs: saveAs) != null;
  }

  @override
  Future<WorkbenchDocumentFile?> saveDocumentWithIdentity(
    String source, {
    required bool saveAs,
    String? currentPath,
    String? currentName,
  }) async {
    // Save writes directly to the document identity already associated with
    // the session. Only Save As (or Save on an untitled document) opens a
    // destination picker.
    final path = !saveAs && currentPath != null && currentPath.isNotEmpty
        ? currentPath
        : await FilePicker.platform.saveFile(
            type: FileType.custom,
            allowedExtensions: _extensions,
            fileName: saveAs ? defaultFileName : currentName ?? defaultFileName,
            lockParentWindow: true,
          );
    if (path == null) return null;

    await File(
      path,
    ).writeAsBytes(Uint8List.fromList(utf8.encode(source)), flush: true);
    return WorkbenchDocumentFile(
      source: source,
      path: path,
      name: _fileName(path) ?? currentName ?? defaultFileName,
    );
  }

  String? _fileName(String path) {
    final separator = path.lastIndexOf(RegExp(r'[/\\]'));
    if (separator < 0 || separator == path.length - 1) return null;
    return path.substring(separator + 1);
  }
}
