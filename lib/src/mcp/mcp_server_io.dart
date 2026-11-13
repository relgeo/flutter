import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relgeo_mcp/relgeo_mcp.dart';

import 'spec_snapshot_loader.dart';

/// Streamable HTTP endpoint owned by one running desktop workbench session.
///
/// It binds only to IPv4 loopback, requires the in-memory bearer token, and
/// exposes only resources backed by the active workbench bridge.
class RelGeoMcpDesktopServer {
  RelGeoMcpDesktopServer._({
    required HttpServer server,
    required McpServerSession session,
    required this.token,
    required this.permission,
    required RelGeoMcpJsonRpcRouter router,
    required Duration requestTimeout,
  }) : _server = server,
       _session = session,
       _router = router,
       _requestTimeout = requestTimeout;

  static const _maxRequestBytes = 1024 * 1024;
  static const _protocolVersion = RelGeoMcpJsonRpcRouter.protocolVersion;

  final HttpServer _server;
  final McpServerSession _session;
  final RelGeoMcpJsonRpcRouter _router;
  final Duration _requestTimeout;
  bool _stopped = false;
  int _activeRequests = 0;

  final String token;
  final McpPermission permission;

  String get endpoint => 'http://127.0.0.1:${_server.port}/mcp';

  /// Safe operational state for the host UI. Durable client identity is not
  /// inferred from bearer requests; active authorized requests are reported
  /// separately instead.
  McpServerStatus get status => _session.status(
    endpoint: endpoint,
    permission: permission,
    activeRequests: _activeRequests,
  );

  static Future<RelGeoMcpDesktopServer> start({
    required RelGeoAgentBridge bridge,
    McpPermission permission = McpPermission.readOnly,
    RelGeoSpecSnapshotLoader? specLoader,
    Duration requestTimeout = const Duration(seconds: 30),
  }) async {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'must be greater than zero',
      );
    }
    final session = McpServerSession(
      policy: const McpSecurityPolicy(enabled: true),
    )..start();
    try {
      final token = session
          .issueToken(permission: permission, ttl: const Duration(hours: 8))
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
        allowDocumentEdits: permission == McpPermission.readWrite,
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
        permission: permission,
        router: router,
        requestTimeout: requestTimeout,
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
    _router.cancelPendingRequests();
    _session.stop();
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    final origin = request.headers.value('origin');
    if (!_isLoopbackHost(request.headers.value('host') ?? '') ||
        (origin != null && !_isLoopbackOrigin(origin))) {
      await _errorResponse(
        response,
        HttpStatus.forbidden,
        category: origin == null ? 'host-rejected' : 'origin-rejected',
        message: 'MCP accepts only loopback host and origin values.',
      );
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
      await _errorResponse(
        response,
        HttpStatus.notFound,
        category: 'route-not-found',
        message: 'MCP endpoint not found.',
      );
      return;
    }
    if (request.method != 'POST') {
      response.headers.set(HttpHeaders.allowHeader, 'POST, OPTIONS');
      await _errorResponse(
        response,
        HttpStatus.methodNotAllowed,
        category: 'method-not-allowed',
        message: 'MCP endpoint accepts POST requests only.',
      );
      return;
    }
    final authorization = _authorized(request);
    if (authorization == null) {
      response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
      await _errorResponse(
        response,
        HttpStatus.unauthorized,
        category: 'unauthorized',
        message: 'A valid MCP bearer token is required.',
      );
      return;
    }
    _activeRequests += 1;
    unawaited(
      response.done.then<void>(
        (_) {
          if (_activeRequests > 0) _activeRequests -= 1;
        },
        onError: (Object _, StackTrace _) {
          if (_activeRequests > 0) _activeRequests -= 1;
        },
      ),
    );
    if (request.headers.contentType?.mimeType != 'application/json') {
      await _errorResponse(
        response,
        HttpStatus.unsupportedMediaType,
        category: 'unsupported-media-type',
        message: 'MCP requests must use application/json.',
      );
      return;
    }
    final accept = request.headers.value(HttpHeaders.acceptHeader) ?? '';
    if (!_accepts(accept, 'application/json') ||
        !_accepts(accept, 'text/event-stream')) {
      await _errorResponse(
        response,
        HttpStatus.notAcceptable,
        category: 'not-acceptable',
        message: 'MCP clients must accept JSON and text/event-stream.',
      );
      return;
    }
    final protocolHeader = request.headers.value('MCP-Protocol-Version');
    if ((_router.initialized && protocolHeader == null) ||
        (protocolHeader != null &&
            !RelGeoMcpJsonRpcRouter.supportedProtocolVersions.contains(
              protocolHeader,
            ))) {
      await _errorResponse(
        response,
        HttpStatus.badRequest,
        category: 'protocol-version',
        message: 'Unsupported or missing MCP protocol version.',
      );
      return;
    }

    try {
      final body = await _readBody(request).timeout(_requestTimeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
        await _errorResponse(
          response,
          HttpStatus.badRequest,
          category: 'invalid-request',
          message: 'MCP request body must be a JSON object.',
        );
        return;
      }
      final message = Map<String, Object?>.from(
        decoded.cast<String, Object?>(),
      );
      if (message['id'] != null) {
        unawaited(
          response.done.then<void>(
            (_) {},
            onError: (Object _, StackTrace _) =>
                _router.cancelRequest(message['id'], 'MCP client disconnected'),
          ),
        );
      }
      if (_requiresDocumentEditPermission(message) &&
          authorization.permission != McpPermission.readWrite) {
        await _errorResponse(
          response,
          HttpStatus.forbidden,
          category: 'forbidden',
          message: 'Document editing is disabled for this MCP session.',
        );
        return;
      }
      final result = await _router
          .handle(message)
          .timeout(
            _requestTimeout,
            onTimeout: () {
              _router.cancelRequest(message['id'], 'MCP request timed out');
              return <String, Object?>{
                'jsonrpc': '2.0',
                'id': message['id'],
                'error': <String, Object?>{
                  'code': -32800,
                  'message': 'MCP request timed out',
                  'category': 'cancelled',
                  'data': <String, Object?>{'category': 'request-timeout'},
                },
              };
            },
          );
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
      await _errorResponse(
        response,
        HttpStatus.badRequest,
        category: 'invalid-json',
        message: 'MCP request body is not valid JSON.',
      );
      return;
    } on TimeoutException {
      await _errorResponse(
        response,
        HttpStatus.requestTimeout,
        category: 'request-timeout',
        message: 'MCP request body timed out.',
      );
      return;
    } on RequestTooLargeException {
      await _errorResponse(
        response,
        HttpStatus.requestEntityTooLarge,
        category: 'request-too-large',
        message: 'MCP request body exceeds the size limit.',
      );
      return;
    } catch (_) {
      await _errorResponse(
        response,
        HttpStatus.internalServerError,
        category: 'transport-failure',
        message: 'MCP transport failed before a response was completed.',
      );
      return;
    }
    await response.close();
  }

  static Future<void> _errorResponse(
    HttpResponse response,
    int statusCode, {
    required String category,
    required String message,
  }) async {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json;
    response.write(
      jsonEncode(<String, Object?>{
        'error': <String, Object?>{
          'code': statusCode,
          'message': message,
          'data': <String, Object?>{'category': category},
        },
      }),
    );
    await response.close();
  }

  McpSessionToken? _authorized(HttpRequest request) {
    final value = request.headers.value(HttpHeaders.authorizationHeader);
    if (value == null || !value.startsWith('Bearer ')) return null;
    return _session.authorize(
      value.substring('Bearer '.length),
      requiredPermission: McpPermission.readOnly,
    );
  }

  static bool _requiresDocumentEditPermission(Map<String, Object?> message) {
    final params = message['params'];
    return message['method'] == 'tools/call' &&
        params is Map &&
        params['name'] == 'relgeo_apply_document_edit';
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
