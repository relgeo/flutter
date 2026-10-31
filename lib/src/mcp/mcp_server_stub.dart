import 'package:relgeo_mcp/relgeo_mcp.dart';

import 'spec_snapshot_loader.dart';
import 'workbench_agent_bridge.dart';

/// Unsupported-platform implementation used by Flutter web builds.
class RelGeoMcpDesktopServer {
  RelGeoMcpDesktopServer._();

  static Future<RelGeoMcpDesktopServer> start({
    required WorkbenchAgentBridge bridge,
    McpPermission permission = McpPermission.readOnly,
    RelGeoSpecSnapshotLoader? specLoader,
  }) => throw UnsupportedError('The local MCP server requires a desktop app.');

  String get endpoint => '';
  String get token => '';
  McpPermission get permission => McpPermission.readOnly;

  Future<void> stop() async {}
}
