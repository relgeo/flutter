import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_file_service.dart';
import 'package:relgeo_flutter/src/ui/workbench_import_diagnostics.dart';

import 'support/shared_fixture.dart';

void main() {
  if (!hasSharedFixtures()) {
    test(
      'shared diagnostic contract requires workspace fixture staging',
      () {},
      skip: 'Set RELGEO_FIXTURE_ROOT to run canonical workspace fixtures.',
    );
    return;
  }

  final contract = jsonDecode(
    sharedFixtureFile('', 'diagnostics/flutter-import-contract.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;

  test('canonical diagnostic contract is current and traceable', () {
    expect(contract['schema'], 'relgeo.flutter-import-diagnostics');
    expect(contract['schemaVersion'], 1);
    expect(contract['compatibilityLine'], '0.5');
    expect(contract['contractRevision'], 'mcp-contract-2026-11-12-r2');
    expect((contract['provenance'] as Map)['source'], 'spec');
    expect((contract['provenance'] as Map)['revision'], isNotEmpty);
    expect(contract['cases'], hasLength(4));
  });

  test('Flutter diagnostics preserve canonical code, phase, path, and origin', () {
    final cases = (contract['cases'] as List).cast<Map<String, dynamic>>();
    for (final item in cases) {
      final fixture = item['fixture'] as String?;
      if (fixture != null) {
        expect(
          sharedFixtureFile('', fixture).existsSync(),
          isTrue,
          reason: 'missing canonical fixture for ${item['id']}',
        );
      }

      final expected = (item['expected'] as Map).cast<String, dynamic>();
      final sourceRevision = 'session-7';
      final diagnostic = switch (item['id']) {
        'invalid-yaml' => WorkbenchImportDiagnostics.fromYamlError(
            'YAML Parse Error',
            sourceRevision: sourceRevision,
          ),
        'unknown-reference' => WorkbenchImportDiagnostics.fromCompilerError(
            'UNKNOWN_IDENTIFIER: missing.x',
            path: expected['path'] as String,
            sourceRevision: sourceRevision,
          ),
        'runtime-empty-boolean' =>
          WorkbenchImportDiagnostics.fromCompilerError(
            'BOOLEAN_EMPTY_RESULT: no intersection',
            path: expected['path'] as String,
            sourceRevision: sourceRevision,
          ),
        'document-decode' => WorkbenchImportDiagnostics.fromFileError(
            const WorkbenchDocumentFileException(
              code: 'document.decode',
              message: 'The selected document is not valid UTF-8.',
            ),
            sourceRevision: sourceRevision,
          ).single,
        _ => fail('unexpected diagnostic contract case ${item['id']}'),
      };

      expect(diagnostic.code, expected['code']);
      expect(diagnostic.phase, expected['phase']);
      expect(diagnostic.path, expected['path']);
      expect(diagnostic.origin, expected['origin']);
      expect(diagnostic.sourceRevision, sourceRevision);
    }
  });
}
