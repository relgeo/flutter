import 'dart:convert';
import 'dart:io';
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

/// A picker result that does not expose the platform plugin's concrete types.
///
/// Desktop pickers may return a path without eagerly loading bytes, while web
/// pickers commonly return bytes without a filesystem path. The workbench
/// accepts either representation and normalizes it at this boundary.
class WorkbenchPickedFile {
  const WorkbenchPickedFile({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final Uint8List? bytes;
}

/// Host adapter for native/document picker operations.
abstract interface class WorkbenchFilePicker {
  Future<WorkbenchPickedFile?> pickDocument({
    required List<String> allowedExtensions,
  });

  Future<String?> saveDocument({
    required String fileName,
    required List<String> allowedExtensions,
  });
}

/// Stable error vocabulary for the document/file boundary.
class WorkbenchDocumentFileException implements Exception {
  const WorkbenchDocumentFileException({
    required this.code,
    required this.message,
    this.path,
    this.cause,
  });

  final String code;
  final String message;
  final String? path;
  final Object? cause;

  @override
  String toString() => '$code: $message';
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
  const FilePickerWorkbenchFileService({
    this.defaultFileName = 'relgeo.yaml',
    WorkbenchFilePicker? picker,
  }) : _picker = picker ?? const _PlatformWorkbenchFilePicker();

  final String defaultFileName;
  final WorkbenchFilePicker _picker;

  @override
  Future<String?> openDocument() async {
    final document = await openDocumentWithIdentity();
    return document?.source;
  }

  @override
  Future<WorkbenchDocumentFile?> openDocumentWithIdentity() async {
    final WorkbenchPickedFile? file;
    try {
      file = await _picker.pickDocument(allowedExtensions: supportedExtensions);
    } catch (error) {
      throw WorkbenchDocumentFileException(
        code: 'document.picker',
        message: 'The document picker could not be opened.',
        cause: error,
      );
    }
    if (file == null) return null;
    _validateSupportedName(file.name, path: file.path);
    final source = await _readPickedSource(file);
    return WorkbenchDocumentFile(
      source: source,
      path: file.path,
      name: file.name,
    );
  }

  @override
  Future<WorkbenchDocumentFile?> openDocumentAtPath(String path) async {
    if (!_isSupportedPath(path)) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return WorkbenchDocumentFile(
        source: _decode(await file.readAsBytes(), path: path),
        path: path,
        name: _fileName(path) ?? path,
      );
    } on WorkbenchDocumentFileException {
      rethrow;
    } catch (error) {
      throw WorkbenchDocumentFileException(
        code: 'document.read',
        message: 'The selected document could not be read.',
        path: path,
        cause: error,
      );
    }
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
    final String? pickedPath;
    if (!saveAs && currentPath != null && currentPath.isNotEmpty) {
      pickedPath = currentPath;
    } else {
      try {
        pickedPath = await _picker.saveDocument(
          fileName: saveAs ? defaultFileName : currentName ?? defaultFileName,
          allowedExtensions: supportedExtensions,
        );
      } catch (error) {
        throw WorkbenchDocumentFileException(
          code: 'document.picker',
          message: 'The document picker could not be opened.',
          cause: error,
        );
      }
    }
    if (pickedPath == null) return null;
    final path = _normalizeSavePath(pickedPath);

    try {
      await File(
        path,
      ).writeAsBytes(Uint8List.fromList(utf8.encode(source)), flush: true);
    } catch (error) {
      throw WorkbenchDocumentFileException(
        code: 'document.write',
        message: 'The document could not be saved.',
        path: path,
        cause: error,
      );
    }
    return WorkbenchDocumentFile(
      source: source,
      path: path,
      name: _fileName(path) ?? currentName ?? defaultFileName,
    );
  }

  static const supportedExtensions = <String>['yaml', 'yml', 'relgeo'];

  String? _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final separator = normalized.lastIndexOf('/');
    if (separator == normalized.length - 1) return null;
    return separator < 0 ? normalized : normalized.substring(separator + 1);
  }

  bool _isSupportedPath(String path) {
    final name = (_fileName(path) ?? path).toLowerCase();
    return supportedExtensions.any((extension) => name.endsWith('.$extension'));
  }

  void _validateSupportedName(String name, {String? path}) {
    final candidate = name.isNotEmpty ? name : path ?? '';
    if (_isSupportedPath(candidate)) return;
    throw WorkbenchDocumentFileException(
      code: 'document.unsupported_format',
      message: 'Only .yaml, .yml, and .relgeo documents are supported.',
      path: path,
    );
  }

  String _normalizeSavePath(String path) {
    final name = _fileName(path);
    if (name == null || name.isEmpty) {
      throw WorkbenchDocumentFileException(
        code: 'document.unsupported_format',
        message: 'The destination must have a supported document filename.',
        path: path,
      );
    }
    if (_isSupportedPath(path)) return path;
    if (name.contains('.')) {
      throw WorkbenchDocumentFileException(
        code: 'document.unsupported_format',
        message: 'Only .yaml, .yml, and .relgeo documents are supported.',
        path: path,
      );
    }
    return '$path.relgeo';
  }

  Future<String> _readPickedSource(WorkbenchPickedFile file) async {
    if (file.bytes != null) return _decode(file.bytes!, path: file.path);
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const WorkbenchDocumentFileException(
        code: 'document.read',
        message: 'The selected document has no readable content.',
      );
    }
    try {
      return _decode(await File(path).readAsBytes(), path: path);
    } on WorkbenchDocumentFileException {
      rethrow;
    } catch (error) {
      throw WorkbenchDocumentFileException(
        code: 'document.read',
        message: 'The selected document could not be read.',
        path: path,
        cause: error,
      );
    }
  }

  String _decode(List<int> bytes, {String? path}) {
    try {
      final decoded = utf8.decode(bytes);
      return decoded.startsWith('\uFEFF') ? decoded.substring(1) : decoded;
    } catch (error) {
      throw WorkbenchDocumentFileException(
        code: 'document.decode',
        message: 'The selected document is not valid UTF-8.',
        path: path,
        cause: error,
      );
    }
  }
}

class _PlatformWorkbenchFilePicker implements WorkbenchFilePicker {
  const _PlatformWorkbenchFilePicker();

  @override
  Future<WorkbenchPickedFile?> pickDocument({
    required List<String> allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    return WorkbenchPickedFile(
      name: file.name,
      path: file.path,
      bytes: file.bytes,
    );
  }

  @override
  Future<String?> saveDocument({
    required String fileName,
    required List<String> allowedExtensions,
  }) {
    return FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      fileName: fileName,
      lockParentWindow: true,
    );
  }
}
