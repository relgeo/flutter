import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/main.dart';
import 'package:relgeo_flutter/src/ui/canvas_painter.dart';
import 'package:relgeo_flutter/src/ui/editor_panel.dart';
import 'package:relgeo_flutter/src/ui/inspector_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
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

    await tester.pumpWidget(const RelGeoCADApp());

    expect(find.text('DSL EDITOR'), findsOneWidget);
    expect(find.text('VIEWPORT'), findsOneWidget);
    expect(find.text('INSPECTOR'), findsOneWidget);
  });

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
    expect(find.byKey(const Key('physical-view-summary-badge')), findsOneWidget);
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

  testWidgets('workbench can switch back to model preview from surface selector', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const RelGeoCADApp(initialDsl: _sheetDsl));
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).sheetId, 'sheet_a4');
    expect(find.text('PHYSICAL PREVIEW · sheet_a4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sheet-option-model-preview')).last);
    await tester.pumpAndSettle();

    expect(_scenePainter(tester).sheetId, isNull);
    expect(find.text('MODEL PREVIEW'), findsOneWidget);
    expect(find.byKey(const Key('physical-target-badge')), findsNothing);
    expect(find.byKey(const Key('physical-view-summary-badge')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('export-svg-button')),
        matching: find.text('SVG MODEL'),
      ),
      findsOneWidget,
    );
  });

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

    expect(_scenePainter(tester).visualProfile.id, 'cad-dark');
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

      expect(_scenePainter(tester).visualProfile.id, 'blueprint');
      expect(_scenePainter(tester).overlay.showBoundingBoxes, isFalse);
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isTrue);

      await tester.tap(find.byKey(const Key('reset-workbench-preferences')));
      await tester.pumpAndSettle();

      expect(_scenePainter(tester).visualProfile.id, 'cad-dark');
      expect(_editorPanel(tester).visualProfile.id, 'cad-dark');
      expect(_inspectorPanel(tester).visualProfile.id, 'cad-dark');
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

      expect(_scenePainter(tester).visualProfile.id, 'cad-dark');
      expect(_scenePainter(tester).overlay.showLabels, isFalse);
      expect(
        _scenePainter(tester).hiddenRoles.contains('construction'),
        isTrue,
      );
      expect(_scenePainter(tester).hiddenRoles.contains('guide'), isFalse);
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
