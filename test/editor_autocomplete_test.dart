import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:relgeo_flutter/src/features/editor/editor_panel.dart';

void main() {
  testWidgets('autocomplete suggestions expose semantic selection actions', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final notifier = ValueNotifier<CodeAutocompleteEditingValue>(
      const CodeAutocompleteEditingValue(
        input: 'sc',
        prompts: [CodeKeywordPrompt(word: 'scene')],
        index: 0,
      ),
    );
    CodeAutocompleteResult? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: RelGeoAutocompleteView(
          notifier: notifier,
          onSelected: (result) => selected = result,
        ),
      ),
    );

    final suggestion = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == 'scene suggestion',
    );
    expect(suggestion, findsOneWidget);
    final node = tester.getSemantics(suggestion);
    expect(node.label, 'scene suggestion');
    expect(node.value, 'Keyword');
    expect(node.hint, 'Insert scene into the editor');
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);

    await tester.tap(suggestion);
    expect(selected?.word, 'scene');
    expect(selected?.input, 'sc');

    semanticsHandle.dispose();
    notifier.dispose();
  });
}
