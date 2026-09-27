import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_composition_shell.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_controller.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';

void main() {
  testWidgets('renders the injected navbar and three feature surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchCompositionShell(
          navbar: const Text('navbar'),
          editor: const Text('editor'),
          viewport: const Text('viewport'),
          inspector: const Text('inspector'),
        ),
      ),
    );

    expect(find.text('navbar'), findsOneWidget);
    expect(find.text('editor'), findsOneWidget);
    expect(find.text('viewport'), findsOneWidget);
    expect(find.text('inspector'), findsOneWidget);
  });

  testWidgets('preserves the desktop panel flex contract', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchCompositionShell(
          navbar: const SizedBox(key: ValueKey('navbar')),
          editor: const SizedBox(key: ValueKey('editor')),
          viewport: const SizedBox(key: ValueKey('viewport')),
          inspector: const SizedBox(key: ValueKey('inspector')),
        ),
      ),
    );

    final row = tester.widget<Row>(find.byType(Row));
    final expanded = row.children.whereType<Expanded>().toList();
    expect(expanded, hasLength(3));
    expect(expanded[0].flex, 32);
    expect(expanded[1].flex, 43);
    expect(expanded[2].flex, 25);
  });

  testWidgets('uses a horizontally scrollable minimum canvas in compact mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchCompositionShell(
          navbar: const SizedBox(),
          editor: const SizedBox(),
          viewport: const SizedBox(),
          inspector: const SizedBox(),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scrollView.scrollDirection, Axis.horizontal);
  });

  testWidgets('interactive shell honors panel visibility and splitter drags', (
    tester,
  ) async {
    final controller = WorkbenchLayoutController();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchCompositionShell(
          navbar: const SizedBox(),
          layoutController: controller,
          editor: const Text('editor'),
          viewport: const Text('viewport'),
          inspector: const Text('inspector'),
        ),
      ),
    );

    expect(find.text('editor'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workbench-divider-editor')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('workbench-divider-editor')),
      const Offset(80, 0),
    );
    expect(controller.layout.splitRatios['left'], greaterThan(0.32));

    controller.togglePanel(WorkbenchPanelId.editor);
    await tester.pump();
    expect(find.text('editor'), findsNothing);
    expect(find.text('viewport'), findsOneWidget);
    expect(find.text('inspector'), findsOneWidget);
  });

  testWidgets('interactive shell keeps a collapsed panel as a labeled rail', (
    tester,
  ) async {
    final controller = WorkbenchLayoutController();
    controller.toggleCollapsed(WorkbenchPanelId.inspector);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchCompositionShell(
          navbar: const SizedBox(),
          layoutController: controller,
          editor: const Text('editor'),
          viewport: const Text('viewport'),
          inspector: const Text('inspector'),
        ),
      ),
    );

    expect(find.text('inspector'), findsNothing);
    expect(find.text('INSPECTOR'), findsOneWidget);
  });

  testWidgets('parameters are an optional standalone bottom surface', (
    tester,
  ) async {
    final controller = WorkbenchLayoutController();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchCompositionShell(
          navbar: const SizedBox(),
          layoutController: controller,
          editor: const Text('editor'),
          viewport: const Text('viewport'),
          inspector: const Text('inspector'),
          parameters: const Text('parameters'),
        ),
      ),
    );

    expect(find.text('parameters'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workbench-divider-parameters')),
      findsOneWidget,
    );
    controller.resizeParameters(70, 600);
    await tester.pump();
    expect(
      controller.panel(WorkbenchPanelId.parameters).bounds.height,
      greaterThan(220),
    );
    controller.setPanelVisibility(
      WorkbenchPanelId.parameters,
      WorkbenchPanelVisibility.hidden,
    );
    await tester.pump();
    expect(find.text('parameters'), findsNothing);
  });
}
