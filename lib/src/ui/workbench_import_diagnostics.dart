import 'package:relgeo_mcp/relgeo_mcp.dart';

import 'workbench_file_service.dart';

/// Stable diagnostic projection for the active YAML/RelGeo import boundary.
///
/// The workbench exposes a bounded MCP diagnostic shape here. Known compiler
/// codes may carry their declared phase/path while unknown exception details
/// remain redacted or fall back to the document boundary.
class WorkbenchImportDiagnostics {
  const WorkbenchImportDiagnostics._();

  static List<DocumentDiagnostic> fromErrors({
    String? yamlError,
    Object? yamlException,
    String? compilerError,
    Object? compilerException,
    Object? fileError,
    String? sourceRevision,
  }) {
    final diagnostics = <DocumentDiagnostic>[];
    if (yamlException case final error?) {
      diagnostics.add(fromYamlError(error, sourceRevision: sourceRevision));
    } else if (yamlError case final message?) {
      diagnostics.add(fromYamlError(message, sourceRevision: sourceRevision));
    }
    if (compilerException case final error?) {
      diagnostics.add(
        fromCompilerError(error, sourceRevision: sourceRevision),
      );
    } else if (compilerError case final message?) {
      diagnostics.add(
        fromCompilerError(message, sourceRevision: sourceRevision),
      );
    }
    if (fileError case final error?) {
      diagnostics.addAll(
        fromFileError(error, sourceRevision: sourceRevision),
      );
    }
    return diagnostics;
  }

  static DocumentDiagnostic fromYamlError(
    Object error, {
    String? path,
    String? sourceRevision,
  }) {
    return DocumentDiagnostic(
      code: 'INVALID_YAML',
      message: _message(error),
      severity: DiagnosticSeverity.error,
      phase: 'parse',
      path: path ?? 'document',
      origin: 'activeDocument',
      sourceRevision: sourceRevision,
    );
  }

  static DocumentDiagnostic fromCompilerError(
    Object error, {
    String? path,
    String? sourceRevision,
  }) {
    final message = _message(error);
    final code = _codeFor(message);
    return DocumentDiagnostic(
      code: code,
      message: _detailFor(message),
      severity: DiagnosticSeverity.error,
      phase: _phaseFor(code),
      path: path ?? _pathFor(message) ?? 'document',
      origin: 'activeDocument',
      sourceRevision: sourceRevision,
    );
  }

  /// Projects file-boundary failures into the same stable diagnostic shape as
  /// parser/compiler failures. Host UI may show a friendlier message, while
  /// MCP consumers still receive a bounded, machine-readable code.
  static List<DocumentDiagnostic> fromFileError(
    Object error, {
    String? sourceRevision,
  }) {
    if (error case final WorkbenchDocumentFileException fileError) {
      return <DocumentDiagnostic>[
        DocumentDiagnostic(
          code: fileError.code.toUpperCase().replaceAll('.', '_'),
          message: fileError.message,
          severity: DiagnosticSeverity.error,
          phase: 'io',
          path: fileError.path ?? 'document',
          origin: 'activeDocument',
          sourceRevision: sourceRevision,
        ),
      ];
    }
    return <DocumentDiagnostic>[
      DocumentDiagnostic(
        code: 'DOCUMENT_IO',
        message: 'The document file operation failed.',
        severity: DiagnosticSeverity.error,
        phase: 'io',
        path: 'document',
        origin: 'activeDocument',
        sourceRevision: sourceRevision,
      ),
    ];
  }

  static String _message(Object error) {
    if (error is String) return error;
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }

  static String _codeFor(String message) {
    final prefix = RegExp(r'^([A-Z][A-Z0-9_]+):').firstMatch(message)?.group(1);
    if (prefix != null && _knownCodes.contains(prefix)) return prefix;
    if (message.contains('Unknown identifier')) return 'UNKNOWN_IDENTIFIER';
    if (message.contains('Unknown object type')) return 'INVALID_OBJECT_TYPE';
    if (message.contains('Division by zero')) return 'DIVISION_BY_ZERO';
    if (message.contains('Invalid expression') ||
        message.contains('Unexpected token')) {
      return 'INVALID_EXPRESSION';
    }
    if (message.contains('constraint') || message.contains('Constraint')) {
      return 'CONSTRAINT_VIOLATION';
    }
    return 'UNKNOWN_ERROR';
  }

  static String _detailFor(String message) {
    final prefix = RegExp(r'^([A-Z][A-Z0-9_]+):\s*').firstMatch(message);
    return prefix == null ? message : message.substring(prefix.end);
  }

  static String _phaseFor(String code) {
    if (code == 'CONSTRAINT_VIOLATION') return 'constraint';
    if (code.contains('BOOLEAN') ||
        code == 'DIVISION_BY_ZERO' ||
        code == 'INVALID_COLLECTION_ACCESS') {
      return 'runtime';
    }
    return 'resolve';
  }

  static String? _pathFor(String message) {
    final path = RegExp(
      r'(?:path|at)\s*[=:]?\s*([A-Za-z_$][A-Za-z0-9_$]*(?:\.[A-Za-z0-9_$]+|\[[^\]]+\])*)',
      caseSensitive: false,
    ).firstMatch(message)?.group(1);
    return path;
  }

  static const _knownCodes = <String>{
    'BOOLEAN_EMPTY_RESULT',
    'BOOLEAN_MULTIPART_RESULT',
    'CONSTRAINT_VIOLATION',
    'DIVISION_BY_ZERO',
    'INVALID_COLLECTION_ACCESS',
    'INVALID_EXPRESSION',
    'INVALID_OBJECT_TYPE',
    'INVALID_VALUE',
    'MISSING_REQUIRED_FIELD',
    'TYPE_MISMATCH',
    'UNKNOWN_IDENTIFIER',
    'UNKNOWN_REFERENCE',
  };
}
