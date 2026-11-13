import 'dart:io';

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

      final initial = (await bridge.getActiveDocument())!;
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

      final review = await bridge.reviewDocumentEdit(proposal);
      expect(review.status, DocumentEditStatus.review);
      expect(session.source, 'scene: old\n');

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

  test(
    'valid no-op edit does not create history or advance revision',
    () async {
      final session = WorkbenchDocumentSession(
        initialSource: 'scene: same\n',
        documentId: 'doc-noop',
      );
      final editor = WorkbenchEditorController.fromText(session.source);
      editor.addListener(() => session.updateSource(editor.text));
      final bridge = WorkbenchAgentBridge(session: session, editor: editor);
      final snapshot = await bridge.getActiveDocument();
      final proposal = DocumentEditProposal(
        baseDocumentId: snapshot!.documentId,
        baseRevision: snapshot.revision,
        summary: 'Keep the current scene',
        edits: const <DocumentEdit>[
          DocumentEdit(
            range: SourceRange(start: 7, end: 11),
            replacement: 'same',
          ),
        ],
      );

      final result = await bridge.applyDocumentEdit(proposal);

      expect(result.status, DocumentEditStatus.noOp);
      expect(result.newRevision, isNull);
      expect(session.revision, 0);
      expect(editor.editingController.canUndo, isFalse);
      expect(session.source, 'scene: same\n');
      editor.dispose();
      session.dispose();
    },
  );

  test(
    'agent apply is in-memory only and never saves the active path',
    () async {
      final directory = await Directory.systemTemp.createTemp('relgeo-mcp-');
      final file = File('${directory.path}/active.relgeo');
      const initialSource = 'scene: old\n';
      await file.writeAsString(initialSource);
      final session = WorkbenchDocumentSession(
        initialSource: initialSource,
        documentId: 'doc-no-save',
      );
      session.markLoaded(
        source: initialSource,
        path: file.path,
        name: 'active.relgeo',
        documentId: 'doc-no-save',
      );
      final editor = WorkbenchEditorController.fromText(session.source);
      editor.addListener(() => session.updateSource(editor.text));
      final bridge = WorkbenchAgentBridge(session: session, editor: editor);
      final snapshot = (await bridge.getActiveDocument())!;

      final result = await bridge.applyDocumentEdit(
        DocumentEditProposal(
          baseDocumentId: snapshot.documentId,
          baseRevision: snapshot.revision,
          summary: 'Change without saving',
          edits: const <DocumentEdit>[
            DocumentEdit(
              range: SourceRange(start: 7, end: 10),
              replacement: 'new',
            ),
          ],
        ),
      );

      expect(result.status, DocumentEditStatus.applied);
      expect(session.path, file.path);
      expect(session.isDirty, isTrue);
      expect(await file.readAsString(), initialSource);

      editor.dispose();
      session.dispose();
      await directory.delete(recursive: true);
    },
  );

  test(
    'editor transaction failure does not report a partial mutation',
    () async {
      final session = WorkbenchDocumentSession(
        initialSource: 'scene: old\n',
        documentId: 'doc-failure',
      );
      final editor = WorkbenchEditorController.fromText(session.source);
      editor.addListener(() => session.updateSource(editor.text));
      final bridge = WorkbenchAgentBridge(session: session, editor: editor);
      final snapshot = (await bridge.getActiveDocument())!;
      final proposal = DocumentEditProposal(
        baseDocumentId: snapshot.documentId,
        baseRevision: snapshot.revision,
        summary: 'Fail before commit',
        edits: const <DocumentEdit>[
          DocumentEdit(
            range: SourceRange(start: 7, end: 10),
            replacement: 'new',
          ),
        ],
      );

      editor.dispose();
      final result = await bridge.applyDocumentEdit(proposal);

      expect(result.status, DocumentEditStatus.failed);
      expect(session.source, 'scene: old\n');
      expect(session.revision, 0);
      expect(session.isDirty, isFalse);
      session.dispose();
    },
  );

  test(
    'close removes the active MCP target and reload invalidates a proposal',
    () async {
      final session = WorkbenchDocumentSession(
        initialSource: 'scene: old\n',
        documentId: 'doc-lifecycle',
      );
      final editor = WorkbenchEditorController.fromText(session.source);
      editor.addListener(() => session.updateSource(editor.text));
      final bridge = WorkbenchAgentBridge(session: session, editor: editor);
      final beforeReload = (await bridge.getActiveDocument())!;
      final proposal = DocumentEditProposal(
        baseDocumentId: beforeReload.documentId,
        baseRevision: beforeReload.revision,
        summary: 'Edit before reload',
        edits: const <DocumentEdit>[
          DocumentEdit(
            range: SourceRange(start: 7, end: 10),
            replacement: 'new',
          ),
        ],
      );

      session.reload(source: 'scene: reloaded\n');
      expect(session.revision, 1);
      expect(
        (await bridge.applyDocumentEdit(proposal)).status,
        DocumentEditStatus.stale,
      );

      session.close();
      expect(session.isOpen, isFalse);
      expect(await bridge.getActiveDocument(), isNull);
      expect(
        (await bridge.applyDocumentEdit(proposal)).status,
        DocumentEditStatus.failed,
      );

      session.markLoaded(
        source: 'scene: reopened\n',
        documentId: 'doc-lifecycle',
      );
      expect(session.isOpen, isTrue);
      expect(session.revision, 0);
      editor.replaceDocument(session.source);
      editor.dispose();
      session.dispose();
    },
  );
}
