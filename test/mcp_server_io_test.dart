// ignore_for_file: unnecessary_overrides

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_mcp/relgeo_mcp.dart';
import 'package:relgeo_flutter/src/mcp/mcp_server.dart';
import 'package:relgeo_flutter/src/mcp/workbench_agent_bridge.dart';
import 'package:relgeo_flutter/src/ui/workbench_document_session.dart';
import 'package:relgeo_flutter/src/ui/workbench_editor_controller.dart';

class _RealHttpOverrides extends HttpOverrides {
  // The base implementation constructs a native HttpClient; retaining this
  // override bypasses TestWidgetsFlutterBinding's fake 400-response client.
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'HTTP MCP exposes bundled spec and gates undoable document edits',
    () async {
      const initialSource = 'objects: {}\n';
      final session = WorkbenchDocumentSession(
        initialSource: initialSource,
        documentId: 'mcp-test-document',
      );
      final editor = WorkbenchEditorController.fromText(initialSource);
      editor.addListener(() => session.updateSource(editor.text));
      final bridge = WorkbenchAgentBridge(session: session, editor: editor);
      final client = HttpOverrides.runZoned(
        HttpClient.new,
        createHttpClient: (context) =>
            _RealHttpOverrides().createHttpClient(context),
      );
      RelGeoMcpDesktopServer? readOnlyServer;
      RelGeoMcpDesktopServer? readWriteServer;

      Future<Map<String, Object?>> post(
        RelGeoMcpDesktopServer server,
        Map<String, Object?> message,
      ) async {
        final request = await client.postUrl(Uri.parse(server.endpoint));
        request.headers
          ..contentType = ContentType.json
          ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream')
          ..set(HttpHeaders.authorizationHeader, 'Bearer ${server.token}');
        request.write(jsonEncode(message));
        final response = await request.close();
        final body = await utf8.decoder.bind(response).join();
        if (response.statusCode != HttpStatus.ok) {
          return <String, Object?>{
            'httpStatus': response.statusCode,
            'body': body,
          };
        }
        return Map<String, Object?>.from(
          (jsonDecode(body) as Map).cast<String, Object?>(),
        );
      }

      Future<void> initialize(RelGeoMcpDesktopServer server) async {
        await post(server, <String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': <String, Object?>{
            'protocolVersion': RelGeoMcpJsonRpcRouter.protocolVersion,
          },
        });
        final notification = await client.postUrl(Uri.parse(server.endpoint));
        notification.headers
          ..contentType = ContentType.json
          ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream')
          ..set(HttpHeaders.authorizationHeader, 'Bearer ${server.token}');
        notification.write(
          jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'method': 'notifications/initialized',
          }),
        );
        final response = await notification.close();
        expect(response.statusCode, HttpStatus.accepted);
        await response.drain<void>();
      }

      try {
        readOnlyServer = await RelGeoMcpDesktopServer.start(bridge: bridge);
        await initialize(readOnlyServer);
        final readOnlyTools = await post(readOnlyServer, <String, Object?>{
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/list',
        });
        final listedReadOnly =
            (((readOnlyTools['result'] as Map)['tools']) as List)
                .cast<Map<String, Object?>>();
        expect(
          listedReadOnly.map((tool) => tool['name']),
          containsAll(<String>[
            'relgeo_search_spec',
            'relgeo_get_spec_section',
            'relgeo_get_active_document',
          ]),
        );
        expect(
          listedReadOnly.map((tool) => tool['name']),
          isNot(contains('relgeo_apply_document_edit')),
        );

        final denied = await post(readOnlyServer, <String, Object?>{
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'tools/call',
          'params': <String, Object?>{
            'name': 'relgeo_apply_document_edit',
            'arguments': <String, Object?>{},
          },
        });
        expect(denied['httpStatus'], HttpStatus.forbidden);
        expect(session.source, initialSource);

        readWriteServer = await RelGeoMcpDesktopServer.start(
          bridge: bridge,
          permission: McpPermission.readWrite,
        );
        await initialize(readWriteServer);
        final readWriteTools = await post(readWriteServer, <String, Object?>{
          'jsonrpc': '2.0',
          'id': 4,
          'method': 'tools/list',
        });
        final listedReadWrite =
            (((readWriteTools['result'] as Map)['tools']) as List)
                .cast<Map<String, Object?>>();
        expect(
          listedReadWrite.map((tool) => tool['name']),
          contains('relgeo_apply_document_edit'),
        );

        final stale = await post(readWriteServer, <String, Object?>{
          'jsonrpc': '2.0',
          'id': 5,
          'method': 'tools/call',
          'params': <String, Object?>{
            'name': 'relgeo_apply_document_edit',
            'arguments': <String, Object?>{
              'baseDocumentId': session.documentId,
              'baseRevision': session.revision + 1,
              'summary': 'Stale change',
              'edits': <Object?>[
                <String, Object?>{
                  'range': <String, Object?>{'start': 0, 'end': 0},
                  'replacement': '# stale\n',
                },
              ],
            },
          },
        });
        expect(
          ((stale['result'] as Map)['structuredContent'] as Map)['status'],
          'stale',
        );
        expect(session.source, initialSource);

        final applied = await post(readWriteServer, <String, Object?>{
          'jsonrpc': '2.0',
          'id': 6,
          'method': 'tools/call',
          'params': <String, Object?>{
            'name': 'relgeo_apply_document_edit',
            'arguments': <String, Object?>{
              'baseDocumentId': session.documentId,
              'baseRevision': session.revision,
              'summary': 'Create a square',
              'edits': <Object?>[
                <String, Object?>{
                  'range': <String, Object?>{
                    'start': 0,
                    'end': initialSource.length,
                  },
                  'replacement':
                      'objects:\n  square:\n    type: rect\n    size: [40, 40]\n    place:\n      topLeft: [0, 0]\n',
                },
              ],
            },
          },
        });
        final editResult =
            (applied['result'] as Map)['structuredContent'] as Map;
        expect(editResult['status'], 'applied');
        expect(session.source, contains('square:'));
        expect(session.isDirty, isTrue);
        expect(editor.editingController.canUndo, isTrue);
      } finally {
        await readOnlyServer?.stop();
        await readWriteServer?.stop();
        client.close(force: true);
        editor.dispose();
        session.dispose();
      }
    },
  );
}
