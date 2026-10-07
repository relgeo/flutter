import 'package:flutter/widgets.dart';

import 'parameters_panel.dart';
import 'workbench_parameters_contract.dart';

/// Optional parameter editing surface for documents that declare parameters.
class WorkbenchParametersFeature extends StatelessWidget {
  const WorkbenchParametersFeature({
    super.key,
    required this.contract,
    this.onClose,
    this.onFloat,
  });

  final WorkbenchParametersContract contract;
  final VoidCallback? onClose;
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
      onClose: onClose,
      onFloat: onFloat,
    );
  }
}
