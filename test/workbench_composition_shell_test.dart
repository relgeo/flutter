import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('floating placement renders above the docked panel layer', (
    tester,
  ) async {
    final standard = WorkbenchLayoutModel.standard();
    final controller = WorkbenchLayoutController(
      initialLayout: standard.copyWith(
        panels: {
          ...standard.panels,
          WorkbenchPanelId.inspector: standard
              .panels[WorkbenchPanelId.inspector]!
              .copyWith(placement: WorkbenchPanelPlacement.floating),
        },
        floatingBounds: const {
          WorkbenchPanelId.inspector: WorkbenchPanelBounds(
            left: 24,
            top: 24,
            width: 280,
            height: 220,
          ),
        },
      ),
    );

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

    expect(
      find.bySemanticsLabel('Resize floating workbench panel'),
      findsOneWidget,
    );
    expect(find.text('inspector'), findsOneWidget);
    controller.moveFloatingPanel(WorkbenchPanelId.inspector, dx: 20, dy: 10);
    await tester.pump();
    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.left,
      44,
    );

    controller.toggleCollapsed(WorkbenchPanelId.inspector);
    await tester.pump();
    expect(find.text('INSPECTOR'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Resize floating workbench panel'),
      findsNothing,
    );

    controller.toggleCollapsed(WorkbenchPanelId.inspector);
    controller.setPlacement(
      WorkbenchPanelId.inspector,
      WorkbenchPanelPlacement.overlay,
    );
    await tester.pump();
    expect(find.byTooltip('Close inspector overlay'), findsOneWidget);
    await tester.tap(find.byTooltip('Close inspector overlay'));
    await tester.pump();
    expect(find.text('inspector'), findsNothing);

    controller.setPanelVisibility(
      WorkbenchPanelId.inspector,
      WorkbenchPanelVisibility.visible,
    );
    await tester.pump();
    await tester.tap(find.text('inspector'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('inspector'), findsNothing);
  });

  testWidgets('floating panels dock into the nearest drop zone on release', (
    tester,
  ) async {
    final standard = WorkbenchLayoutModel.standard();
    final controller = WorkbenchLayoutController(
      initialLayout: standard.copyWith(
        panels: {
          ...standard.panels,
          WorkbenchPanelId.inspector: standard
              .panels[WorkbenchPanelId.inspector]!
              .copyWith(placement: WorkbenchPanelPlacement.floating),
        },
        floatingBounds: const {
          WorkbenchPanelId.inspector: WorkbenchPanelBounds(
            left: 420,
            top: 24,
            width: 280,
            height: 220,
          ),
        },
      ),
    );

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

    controller.moveFloatingPanel(
      WorkbenchPanelId.inspector,
      dx: -420,
      dy: 0,
      canvasWidth: 800,
      canvasHeight: 560,
    );
    controller.dockFloatingPanelIfDropped(
      WorkbenchPanelId.inspector,
      canvasWidth: 800,
      canvasHeight: 560,
    );
    await tester.pump();

    expect(
      controller.panel(WorkbenchPanelId.inspector).placement,
      WorkbenchPanelPlacement.left,
    );
  });

  testWidgets('docking a floating panel restores focus to its docked surface', (
    tester,
  ) async {
    final standard = WorkbenchLayoutModel.standard();
    final controller = WorkbenchLayoutController(
      initialLayout: standard.copyWith(
        panels: {
          ...standard.panels,
          WorkbenchPanelId.inspector: standard
              .panels[WorkbenchPanelId.inspector]!
              .copyWith(placement: WorkbenchPanelPlacement.floating),
        },
        floatingBounds: const {
          WorkbenchPanelId.inspector: WorkbenchPanelBounds(
            left: 420,
            top: 24,
            width: 280,
            height: 220,
          ),
        },
      ),
    );

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

    controller.dockFloatingPanelIfDropped(
      WorkbenchPanelId.inspector,
      canvasWidth: 800,
      canvasHeight: 560,
    );
    await tester.pump();

    final inspectorContext = tester.element(find.text('inspector'));
    expect(Focus.of(inspectorContext).hasFocus, isTrue);
    expect(controller.focusRequest, isNull);
  });

  testWidgets('docked panels participate in keyboard traversal', (
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

    final editorNode = Focus.of(tester.element(find.text('editor')));
    final viewportNode = Focus.of(tester.element(find.text('viewport')));
    final inspectorNode = Focus.of(tester.element(find.text('inspector')));
    editorNode.requestFocus();
    await tester.pump();

    expect(editorNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(viewportNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(inspectorNode.hasFocus, isTrue);
  });

  testWidgets('panel splitters resize with keyboard arrows', (tester) async {
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

    final divider = find.bySemanticsLabel('Resize workbench panels').first;
    final dividerNode = Focus.of(tester.element(divider));
    dividerNode.requestFocus();
    await tester.pump();
    final before = controller.layout.splitRatios['left']!;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(controller.layout.splitRatios['left'], greaterThan(before));
  });

  testWidgets('floating resize handle responds to keyboard arrows', (
    tester,
  ) async {
    final standard = WorkbenchLayoutModel.standard();
    final controller = WorkbenchLayoutController(
      initialLayout: standard.copyWith(
        panels: {
          ...standard.panels,
          WorkbenchPanelId.inspector: standard
              .panels[WorkbenchPanelId.inspector]!
              .copyWith(placement: WorkbenchPanelPlacement.floating),
        },
        floatingBounds: const {
          WorkbenchPanelId.inspector: WorkbenchPanelBounds(
            left: 120,
            top: 24,
            width: 280,
            height: 220,
          ),
        },
      ),
    );

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

    final handle = find.bySemanticsLabel('Resize floating workbench panel');
    final handleNode = Focus.of(tester.element(handle));
    handleNode.requestFocus();
    await tester.pump();
    final before =
        controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.width!;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.width,
      greaterThan(before),
    );
  });

  testWidgets('collapsed floating panels expose a restore action', (
    tester,
  ) async {
    final standard = WorkbenchLayoutModel.standard();
    final controller = WorkbenchLayoutController(
      initialLayout: standard.copyWith(
        panels: {
          ...standard.panels,
          WorkbenchPanelId.inspector: standard
              .panels[WorkbenchPanelId.inspector]!
              .copyWith(
                placement: WorkbenchPanelPlacement.floating,
                visibility: WorkbenchPanelVisibility.collapsed,
              ),
        },
      ),
    );

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

    await tester.tap(find.text('INSPECTOR'));
    await tester.pump();

    expect(
      controller.panel(WorkbenchPanelId.inspector).visibility,
      WorkbenchPanelVisibility.visible,
    );
  });
}
