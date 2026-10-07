import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_composition_shell.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_layout_adapter.dart';
import 'package:relgeo_flutter/src/ui/docking/dock_node.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_controller.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';
import 'package:relgeo_flutter/src/ui/workbench_panel_interaction.dart';

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

  testWidgets('recursive dock tree remains scrollable in compact shell mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final layout = WorkbenchLayoutModel.standard();
    final controller = WorkbenchLayoutController(initialLayout: layout);
    controller.restore(
      layout,
      dockedRoot: DockSplitNode(
        axis: DockAxis.horizontal,
        children: const [
          DockPanelNode(WorkbenchPanelId.editor),
          DockPanelNode(WorkbenchPanelId.preview),
          DockPanelNode(WorkbenchPanelId.inspector),
        ],
        ratios: const [0.32, 0.43, 0.25],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchCompositionShell(
          navbar: const SizedBox(),
          layoutController: controller,
          editor: const Text('editor'),
          viewport: const Text('preview'),
          inspector: const Text('inspector'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('dock-split-horizontal')), findsOneWidget);
    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scrollView.scrollDirection, Axis.horizontal);
    expect(find.text('editor'), findsOneWidget);
    expect(find.text('preview'), findsOneWidget);
    expect(find.text('inspector'), findsOneWidget);

    final divider = find.byKey(
      const ValueKey('dock-divider-handle-horizontal--0'),
    );
    expect(divider, findsOneWidget);
    await tester.drag(divider, const Offset(24, 0));
    await tester.pump();
    final resizedRoot = controller.dockedRoot! as DockSplitNode;
    expect(resizedRoot.ratios.first, greaterThan(0.32));

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
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
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('workbench-divider-visual-editor')),
          )
          .width,
      1,
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

  testWidgets('right splitter does not mutate the left panel ratio', (
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

    final leftBefore = controller.layout.splitRatios['left']!;
    await tester.drag(
      find.byKey(const ValueKey('workbench-divider-preview')),
      const Offset(60, 0),
    );
    await tester.pump();

    expect(controller.layout.splitRatios['left'], leftBefore);
    expect(controller.layout.splitRatios['center'], greaterThan(0.43));
  });

  testWidgets('interactive shell hides and restores a closed panel', (
    tester,
  ) async {
    final controller = WorkbenchLayoutController();
    controller.closePanel(WorkbenchPanelId.inspector);

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
    expect(find.text('INSPECTOR'), findsNothing);

    controller.togglePanel(WorkbenchPanelId.inspector);
    await tester.pump();
    expect(find.text('inspector'), findsOneWidget);
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
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('workbench-divider-visual-parameters')),
          )
          .height,
      1,
    );
    controller.resizeParameters(-70, 600);
    await tester.pump();
    expect(
      controller.panel(WorkbenchPanelId.parameters).bounds.height,
      greaterThan(220),
    );
    await tester.drag(
      find.byKey(const ValueKey('workbench-divider-parameters')),
      const Offset(0, 60),
    );
    expect(
      controller.panel(WorkbenchPanelId.parameters).bounds.height,
      lessThan(290),
    );
    controller.setPanelVisibility(
      WorkbenchPanelId.parameters,
      WorkbenchPanelVisibility.hidden,
    );
    await tester.pump();
    expect(find.text('parameters'), findsNothing);
  });

  testWidgets('parameters in the dock tree are rendered only once', (
    tester,
  ) async {
    final controller = WorkbenchLayoutController();
    final layout = controller.layout;
    controller.restore(
      layout,
      dockedRoot: DockSplitNode(
        axis: DockAxis.horizontal,
        children: const [
          DockPanelNode(WorkbenchPanelId.editor),
          DockPanelNode(WorkbenchPanelId.parameters),
        ],
        ratios: const [0.7, 0.3],
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
          parameters: const Text('parameters'),
        ),
      ),
    );

    expect(controller.dockedRoot, isNotNull);
    expect(find.text('parameters'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workbench-divider-parameters')),
      findsNothing,
    );
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
      find.byKey(const Key('resize-floating-workbench-panel')),
      findsOneWidget,
    );
    expect(find.text('inspector'), findsOneWidget);
    controller.moveFloatingPanel(WorkbenchPanelId.inspector, dx: 20, dy: 10);
    await tester.pump();
    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.left,
      44,
    );

    final floatingPanel = find.byKey(
      const ValueKey('floating-panel-inspector'),
    );
    expect(tester.widget<Material>(floatingPanel).elevation, 16);
    await tester.pump();
    await tester.tap(find.text('inspector'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('inspector'), findsOneWidget);

    controller.closePanel(WorkbenchPanelId.inspector);
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

  testWidgets('floating drag exposes a visible dock drop preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
          inspector: const WorkbenchPanelTitleBar(
            child: SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('inspector'),
              ),
            ),
          ),
        ),
      ),
    );

    final titleBar = find.byKey(
      const Key('floating-panel-titlebar-drag-region'),
    );
    expect(titleBar, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(titleBar));
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();

    expect(find.byKey(const ValueKey('dock-drop-preview')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('dock-drop-preview')), findsNothing);
    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.left,
      24,
    );
    expect(
      controller.panel(WorkbenchPanelId.inspector).visibility,
      WorkbenchPanelVisibility.visible,
    );
    expect(
      controller.panel(WorkbenchPanelId.inspector).placement,
      WorkbenchPanelPlacement.floating,
    );
    await gesture.up();
    await tester.pump();

    final redrag = await tester.startGesture(tester.getCenter(titleBar));
    await redrag.moveBy(const Offset(-30, 0));
    await redrag.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('dock-drop-preview')), findsOneWidget);
    await redrag.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('dock-drop-preview')), findsNothing);
    expect(controller.dockedRoot, isA<DockSplitNode>());
    expect(find.byKey(const ValueKey('dock-split-horizontal')), findsOneWidget);
  });

  testWidgets('invalid floating drop stays floating and preserves dock tree', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final standard = WorkbenchLayoutModel.standard();
    final controller = WorkbenchLayoutController(
      initialLayout: standard.copyWith(
        panels: {
          ...standard.panels,
          WorkbenchPanelId.editor: standard.panels[WorkbenchPanelId.editor]!
              .copyWith(
                bounds: const WorkbenchPanelBounds(width: 420, minWidth: 2000),
              ),
          WorkbenchPanelId.inspector: standard
              .panels[WorkbenchPanelId.inspector]!
              .copyWith(
                placement: WorkbenchPanelPlacement.floating,
                bounds: const WorkbenchPanelBounds(minWidth: 2000),
              ),
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
          inspector: const WorkbenchPanelTitleBar(
            child: SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('inspector'),
              ),
            ),
          ),
        ),
      ),
    );

    final initialRoot = DockLayoutAdapter.fromPlacementLayout(
      controller.layout,
    );
    final titleBar = find.byKey(
      const Key('floating-panel-titlebar-drag-region'),
    );
    final gesture = await tester.startGesture(tester.getCenter(titleBar));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();

    expect(controller.dropPreview, isNotNull);
    expect(controller.dropPreview!.isValid, isFalse);
    expect(find.byKey(const ValueKey('dock-drop-preview')), findsNothing);

    await gesture.up();
    await tester.pump();

    expect(
      controller.panel(WorkbenchPanelId.inspector).placement,
      WorkbenchPanelPlacement.floating,
    );
    expect(controller.dockedRoot, isNull);
    expect(
      DockLayoutAdapter.fromPlacementLayout(controller.layout),
      initialRoot,
    );
    expect(tester.takeException(), isNull);
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

    final afterKeyboard = controller.layout.splitRatios['left']!;
    final dividerSemanticsNode = tester.semantics.find(divider);
    dividerSemanticsNode.owner!.performAction(
      dividerSemanticsNode.id,
      ui.SemanticsAction.decrease,
    );
    await tester.pump();

    expect(controller.layout.splitRatios['left'], lessThan(afterKeyboard));
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

    final handle = find.byKey(const Key('resize-floating-workbench-panel'));
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

    final afterKeyboard =
        controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.width!;
    final semantics = tester.ensureSemantics();
    await tester.pump();
    final handleSemanticsNode = tester.semantics.find(
      find.bySemanticsLabel('Resize floating workbench panel'),
    );
    handleSemanticsNode.owner!.performAction(
      handleSemanticsNode.id,
      ui.SemanticsAction.decrease,
    );
    semantics.dispose();
    await tester.pump();

    expect(
      controller.layout.floatingBounds[WorkbenchPanelId.inspector]!.width,
      lessThan(afterKeyboard),
    );
  });

  testWidgets('floating panel remains visible after Escape', (tester) async {
    final standard = WorkbenchLayoutModel.standard();
    final controller = WorkbenchLayoutController(
      initialLayout: standard.copyWith(
        panels: {
          ...standard.panels,
          WorkbenchPanelId.inspector: standard
              .panels[WorkbenchPanelId.inspector]!
              .copyWith(placement: WorkbenchPanelPlacement.floating),
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

    await tester.tap(find.text('inspector'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(
      controller.panel(WorkbenchPanelId.inspector).visibility,
      WorkbenchPanelVisibility.visible,
    );
  });
}
