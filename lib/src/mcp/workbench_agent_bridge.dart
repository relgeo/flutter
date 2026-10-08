import 'package:relgeo_mcp/relgeo_mcp.dart';

import '../ui/workbench_document_session.dart';
import '../ui/workbench_editor_controller.dart';

typedef WorkbenchDiagnosticsProvider = List<DocumentDiagnostic> Function();

/// Flutter's host-side implementation of the pure-Dart agent bridge.
///
/// This class knows the session and editor controllers, but no MCP transport,
/// JSON-RPC, widget, or filesystem API. A protocol adapter can depend on the
/// [RelGeoAgentBridge] interface instead.
class WorkbenchAgentBridge implements RelGeoAgentBridge {
  WorkbenchAgentBridge({
    required this.session,
    required this.editor,
    this.diagnostics = _emptyDiagnostics,
  });

  final WorkbenchDocumentSession session;
  final WorkbenchEditorController editor;
  final WorkbenchDiagnosticsProvider diagnostics;

  static List<DocumentDiagnostic> _emptyDiagnostics() =>
      const <DocumentDiagnostic>[];

  @override
  Future<ActiveDocumentSnapshot> getActiveDocument() async =>
      session.snapshot(diagnostics: diagnostics());

  @override
  Future<List<DocumentDiagnostic>> getDiagnostics() async => diagnostics();

  @override
  Future<DocumentEditResult> applyDocumentEdit(
    DocumentEditProposal proposal,
  ) async {
    final snapshot = session.snapshot(diagnostics: diagnostics());
    final validation = proposal.validateAgainst(snapshot);
    final hasStaleGuardFailure = validation.any(
      (error) =>
          error == 'baseDocumentId does not identify the active document' ||
          error == 'baseRevision is stale',
    );
    if (hasStaleGuardFailure) {
      return DocumentEditResult.stale(
        message: validation.join('; '),
      );
    }
    if (validation.isNotEmpty) {
      return DocumentEditResult.rejected(
        message: validation.join('; '),
      );
    }

    final nextSource = proposal.applyTo(snapshot);

    // The setter is called exactly once. With the workbench listener attached,
    // that produces one native editor history entry and updates the session;
    // the fallback keeps this host correct in headless tests as well.
    editor.applyAgentSource(nextSource);
    if (session.revision == snapshot.revision) {
      session.applySourceIfCurrent(
        documentId: snapshot.documentId,
        baseRevision: snapshot.revision,
        source: nextSource,
      );
    }
    if (session.documentId != snapshot.documentId ||
        session.revision != snapshot.revision + 1 ||
        session.source != nextSource) {
      return const DocumentEditResult.failed(
        message: 'editor and active session diverged during apply',
      );
    }

    return DocumentEditResult.applied(
      newRevision: session.revision,
      snapshot: session.snapshot(diagnostics: diagnostics()),
    );
  }
}
