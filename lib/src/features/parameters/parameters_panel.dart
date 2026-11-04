import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/keyboard_activatable.dart';
import '../../ui/workbench_panel_interaction.dart';
import '../../ui/workbench_visual_profile.dart';
import '../editor/workbench_document_settings.dart';

/// Standalone parameters panel.
///
/// This surface intentionally owns only parameter controls. It does not know
/// about the editor, document compilation, or layout persistence.
class ParametersPanel extends StatelessWidget {
  const ParametersPanel({
    super.key,
    required this.paramValues,
    required this.paramOverrides,
    required this.targetUnit,
    required this.onParamChanged,
    required this.onParamReset,
    this.parameterSpecs = const <String, WorkbenchParameterSpec>{},
    this.visualProfile = WorkbenchVisualProfile.cad,
    this.onClose,
    this.onFloat,
  });

  final Map<String, double> paramValues;
  final Map<String, dynamic> paramOverrides;
  final String targetUnit;
  final void Function(String name, double value) onParamChanged;
  final VoidCallback onParamReset;
  final Map<String, WorkbenchParameterSpec> parameterSpecs;
  final WorkbenchVisualProfile visualProfile;
  final VoidCallback? onClose;
  final VoidCallback? onFloat;

  @override
  Widget build(BuildContext context) {
    final interaction = WorkbenchPanelInteractionScope.maybeOf(context);
    final isFloating = interaction?.isFloating ?? false;
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: visualProfile.overlayBackgroundColor,
        border: Border(
          top: BorderSide(color: visualProfile.borderColor, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: WorkbenchPanelTitleBar(
              child: Row(
                children: [
                  Icon(Icons.tune, color: visualProfile.accentColor, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    'PARAMETERS (${paramValues.length})',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.6,
                      color: visualProfile.mutedColor,
                    ),
                  ),
                  const Spacer(),
                  if (paramOverrides.isNotEmpty)
                    Semantics(
                      button: true,
                      label: 'Reset parameter overrides',
                      hint: 'Restore default parameter values',
                      onTap: onParamReset,
                      child: WorkbenchKeyboardActivatable(
                        onActivate: onParamReset,
                        focusColor: visualProfile.accentColor,
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: onParamReset,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'RESET',
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onFloat != null && !isFloating) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      key: const Key('float-parameters-panel'),
                      tooltip: 'Float Parameters',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      color: visualProfile.mutedColor,
                      onPressed: onFloat,
                    ),
                  ],
                  if (onClose != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      key: const Key('close-parameters-panel'),
                      tooltip: 'Close Parameters panel',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      color: visualProfile.mutedColor,
                      onPressed: onClose,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: paramValues.keys.map((pName) {
                  final spec = parameterSpecs[pName];
                  final current =
                      ((paramOverrides[pName] ?? paramValues[pName]!) as num)
                          .toDouble();
                  final minVal = spec?.min ?? 1.0;
                  final configuredStep = spec?.step;
                  final rangeStep = configuredStep != null && configuredStep > 0
                      ? configuredStep
                      : 1.0;
                  final fallbackMax = math.max(
                    math.max(200.0, paramValues[pName]! * 2.5),
                    minVal + rangeStep,
                  );
                  final configuredMax = spec?.max;
                  final maxVal = configuredMax != null && configuredMax > minVal
                      ? configuredMax
                      : fallbackMax;
                  final calculatedDivisions = configuredStep != null &&
                          configuredStep > 0
                      ? ((maxVal - minVal) / configuredStep).round()
                      : 0;
                  final divisions = calculatedDivisions > 0
                      ? calculatedDivisions
                      : null;
                  final safeCurrent = current.clamp(minVal, maxVal).toDouble();
                  final displayLabel = spec?.displayLabel ?? pName;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            displayLabel,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: visualProfile.mutedColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2.5,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                            ),
                            child: Semantics(
                              label: '$displayLabel parameter',
                              value:
                                  '${safeCurrent.toStringAsFixed(1)} $targetUnit',
                              hint: 'Adjust $displayLabel',
                              child: Slider(
                                value: safeCurrent,
                                min: minVal,
                                max: maxVal,
                                divisions: divisions,
                                onChanged: (value) =>
                                    onParamChanged(pName, value),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${safeCurrent.toStringAsFixed(1)} $targetUnit',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: visualProfile.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
