import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_import_diagnostics.dart';
import 'package:relgeo_mcp/relgeo_mcp.dart';

void main() {
  test('active import errors use stable bounded diagnostic codes', () {
    final diagnostics = WorkbenchImportDiagnostics.fromErrors(
      yamlError: 'mapping values are not allowed here',
      compilerError: null,
    );

    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.code, 'relgeo.yaml.parse');
    expect(diagnostics.single.message, 'mapping values are not allowed here');
    expect(diagnostics.single.severity, DiagnosticSeverity.error);
  });

  test('compile error is kept distinct from YAML parse error', () {
    final diagnostics = WorkbenchImportDiagnostics.fromErrors(
      yamlError: 'invalid YAML',
      compilerError: 'Unknown object type: nope',
    );

    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      <String>['relgeo.yaml.parse', 'relgeo.compile'],
    );
    expect(diagnostics.every((diagnostic) =>
        diagnostic.severity == DiagnosticSeverity.error), isTrue);
  });

  test('no active import error produces an empty diagnostic list', () {
    expect(WorkbenchImportDiagnostics.fromErrors(), isEmpty);
  });
}
