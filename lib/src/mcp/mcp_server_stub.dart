import 'spec_snapshot_loader.dart';
import 'workbench_agent_bridge.dart';

/// Unsupported-platform implementation used by Flutter web builds.
class RelGeoMcpDesktopServer {
  RelGeoMcpDesktopServer._();

  static Future<RelGeoMcpDesktopServer> start({
    required WorkbenchAgentBridge bridge,
    RelGeoSpecSnapshotLoader? specLoader,
  }) => throw UnsupportedError('The local MCP server requires a desktop app.');

  String get endpoint => '';
  String get token => '';

  Future<void> stop() async {}
}
