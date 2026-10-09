import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/mcp/workbench_agent_bridge.dart';
import 'package:relgeo_flutter/src/ui/workbench_document_session.dart';
import 'package:relgeo_flutter/src/ui/workbench_editor_controller.dart';
import 'package:relgeo_mcp/relgeo_mcp.dart';

void main() {
  test(
    'agent edit is one undoable transaction with a revision guard',
    () async {
      final session = WorkbenchDocumentSession(
        initialSource: 'scene: old\n',
        documentId: 'doc-1',
      );
      final editor = WorkbenchEditorController.fromText(session.source);
      editor.addListener(() => session.updateSource(editor.text));
      final bridge = WorkbenchAgentBridge(session: session, editor: editor);

      final initial = await bridge.getActiveDocument();
      final proposal = DocumentEditProposal(
        baseDocumentId: initial.documentId,
        baseRevision: initial.revision,
        summary: 'Change scene name',
        edits: const <DocumentEdit>[
          DocumentEdit(
            range: SourceRange(start: 7, end: 10),
            replacement: 'new',
          ),
        ],
      );

      final applied = await bridge.applyDocumentEdit(proposal);
      expect(applied.status, DocumentEditStatus.applied);
      expect(applied.newRevision, 1);
      expect(session.source, 'scene: new\n');
      expect(session.isDirty, isTrue);
      expect(editor.editingController.canUndo, isTrue);

      editor.editingController.undo();
      expect(editor.text, 'scene: old\n');

      final stale = await bridge.applyDocumentEdit(proposal);
      expect(stale.status, DocumentEditStatus.stale);

      editor.dispose();
      session.dispose();
    },
  );

  test('document replacement resets identity and revision', () {
    final session = WorkbenchDocumentSession(
      initialSource: 'one',
      documentId: 'old-doc',
    );
    session.updateSource('two');
    expect(session.revision, 1);

    session.markLoaded(
      source: 'three',
      path: '/documents/three.relgeo',
      name: 'three.relgeo',
    );
    expect(session.documentId, '/documents/three.relgeo');
    expect(session.revision, 0);
    expect(session.isDirty, isFalse);

    session.dispose();
  });
}
