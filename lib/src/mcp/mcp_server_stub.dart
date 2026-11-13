import 'package:relgeo_mcp/relgeo_mcp.dart';

import 'spec_snapshot_loader.dart';

/// Unsupported-platform implementation used by Flutter web builds.
class RelGeoMcpDesktopServer {
  RelGeoMcpDesktopServer._();

  static Future<RelGeoMcpDesktopServer> start({
    required RelGeoAgentBridge bridge,
    McpPermission permission = McpPermission.readOnly,
    RelGeoSpecSnapshotLoader? specLoader,
    Duration requestTimeout = const Duration(seconds: 30),
  }) => throw UnsupportedError('The local MCP server requires a desktop app.');

  String get endpoint => '';
  String get token => '';
  McpPermission get permission => McpPermission.readOnly;
  McpServerStatus get status => const McpServerStatus(
    running: false,
    connectedClients: 0,
  );

  Future<void> stop() async {}
}
