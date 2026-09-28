import 'package:flutter/widgets.dart';

import 'parameters_panel.dart';
import 'workbench_parameters_contract.dart';

/// Optional parameter editing surface for documents that declare parameters.
class WorkbenchParametersFeature extends StatelessWidget {
  const WorkbenchParametersFeature({
    super.key,
    required this.contract,
    this.onCollapse,
    this.onFloat,
  });

  final WorkbenchParametersContract contract;
  final VoidCallback? onCollapse;
  final VoidCallback? onFloat;

  @override
  Widget build(BuildContext context) {
    return ParametersPanel(
      paramValues: contract.paramValues,
      paramOverrides: contract.paramOverrides,
      targetUnit: contract.targetUnit,
      onParamChanged: contract.onParamChanged,
      onParamReset: contract.onParamReset,
      visualProfile: contract.visualProfile,
      onCollapse: onCollapse,
      onFloat: onFloat,
    );
  }
}
