import 'package:relgeo_mcp/relgeo_mcp.dart';

/// Stable diagnostic projection for the active YAML/RelGeo import boundary.
///
/// The workbench intentionally exposes only the bounded MCP diagnostic shape
/// here. Source paths and compiler phases belong to the broader core
/// diagnostic promotion contract and are not inferred from exception text.
class WorkbenchImportDiagnostics {
  const WorkbenchImportDiagnostics._();

  static List<DocumentDiagnostic> fromErrors({
    String? yamlError,
    String? compilerError,
  }) {
    final diagnostics = <DocumentDiagnostic>[];
    if (yamlError case final message?) {
      diagnostics.add(
        DocumentDiagnostic(
          code: 'relgeo.yaml.parse',
          message: message,
          severity: DiagnosticSeverity.error,
        ),
      );
    }
    if (compilerError case final message?) {
      diagnostics.add(
        DocumentDiagnostic(
          code: 'relgeo.compile',
          message: message,
          severity: DiagnosticSeverity.error,
        ),
      );
    }
    return diagnostics;
  }
}
