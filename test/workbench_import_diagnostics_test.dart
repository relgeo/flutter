import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_file_service.dart';
import 'package:relgeo_flutter/src/ui/workbench_import_diagnostics.dart';

void main() {
  test('structured consumer diagnostics preserve canonical fields', () {
    final diagnostic = WorkbenchImportDiagnostics.fromCompilerError(
      const _StructuredDiagnostic(
        code: 'UNKNOWN_ANCHOR',
        message: 'Unknown anchor: edge',
        phase: 'validate',
        path: 'objects.panel.place.anchor',
        origin: 'validator',
      ),
      sourceRevision: 'session-structured',
    );

    expect(diagnostic.code, 'UNKNOWN_ANCHOR');
    expect(diagnostic.message, 'Unknown anchor: edge');
    expect(diagnostic.phase, 'validate');
    expect(diagnostic.path, 'objects.panel.place.anchor');
    expect(diagnostic.origin, 'validator');
    expect(diagnostic.sourceRevision, 'session-structured');
  });

  test('map-shaped consumer diagnostics normalize code names', () {
    final diagnostic = WorkbenchImportDiagnostics.fromCompilerError({
      'code': 'invalid unit value',
      'message': 'Expected a finite length',
      'phase': 'validate',
      'path': 'parameters.scale.default',
      'origin': 'validator',
    });

    expect(diagnostic.code, 'INVALID_UNIT_VALUE');
    expect(diagnostic.phase, 'validate');
    expect(diagnostic.path, 'parameters.scale.default');
    expect(diagnostic.origin, 'validator');
  });

  test('file errors use the stable document diagnostic vocabulary', () {
    const error = WorkbenchDocumentFileException(
      code: 'document.decode',
      message: 'The selected document is not valid UTF-8.',
    );

    final diagnostics = WorkbenchImportDiagnostics.fromFileError(error);

    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.code, 'DOCUMENT_DECODE');
    expect(diagnostics.single.phase, 'io');
    expect(diagnostics.single.path, 'document');
    expect(diagnostics.single.origin, 'activeDocument');
    expect(diagnostics.single.message, error.message);
  });

  test('unknown file errors do not expose host exception details', () {
    final diagnostics = WorkbenchImportDiagnostics.fromFileError(
      StateError('host-specific detail'),
    );

    expect(diagnostics.single.code, 'DOCUMENT_IO');
    expect(diagnostics.single.message, 'The document file operation failed.');
    expect(diagnostics.single.message, isNot(contains('host-specific')));
  });

  test('compiler errors align to core code, phase, and path fields', () {
    final diagnostics = WorkbenchImportDiagnostics.fromCompilerError(
      'UNKNOWN_IDENTIFIER: missing.center',
      path: 'objects.broken.center',
    );

    expect(diagnostics.code, 'UNKNOWN_IDENTIFIER');
    expect(diagnostics.message, 'missing.center');
    expect(diagnostics.phase, 'resolve');
    expect(diagnostics.path, 'objects.broken.center');
    expect(diagnostics.origin, 'activeDocument');
  });

  test('YAML errors align to parse phase and document path', () {
    final diagnostic = WorkbenchImportDiagnostics.fromYamlError(
      'YAML Parse Error',
    );

    expect(diagnostic.code, 'INVALID_YAML');
    expect(diagnostic.phase, 'parse');
    expect(diagnostic.path, 'document');
  });
}

class _StructuredDiagnostic {
  const _StructuredDiagnostic({
    required this.code,
    required this.message,
    required this.phase,
    required this.path,
    required this.origin,
  });

  final String code;
  final String message;
  final String phase;
  final String path;
  final String origin;
}
