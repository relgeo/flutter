import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_file_service.dart';
import 'package:relgeo_flutter/src/ui/workbench_import_diagnostics.dart';

void main() {
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
