import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relgeo_mcp/relgeo_mcp.dart';

import 'spec_snapshot_loader.dart';
import 'workbench_agent_bridge.dart';

/// Streamable HTTP endpoint owned by one running desktop workbench session.
///
/// It binds only to IPv4 loopback, requires the in-memory bearer token, and
/// exposes only resources backed by the active workbench bridge.
class RelGeoMcpDesktopServer {
  RelGeoMcpDesktopServer._({
    required HttpServer server,
    required McpServerSession session,
    required this.token,
    required RelGeoMcpJsonRpcRouter router,
  }) : _server = server,
       _session = session,
       _router = router;

  static const _maxRequestBytes = 1024 * 1024;
  static const _protocolVersion = RelGeoMcpJsonRpcRouter.protocolVersion;

  final HttpServer _server;
  final McpServerSession _session;
  final RelGeoMcpJsonRpcRouter _router;
  bool _stopped = false;

  final String token;

  String get endpoint => 'http://127.0.0.1:${_server.port}/mcp';

  static Future<RelGeoMcpDesktopServer> start({
    required WorkbenchAgentBridge bridge,
    RelGeoSpecSnapshotLoader? specLoader,
  }) async {
    final session = McpServerSession(
      policy: const McpSecurityPolicy(enabled: true),
    )..start();
    try {
      final token = session
          .issueToken(
            permission: McpPermission.readOnly,
            ttl: const Duration(hours: 8),
          )
          .value;
      final bundledSpec = await (specLoader ?? const RelGeoSpecSnapshotLoader())
          .load();
      final specIndex = bundledSpec.createIndex();
      final resources = RelGeoMcpResourceStore(
        activeBridge: bridge,
        specIndex: specIndex,
      );
      final router = RelGeoMcpJsonRpcRouter(
        dispatcher: RelGeoMcpToolDispatcher(null, specIndex: specIndex),
        activeBridge: bridge,
        resources: resources,
      );
      final server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
      final result = RelGeoMcpDesktopServer._(
        server: server,
        session: session,
        token: token,
        router: router,
      );
      server.listen(result._handleRequest, onError: (_) {});
      return result;
    } catch (_) {
      session.stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _session.stop();
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    final origin = request.headers.value('origin');
    if (!_isLoopbackHost(request.headers.value('host') ?? '') ||
        (origin != null && !_isLoopbackOrigin(origin))) {
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }

    if (origin != null) {
      response.headers
        ..set('Access-Control-Allow-Origin', origin)
        ..set('Access-Control-Allow-Methods', 'POST, OPTIONS')
        ..set(
          'Access-Control-Allow-Headers',
          'Authorization, Content-Type, Accept, MCP-Protocol-Version',
        )
        ..set(HttpHeaders.varyHeader, 'Origin');
    }
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }
    if (request.uri.path != '/mcp' || request.uri.query.isNotEmpty) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    if (request.method != 'POST') {
      response.headers.set(HttpHeaders.allowHeader, 'POST, OPTIONS');
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    if (!_authorized(request)) {
      response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
      response.statusCode = HttpStatus.unauthorized;
      await response.close();
      return;
    }
    if (request.headers.contentType?.mimeType != 'application/json') {
      response.statusCode = HttpStatus.unsupportedMediaType;
      await response.close();
      return;
    }
    final accept = request.headers.value(HttpHeaders.acceptHeader) ?? '';
    if (!_accepts(accept, 'application/json') ||
        !_accepts(accept, 'text/event-stream')) {
      response.statusCode = HttpStatus.notAcceptable;
      await response.close();
      return;
    }
    final protocolHeader = request.headers.value('MCP-Protocol-Version');
    if (protocolHeader != null &&
        !RelGeoMcpJsonRpcRouter.supportedProtocolVersions.contains(
          protocolHeader,
        )) {
      response.statusCode = HttpStatus.badRequest;
      await response.close();
      return;
    }

    try {
      final body = await _readBody(request);
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
        response.statusCode = HttpStatus.badRequest;
        await response.close();
        return;
      }
      final message = Map<String, Object?>.from(
        decoded.cast<String, Object?>(),
      );
      final result = await _router.handle(message);
      if (result == null) {
        response.statusCode = HttpStatus.accepted;
      } else {
        response.headers
          ..contentType = ContentType.json
          ..set(
            'MCP-Protocol-Version',
            protocolHeader ??
                _router.negotiatedProtocolVersion ??
                _protocolVersion,
          );
        response.write(jsonEncode(result));
      }
    } on FormatException {
      response.statusCode = HttpStatus.badRequest;
    } on RequestTooLargeException {
      response.statusCode = HttpStatus.requestEntityTooLarge;
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    }
    await response.close();
  }

  bool _authorized(HttpRequest request) {
    final value = request.headers.value(HttpHeaders.authorizationHeader);
    if (value == null || !value.startsWith('Bearer ')) return false;
    return _session.authorize(
          value.substring('Bearer '.length),
          requiredPermission: McpPermission.readOnly,
        ) !=
        null;
  }

  static Future<String> _readBody(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in request) {
      length += chunk.length;
      if (length > _maxRequestBytes) throw const RequestTooLargeException();
      builder.add(chunk);
    }
    return utf8.decode(builder.takeBytes());
  }

  static bool _accepts(String header, String mimeType) => header
      .split(',')
      .map((value) => value.trim().split(';').first.trim().toLowerCase())
      .any((value) => value == mimeType || value == '*/*');

  static bool _isLoopbackHost(String hostHeader) {
    final host = hostHeader.toLowerCase().split(':').first;
    return host == '127.0.0.1' || host == 'localhost';
  }

  static bool _isLoopbackOrigin(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost') &&
        uri.userInfo.isEmpty &&
        uri.path.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }
}

class RequestTooLargeException implements Exception {
  const RequestTooLargeException();
}
