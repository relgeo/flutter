import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/keyboard_activatable.dart';
import '../../ui/workbench_visual_profile.dart';

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
    this.visualProfile = WorkbenchVisualProfile.cad,
  });

  final Map<String, double> paramValues;
  final Map<String, dynamic> paramOverrides;
  final String targetUnit;
  final void Function(String name, double value) onParamChanged;
  final VoidCallback onParamReset;
  final WorkbenchVisualProfile visualProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120, maxHeight: 220),
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
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: paramValues.keys.map((pName) {
                  final current =
                      (paramOverrides[pName] ?? paramValues[pName]!) as double;
                  final maxVal = math.max(200.0, paramValues[pName]! * 2.5);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            pName,
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
                              label: '$pName parameter',
                              value:
                                  '${current.toStringAsFixed(1)} $targetUnit',
                              hint: 'Adjust $pName',
                              child: Slider(
                                value: current.clamp(1.0, maxVal),
                                min: 1.0,
                                max: maxVal,
                                onChanged: (value) =>
                                    onParamChanged(pName, value),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${current.toStringAsFixed(1)} $targetUnit',
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
