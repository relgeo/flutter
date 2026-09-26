import 'package:flutter/widgets.dart';

import 'inspector_panel.dart';
import 'workbench_inspector_contract.dart';

/// Inspector feature surface.
///
/// Scene and diagnostic snapshots are supplied by the composition root so the
/// inspector does not reach into editor, document, or viewport state directly.
class WorkbenchInspectorFeature extends StatelessWidget {
  const WorkbenchInspectorFeature({super.key, required this.contract});

  final WorkbenchInspectorContract contract;

  @override
  Widget build(BuildContext context) {
    return InspectorPanel(
      scene: contract.scene,
      yamlError: contract.yamlError,
      compilerError: contract.compilerError,
      targetUnit: contract.targetUnit,
      visualProfile: contract.visualProfile,
      themeTokens: contract.themeTokens,
    );
  }
}
