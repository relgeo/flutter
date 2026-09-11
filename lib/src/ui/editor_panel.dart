import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'workbench_visual_profile.dart';

class EditorPanel extends StatelessWidget {
  final CodeLineEditingController controller;
  final Map<String, double> paramValues;
  final Map<String, dynamic> paramOverrides;
  final String targetUnit;
  final void Function(String name, double value) onParamChanged;
  final VoidCallback onParamReset;
  final WorkbenchVisualProfile visualProfile;

  const EditorPanel({
    super.key,
    required this.controller,
    required this.paramValues,
    required this.paramOverrides,
    required this.targetUnit,
    required this.onParamChanged,
    required this.onParamReset,
    this.visualProfile = WorkbenchVisualProfile.cadDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: visualProfile.toolbarBackgroundColor,
        border: Border(
          right: BorderSide(color: visualProfile.borderColor, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Editor header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            color: visualProfile.overlayBackgroundColor,
            child: Row(
              children: [
                Icon(
                  Icons.terminal,
                  color: visualProfile.accentColor,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  'DSL EDITOR',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: visualProfile.accentColor,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: visualProfile.borderColor),

          // Code editor
          Expanded(
            child: Container(
              color: visualProfile.toolbarBackgroundColor,
              child: Platform.environment.containsKey('FLUTTER_TEST')
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          controller.text.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Courier',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : CodeAutocomplete(
                      viewBuilder: (context, notifier, onSelected) {
                        return RelGeoAutocompleteView(
                          notifier: notifier,
                          onSelected: onSelected,
                          visualProfile: visualProfile,
                        );
                      },
                      promptsBuilder: DefaultCodeAutocompletePromptsBuilder(
                        language: langYaml,
                        directPrompts: relgeoPrompts,
                      ),
                      child: CodeEditor(
                        controller: controller,
                        wordWrap: true,
                        style: CodeEditorStyle(
                          fontSize: 12.5,
                          fontFamily: 'Courier',
                          textColor: Colors.white,
                          backgroundColor: visualProfile.toolbarBackgroundColor,
                          cursorColor: visualProfile.accentColor,
                          cursorLineColor: visualProfile.accentSoftColor,
                          selectionColor: visualProfile.accentSoftColor,
                          chunkIndicatorColor: visualProfile.mutedColor,
                          codeTheme: CodeHighlightTheme(
                            languages: {
                              'yaml': CodeHighlightThemeMode(mode: langYaml),
                            },
                            theme: atomOneDarkTheme,
                          ),
                        ),
                        indicatorBuilder:
                            (
                              context,
                              editingController,
                              chunkController,
                              notifier,
                            ) {
                              return Row(
                                children: [
                                  DefaultCodeLineNumber(
                                    controller: editingController,
                                    notifier: notifier,
                                    textStyle: TextStyle(
                                      color: visualProfile.mutedColor,
                                      fontSize: 11,
                                      fontFamily: 'Courier',
                                    ),
                                    focusedTextStyle: TextStyle(
                                      color: visualProfile.accentColor,
                                      fontSize: 11,
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  DefaultCodeChunkIndicator(
                                    width: 16,
                                    controller: chunkController,
                                    notifier: notifier,
                                  ),
                                ],
                              );
                            },
                      ),
                    ),
            ),
          ),

          // Parameter sliders (only visible if parameters are defined)
          if (paramValues.isNotEmpty) _buildParameterPanel(context),
        ],
      ),
    );
  }

  Widget _buildParameterPanel(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: visualProfile.overlayBackgroundColor,
        border: Border(
          top: BorderSide(color: visualProfile.borderColor, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
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
                  InkWell(
                    onTap: onParamReset,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            color: visualProfile.accentColor,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'RESET',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: visualProfile.accentColor,
                            ),
                          ),
                        ],
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
                            child: Slider(
                              value: current,
                              min: 1.0,
                              max: maxVal,
                              onChanged: (v) => onParamChanged(pName, v),
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

// ─────────────────────────────────────────────
// Code Autocomplete Prompts and UI Gutter
// ─────────────────────────────────────────────

const relgeoKeywords = [
  CodeKeywordPrompt(word: 'version'),
  CodeKeywordPrompt(word: 'scene'),
  CodeKeywordPrompt(word: 'parameters'),
  CodeKeywordPrompt(word: 'derived'),
  CodeKeywordPrompt(word: 'objects'),
  CodeKeywordPrompt(word: 'constraints'),
  CodeKeywordPrompt(word: 'components'),
  CodeKeywordPrompt(word: 'sheets'),
  CodeKeywordPrompt(word: 'views'),
];

const relgeoObjectTypes = [
  CodeFieldPrompt(word: 'point', type: 'type'),
  CodeFieldPrompt(word: 'line', type: 'type'),
  CodeFieldPrompt(word: 'rect', type: 'type'),
  CodeFieldPrompt(word: 'circle', type: 'type'),
  CodeFieldPrompt(word: 'group', type: 'type'),
  CodeFieldPrompt(word: 'text', type: 'type'),
  CodeFieldPrompt(word: 'path', type: 'type'),
  CodeFieldPrompt(word: 'polygon', type: 'type'),
  CodeFieldPrompt(word: 'clone', type: 'type'),
  CodeFieldPrompt(word: 'arc', type: 'type'),
  CodeFieldPrompt(word: 'cubic', type: 'type'),
  CodeFieldPrompt(word: 'quadratic', type: 'type'),
  CodeFieldPrompt(word: 'repeat', type: 'type'),
  CodeFieldPrompt(word: 'divide', type: 'type'),
  CodeFieldPrompt(word: 'collection', type: 'type'),
  CodeFieldPrompt(word: 'component', type: 'type'),
  CodeFieldPrompt(word: 'dimension', type: 'type'),
  CodeFieldPrompt(word: 'annotation', type: 'type'),
  CodeFieldPrompt(word: 'boolean', type: 'type'),
];

const relgeoFunctions = [
  CodeFunctionPrompt(
    word: 'intersection',
    type: 'Point',
    parameters: {'obj1': 'id', 'obj2': 'id'},
  ),
  CodeFunctionPrompt(
    word: 'distance',
    type: 'number',
    parameters: {'obj1': 'id', 'obj2': 'id'},
  ),
  CodeFunctionPrompt(word: 'length', type: 'number', parameters: {'obj': 'id'}),
  CodeFunctionPrompt(word: 'area', type: 'number', parameters: {'obj': 'id'}),
  CodeFunctionPrompt(
    word: 'pointAt',
    type: 'Point',
    parameters: {'obj': 'id', 't': 'number'},
  ),
  CodeFunctionPrompt(
    word: 'tangentAt',
    type: 'Vector',
    parameters: {'obj': 'id', 't': 'number'},
  ),
  CodeFunctionPrompt(
    word: 'normalAt',
    type: 'Vector',
    parameters: {'obj': 'id', 't': 'number'},
  ),
  CodeFunctionPrompt(
    word: 'closestPoint',
    type: 'Point',
    parameters: {'ref': 'Point', 'target': 'id'},
  ),
  CodeFunctionPrompt(
    word: 'min',
    type: 'number',
    parameters: {'a': 'number', 'b': 'number'},
  ),
  CodeFunctionPrompt(
    word: 'max',
    type: 'number',
    parameters: {'a': 'number', 'b': 'number'},
  ),
  CodeFunctionPrompt(word: 'abs', type: 'number', parameters: {'x': 'number'}),
  CodeFunctionPrompt(
    word: 'clamp',
    type: 'number',
    parameters: {'val': 'number', 'min': 'number', 'max': 'number'},
  ),
  CodeFunctionPrompt(word: 'sin', type: 'number', parameters: {'x': 'number'}),
  CodeFunctionPrompt(word: 'cos', type: 'number', parameters: {'x': 'number'}),
  CodeFunctionPrompt(word: 'tan', type: 'number', parameters: {'x': 'number'}),
  CodeFunctionPrompt(word: 'sqrt', type: 'number', parameters: {'x': 'number'}),
];

const relgeoFields = [
  CodeFieldPrompt(word: 'type', type: 'Field'),
  CodeFieldPrompt(word: 'meta', type: 'Field'),
  CodeFieldPrompt(word: 'anchors', type: 'Field'),
  CodeFieldPrompt(word: 'place', type: 'Field'),
  CodeFieldPrompt(word: 'visible', type: 'Field'),
  CodeFieldPrompt(word: 'stroke', type: 'Field'),
  CodeFieldPrompt(word: 'fill', type: 'Field'),
  CodeFieldPrompt(word: 'width', type: 'Field'),
  CodeFieldPrompt(word: 'opacity', type: 'Field'),
  CodeFieldPrompt(word: 'dash', type: 'Field'),
  CodeFieldPrompt(word: 'role', type: 'Field'),
  CodeFieldPrompt(word: 'left', type: 'Field'),
  CodeFieldPrompt(word: 'right', type: 'Field'),
  CodeFieldPrompt(word: 'top', type: 'Field'),
  CodeFieldPrompt(word: 'bottom', type: 'Field'),
  CodeFieldPrompt(word: 'center', type: 'Field'),
  CodeFieldPrompt(word: 'topLeft', type: 'Field'),
  CodeFieldPrompt(word: 'topRight', type: 'Field'),
  CodeFieldPrompt(word: 'bottomLeft', type: 'Field'),
  CodeFieldPrompt(word: 'bottomRight', type: 'Field'),
];

final List<CodePrompt> relgeoPrompts = [
  ...relgeoKeywords,
  ...relgeoObjectTypes,
  ...relgeoFunctions,
  ...relgeoFields,
];

class RelGeoAutocompleteView extends StatelessWidget
    implements PreferredSizeWidget {
  final ValueNotifier<CodeAutocompleteEditingValue> notifier;
  final ValueChanged<CodeAutocompleteResult> onSelected;
  final WorkbenchVisualProfile visualProfile;

  const RelGeoAutocompleteView({
    super.key,
    required this.notifier,
    required this.onSelected,
    this.visualProfile = WorkbenchVisualProfile.cadDark,
  });

  @override
  Size get preferredSize => const Size(280, 220);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CodeAutocompleteEditingValue>(
      valueListenable: notifier,
      builder: (context, value, _) {
        if (value.prompts.isEmpty) return const SizedBox.shrink();

        return Container(
          width: preferredSize.width,
          height: preferredSize.height,
          decoration: BoxDecoration(
            color: visualProfile.toolbarBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: visualProfile.accentColor, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: value.prompts.length,
              itemBuilder: (context, idx) {
                final prompt = value.prompts[idx];
                final isSelected = value.index == idx;

                String label = prompt.word;
                String type = 'Keyword';
                String? desc;

                if (prompt is CodeFieldPrompt) {
                  type = prompt.type;
                } else if (prompt is CodeFunctionPrompt) {
                  type = 'Fn';
                  desc =
                      '${prompt.word}(${prompt.parameters.keys.join(', ')}) → ${prompt.type}';
                }

                return GestureDetector(
                  onTap: () {
                    onSelected(value.copyWith(index: idx).autocomplete);
                  },
                  child: Container(
                    color: isSelected
                        ? visualProfile.accentSoftColor
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          type == 'Fn'
                              ? Icons.functions
                              : (type == 'Keyword'
                                    ? Icons.code
                                    : Icons.grid_view),
                          size: 13,
                          color: isSelected
                              ? visualProfile.accentColor
                              : visualProfile.mutedColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? visualProfile.accentColor
                                      : Colors.white,
                                ),
                              ),
                              if (desc != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 9,
                                    color: visualProfile.mutedColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? visualProfile.accentSoftColor
                                : visualProfile.borderColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? visualProfile.accentColor
                                  : visualProfile.mutedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
