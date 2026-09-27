import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/main.dart';
import 'package:relgeo_flutter/src/ui/cad_workbench.dart';
import 'package:relgeo_flutter/src/ui/workbench_file_service.dart';
import 'package:relgeo_flutter/src/ui/canvas_painter.dart';
import 'package:relgeo_flutter/src/features/editor/editor_panel.dart';
import 'package:relgeo_flutter/src/features/inspector/inspector_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/shared_fixture.dart';

const _sheetDsl = '''scene:
  unit: mm
  padding: 20

objects:
  panel:
    type: rect
    size: [120, 80]
    meta:
      role: final

  center_axis:
    type: line
    start: [60, -10]
    end: [60, 90]
    meta:
      role: centerline

  guide_axis:
    type: line
    start: [-10, 40]
    end: [130, 40]
    meta:
      role: guide

views:
  front:
    target: panel
    scale: "1:1"
    filter:
      roles: [final, centerline, guide]

sheets:
  sheet_a4:
    size: A4
    orientation: landscape
    views:
      - use: front
        place:
          topLeft: [20, 20]

  sheet_a3:
    size: A3
    orientation: landscape
    views:
      - use: front
        place:
          topLeft: [25, 25]
''';

class _FakeFileService implements WorkbenchDocumentFileService {
  int openCount = 0;
  int saveCount = 0;
  bool? lastSaveAs;
  String? lastCurrentPath;
  String? lastCurrentName;

  @override
  Future<String?> openDocument() async {
    openCount++;
    return _sheetDsl;
  }

  @override
  Future<WorkbenchDocumentFile?> openDocumentWithIdentity() async {
    openCount++;
    return const WorkbenchDocumentFile(
      source: _sheetDsl,
      path: '/documents/example.relgeo',
      name: 'example.relgeo',
    );
  }

  @override
  Future<bool> saveDocument(String source, {required bool saveAs}) async {
    saveCount++;
    lastSaveAs = saveAs;
    expect(source, contains('scene:'));
    return true;
  }

  @override
  Future<WorkbenchDocumentFile?> saveDocumentWithIdentity(
    String source, {
    required bool saveAs,
    String? currentPath,
    String? currentName,
  }) async {
    saveCount++;
    lastSaveAs = saveAs;
    lastCurrentPath = currentPath;
    lastCurrentName = currentName;
    expect(source, contains('scene:'));
    return WorkbenchDocumentFile(
      source: source,
      path: currentPath ?? '/documents/new.relgeo',
      name: currentName ?? 'new.relgeo',
    );
  }
}

void main() {
  final sharedFixturesAvailable = hasSharedFixtures();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.clearAllTestValues();
  });

  testWidgets('CAD Playground Smoke Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const RelGeoCADApp(showInWindowMenu: true));

    expect(find.byKey(const Key('workbench-menu-bar')), findsOneWidget);
    expect(find.text('DSL EDITOR'), findsOneWidget);
    expect(find.text('VIEWPORT'), findsOneWidget);
    expect(find.text('INSPECTOR'), findsOneWidget);

    await tester.tap(find.text('Workbench'));
    await tester.pumpAndSettle();
    expect(find.text('Overlay Inspector'), findsOneWidget);
    await tester.tap(find.text('Overlay Inspector'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close inspector overlay'), findsOneWidget);

    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(find.text('About RelGeo'), findsOneWidget);
  });

  testWidgets('file menu exposes explicit model and sheet SVG targets', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: CADWorkbenchPage(initialDsl: _sheetDsl)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    expect(find.text('Export'), findsOneWidget);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.text('SVG'), findsOneWidget);
    await tester.tap(find.text('SVG'));
    await tester.pumpAndSettle();
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Sheet / View'), findsOneWidget);
  });

  testWidgets('file menu exposes host document lifecycle callbacks', (
    WidgetTester tester,
  ) async {
    var saveAsCount = 0;
    var closeCount = 0;
    var quitCount = 0;

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CADWorkbenchPage(
          initialDsl: _sheetDsl,
          onSaveAsDocument: () => saveAsCount++,
          onCloseDocument: () => closeCount++,
          onQuitApplication: () => quitCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    expect(find.text('Save document as…'), findsOneWidget);
    expect(find.text('Close document'), findsOneWidget);
    expect(find.text('Quit RelGeo'), findsOneWidget);

    await tester.tap(find.text('Save document as…'));
    await tester.pump();
    expect(saveAsCount, 1);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close document'));
    await tester.pump();
    expect(closeCount, 1);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quit RelGeo'));
    await tester.pump();
    expect(quitCount, 1);
  });

  testWidgets('dirty lifecycle asks before destructive document actions', (
    WidgetTester tester,
  ) async {
    var allowDiscard = false;
    var confirmCount = 0;
    var closeCount = 0;

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CADWorkbenchPage(
          initialDsl: _sheetDsl,
          onCloseDocument: () => closeCount++,
          onConfirmDiscardChanges: () async {
            confirmCount++;
            return allowDiscard;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor = _editorPanel(tester).controller;
    editor.text = '${editor.text}\n# unsaved';
    await tester.pump();

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close document'));
    await tester.pumpAndSettle();
    expect(confirmCount, 1);
    expect(closeCount, 0);

    allowDiscard = true;
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close document'));
    await tester.pumpAndSettle();
    expect(confirmCount, 2);
    expect(closeCount, 1);
  });

  testWidgets('edit menu reflects and invokes native editor history', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: CADWorkbenchPage(initialDsl: _sheetDsl)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final initialUndo = tester.widget<MenuItemButton>(
      find.widgetWithText(MenuItemButton, 'Undo'),
    );
    expect(initialUndo.onPressed, isNull);
    await tester.tapAt(const Offset(600, 600));

    final editor = _editorPanel(tester).controller;
    editor.text = '${editor.text}\n# edit';
    await tester.pump();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final undo = tester.widget<MenuItemButton>(
      find.widgetWithText(MenuItemButton, 'Undo'),
    );
    expect(undo.onPressed, isNotNull);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(editor.text.toString(), _sheetDsl);
  });

  testWidgets('file service powers open and save commands', (
    WidgetTester tester,
  ) async {
    final service = _FakeFileService();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CADWorkbenchPage(initialDsl: _sheetDsl, fileService: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save document'));
    await tester.pumpAndSettle();
    expect(service.saveCount, 1);
    expect(service.lastSaveAs, isFalse);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save document as…'));
    await tester.pumpAndSettle();
    expect(service.saveCount, 2);
    expect(service.lastSaveAs, isTrue);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open document…'));
    await tester.pumpAndSettle();
    expect(service.openCount, 1);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save document'));
    await tester.pumpAndSettle();
    expect(service.saveCount, 3);
    expect(service.lastCurrentPath, '/documents/example.relgeo');
    expect(service.lastCurrentName, 'example.relgeo');
  });

  testWidgets('file service enables a guarded local new document fallback', (
    WidgetTester tester,
  ) async {
    final service = _FakeFileService();
    await tester.pumpWidget(
      MaterialApp(
        home: CADWorkbenchPage(initialDsl: _sheetDsl, fileService: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    expect(find.text('New document'), findsOneWidget);

    await tester.tap(find.text('New document'));
    await tester.pumpAndSettle();

    expect(find.textContaining('# New RelGeo document'), findsOneWidget);
    expect(find.textContaining('scene:'), findsOneWidget);
  });

  testWidgets(
    'typed host save acknowledgement clears dirty state and identity',
    (WidgetTester tester) async {
      final requests = <WorkbenchDocumentSaveRequest>[];
      final dirtyStates = <bool>[];

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: CADWorkbenchPage(
            initialDsl: _sheetDsl,
            onSaveDocumentWithResult: (request) async {
              requests.add(request);
              return WorkbenchDocumentSaveResult(
                saved: true,
                path: request.saveAs
                    ? '/documents/renamed.relgeo'
                    : '/documents/saved.relgeo',
                name: request.saveAs ? 'renamed.relgeo' : 'saved.relgeo',
              );
            },
            onDocumentDirtyChanged: dirtyStates.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editor = _editorPanel(tester).controller;
      editor.text = '${editor.text}\n# typed save';
      await tester.pump();

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save document'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.single.saveAs, isFalse);
      expect(requests.single.source, contains('# typed save'));
      expect(requests.single.currentPath, isNull);
      expect(requests.single.currentName, isNull);
      expect(dirtyStates, containsAllInOrder(<bool>[true, false]));

      editor.text = '${editor.text}\n# typed save as';
      await tester.pump();
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save document as…'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(2));
      expect(requests.last.saveAs, isTrue);
      expect(requests.last.currentPath, '/documents/saved.relgeo');
      expect(requests.last.currentName, 'saved.relgeo');
      expect(dirtyStates.last, isFalse);
    },
  );

  testWidgets('theme mode follows system until explicitly overridden', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;

    await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    expect(
      Theme.of(tester.element(find.text('DSL EDITOR'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const Key('theme-mode-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-mode-option-dark')).last);
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.byKey(const Key('theme-mode-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-mode-option-light')).last);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('DSL EDITOR'))).brightness,
      Brightness.light,
    );

    await tester.tap(find.byKey(const Key('theme-mode-reset')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
  });

  testWidgets('theme selector exposes semantic state', (
    WidgetTester tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RelGeoCADApp());
    await tester.pumpAndSettle();

    final node = tester.getSemantics(
      find.byKey(const Key('theme-mode-semantics')),
    );
    expect(node.label, contains('Theme mode'));
    expect(node.value, contains('System'));
    expect(node.hint, contains('Choose Light or Dark'));
    semanticsHandle.dispose();
  });

  testWidgets('workbench controls expose semantic state', (
    WidgetTester tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const RelGeoCADApp());
    await tester.pumpAndSettle();

    final profileNode = tester.getSemantics(
      find.byKey(const Key('workbench-profile-semantics')),
    );
    expect(profileNode.label, contains('Canvas appearance'));
    expect(profileNode.value, contains('CAD'));
    expect(profileNode.hint, contains('Choose a canvas appearance preset'));
    semanticsHandle.dispose();
    tester.view.reset();
  });

  testWidgets('custom controls expose keyboard activation bindings', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RelGeoCADApp());
    await tester.pumpAndSettle();

    final detectors = tester
        .widgetList<FocusableActionDetector>(
          find.byType(FocusableActionDetector),
        )
        .toList();
    final keyboardDetectors = detectors
        .where(
          (detector) => detector.actions?.containsKey(ActivateIntent) ?? false,
        )
        .toList();

    expect(keyboardDetectors.length, greaterThanOrEqualTo(3));
    for (final detector in keyboardDetectors) {
      expect(
        detector.shortcuts?.values.any((intent) => intent is ActivateIntent),
        isTrue,
      );
      expect(
        detector.actions,
        containsPair(ActivateIntent, isA<Action<Intent>>()),
      );
    }
  });

  testWidgets('custom controls participate in keyboard focus traversal', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RelGeoCADApp());
    await tester.pumpAndSettle();

    final customControlCount = find
        .byType(FocusableActionDetector)
        .evaluate()
        .length;
    expect(customControlCount, greaterThanOrEqualTo(3));

    var reachedCustomControl = false;
    for (var attempt = 0; attempt < 32 && !reachedCustomControl; attempt++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (focusContext == null) continue;

      focusContext.visitAncestorElements((element) {
        if (element.widget is FocusableActionDetector) {
          reachedCustomControl = true;
          return false;
        }
        return true;
      });
    }

    expect(reachedCustomControl, isTrue);
  });

  testWidgets(
    'active v0.5 fixture flows through workbench surfaces',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        RelGeoCADApp(
          initialDsl: loadSharedFixtureText('10-v05-relational-baseline.yaml'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMPILED OK'), findsOneWidget);
      expect(find.text('MODEL PREVIEW'), findsOneWidget);
      expect(find.byKey(const Key('scene-canvas')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('export-svg-button')),
          matching: find.text('SVG MODEL'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('ERRORS'));
      await tester.pumpAndSettle();
      expect(find.text('COMPILATION SUCCESSFUL'), findsOneWidget);
    },
    skip: !sharedFixturesAvailable,
  );

  testWidgets(
    'runtime diagnostic remains visible in the workbench inspector',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        RelGeoCADApp(
          initialDsl: loadSharedFixtureText(
            '14-v05-runtime-align-violation.yaml',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMPILED OK'), findsOneWidget);
      expect(find.byKey(const Key('scene-canvas')), findsOneWidget);

      await tester.tap(find.text('ERRORS'));
      await tester.pumpAndSettle();
      expect(
        find.text('Points are not aligned. Distance: 14.1421'),
        findsOneWidget,
      );
    },
    skip: !sharedFixturesAvailable,
  );

  testWidgets(
    'invalid edits keep the last valid preview while showing diagnostics',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        RelGeoCADApp(
          initialDsl: loadSharedFixtureText('10-v05-relational-baseline.yaml'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scene-canvas')), findsOneWidget);
      final controller = _editorPanel(tester).controller;
      controller.text =
          'version: 0.5\nobjects:\n  broken:\n    type: definitely-not-a-relgeo-object';
      controller.notifyListeners();
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('ERROR'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('scene-canvas')), findsOneWidget);

      await tester.tap(find.text('ERRORS'));
      await tester.pumpAndSettle();
      expect(find.text('COMPILER / TOPOLOGY ERROR'), findsOneWidget);
    },
    skip: !sharedFixturesAvailable,
  );

  testWidgets('workbench can switch active sheet from sheet selector', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sheet-selector')), findsOneWidget);
    expect(_scenePainter(tester).sheetId, 'sheet_a4');
    expect(find.byKey(const Key('preview-surface-badge')), findsOneWidget);
    expect(find.text('PHYSICAL PREVIEW · sheet_a4'), findsOneWidget);
    expect(find.byKey(const Key('physical-target-badge')), findsOneWidget);
    expect(
      find.byKey(const Key('physical-view-summary-badge')),
      findsOneWidget,
    );
    expect(
      find.text('TARGET: A4 · 297.0 × 210.0 MM · LANDSCAPE'),
      findsOneWidget,
    );
    expect(find.text('VIEWS: 1 · SCALE: 1:1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('export-svg-button')),
        matching: find.text('SVG SHEET'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('297.0, 210.0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sheet-option-sheet_a3')).last);
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).sheetId, 'sheet_a3');
    expect(find.text('PHYSICAL PREVIEW · sheet_a3'), findsOneWidget);
    expect(
      find.text('TARGET: A3 · 420.0 × 297.0 MM · LANDSCAPE'),
      findsOneWidget,
    );
    expect(find.text('VIEWS: 1 · SCALE: 1:1'), findsOneWidget);
    expect(find.textContaining('420.0, 297.0'), findsOneWidget);
  });

  testWidgets(
    'workbench can switch back to model preview from surface selector',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).sheetId, 'sheet_a4');
      expect(find.text('PHYSICAL PREVIEW · sheet_a4'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sheet-selector')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('sheet-option-model-preview')).last,
      );
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).sheetId, isNull);
      expect(find.text('MODEL PREVIEW'), findsOneWidget);
      expect(find.byKey(const Key('physical-target-badge')), findsNothing);
      expect(
        find.byKey(const Key('physical-view-summary-badge')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('export-svg-button')),
          matching: find.text('SVG MODEL'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('role filter updates hidden roles used by canvas painter', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);

    await tester.tap(find.byKey(const Key('role-toggle-guide')));
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);

    await tester.tap(find.byKey(const Key('role-toggle-guide')));
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);
  });

  testWidgets(
    'role filter continues to affect canvas painter while sheet mode is active',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).sheetId, 'sheet_a4');
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);

      await tester.tap(find.byKey(const Key('role-toggle-guide')));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).sheetId, 'sheet_a4');
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);
    },
  );

  testWidgets('workbench can switch visual profile for preview canvas', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).visualProfile.id, 'cad');
    expect(_scenePainter(tester).overlay.showLabels, isFalse);
    expect(_scenePainter(tester).overlay.showBoundingBoxes, isFalse);
    expect(_scenePainter(tester).hiddenRoles.contains('construction'), isTrue);
    expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);
    expect(
      find.descendant(
        of: find.byKey(const Key('overlay-status-badge')),
        matching: find.text('Preset Active'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('role-status-badge')),
        matching: find.text('Preset Active'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('workbench-profile-selector')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('workbench-profile-option-blueprint')).last,
    );
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).visualProfile.id, 'blueprint');
    expect(_editorPanel(tester).visualProfile.id, 'blueprint');
    expect(_inspectorPanel(tester).visualProfile.id, 'blueprint');
    expect(_scenePainter(tester).overlay.showLabels, isTrue);
    expect(_scenePainter(tester).overlay.showBoundingBoxes, isTrue);
    expect(_scenePainter(tester).hiddenRoles.contains('construction'), isFalse);

    await tester.tap(find.byKey(const Key('workbench-profile-selector')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('workbench-profile-option-paper')).last,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).visualProfile.id, 'paper');
    expect(_scenePainter(tester).hiddenRoles.contains('construction'), isTrue);
    expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);
    expect(_scenePainter(tester).hiddenRoles.contains('hidden'), isTrue);
  });

  testWidgets(
    'manual overlay override survives profile switch until overlay sync is re-enabled',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).overlay.showLabels, isFalse);
      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).overlay.showLabels, isTrue);
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);
      expect(
        find.descendant(
          of: find.byKey(const Key('overlay-status-badge')),
          matching: find.text('Locally Overridden'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('workbench-profile-selector')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('workbench-profile-option-paper')).last,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).visualProfile.id, 'paper');
      expect(_scenePainter(tester).overlay.showLabels, isTrue);
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);

      await tester.tap(find.byKey(const Key('overlay-sync-toggle')));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).overlay.showLabels, isFalse);
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);
      expect(
        find.descendant(
          of: find.byKey(const Key('overlay-status-badge')),
          matching: find.text('Preset Active'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'manual role filter override survives profile switch until role sync is re-enabled',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);
      expect(_scenePainter(tester).overlay.showLabels, isFalse);

      await tester.tap(find.byKey(const Key('role-toggle-guide')));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);
      expect(_scenePainter(tester).overlay.showLabels, isFalse);
      expect(
        find.descendant(
          of: find.byKey(const Key('role-status-badge')),
          matching: find.text('Locally Overridden'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('workbench-profile-selector')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('workbench-profile-option-blueprint')).last,
      );
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).visualProfile.id, 'blueprint');
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);
      expect(_scenePainter(tester).overlay.showLabels, isTrue);

      await tester.tap(find.byKey(const Key('role-filter-sync-toggle')));
      await tester.pumpAndSettle();

      expect(
        _scenePainter(tester).hiddenRoles.contains('construction'),
        isFalse,
      );
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);
      expect(_scenePainter(tester).overlay.showLabels, isTrue);
      expect(
        find.descendant(
          of: find.byKey(const Key('role-status-badge')),
          matching: find.text('Preset Active'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    're-enabling both sync channels restores both overlay and role presets',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('role-toggle-guide')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('workbench-profile-selector')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('workbench-profile-option-paper')).last,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('overlay-sync-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-filter-sync-toggle')));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).overlay.showLabels, isFalse);
      expect(
        _scenePainter(tester).hiddenRoles.contains('construction'),
        isTrue,
      );
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);
      expect(_scenePainter(tester).hiddenRoles.contains('hidden'), isTrue);
    },
  );

  testWidgets('workbench restores persisted profile and behavior on relaunch', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('workbench-profile-selector')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('workbench-profile-option-blueprint')).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('role-toggle-guide')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BBox'));
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).visualProfile.id, 'blueprint');
    expect(_scenePainter(tester).overlay.showBoundingBoxes, isFalse);
    expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).visualProfile.id, 'blueprint');
    expect(_editorPanel(tester).visualProfile.id, 'blueprint');
    expect(_inspectorPanel(tester).visualProfile.id, 'blueprint');
    expect(_scenePainter(tester).overlay.showBoundingBoxes, isFalse);
    expect(_scenePainter(tester).overlay.showLabels, isTrue);
    expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('overlay-status-badge')),
        matching: find.text('Locally Overridden'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('role-status-badge')),
        matching: find.text('Locally Overridden'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'reset workbench preferences restores defaults and clears persisted state',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('workbench-profile-selector')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('workbench-profile-option-blueprint')).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-toggle-guide')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BBox'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collapse Preview'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workbench-panel-preview')), findsNothing);

      await tester.tap(find.text('Workbench'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset workbench preferences'));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).visualProfile.id, 'cad');
      expect(_editorPanel(tester).visualProfile.id, 'cad');
      expect(_inspectorPanel(tester).visualProfile.id, 'cad');
      expect(_scenePainter(tester).overlay.showLabels, isFalse);
      expect(_scenePainter(tester).overlay.showBoundingBoxes, isFalse);
      expect(
        _scenePainter(tester).hiddenRoles.contains('construction'),
        isTrue,
      );
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);
      expect(
        find.descendant(
          of: find.byKey(const Key('overlay-status-badge')),
          matching: find.text('Preset Active'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('role-status-badge')),
          matching: find.text('Preset Active'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).visualProfile.id, 'cad');
      expect(_scenePainter(tester).overlay.showLabels, isFalse);
      expect(
        _scenePainter(tester).hiddenRoles.contains('construction'),
        isTrue,
      );
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);
    },
  );

  testWidgets(
    'full workbench renders cleanly in light and dark system themes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            brightness;

        await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('DSL EDITOR'), findsOneWidget);
        expect(find.text('VIEWPORT'), findsOneWidget);
        expect(find.text('INSPECTOR'), findsOneWidget);
        expect(
          Theme.of(tester.element(find.text('DSL EDITOR'))).brightness,
          brightness,
        );
      }
    },
  );
}

CanvasPainter _scenePainter(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.byKey(const Key('scene-canvas')),
  );
  return customPaint.painter! as CanvasPainter;
}

EditorPanel _editorPanel(WidgetTester tester) {
  return tester.widget<EditorPanel>(find.byType(EditorPanel));
}

InspectorPanel _inspectorPanel(WidgetTester tester) {
  return tester.widget<InspectorPanel>(find.byType(InspectorPanel));
}
