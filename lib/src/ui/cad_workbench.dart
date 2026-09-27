import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'workbench_preferences.dart';
import 'workbench_preferences_controller.dart';
import 'workbench_svg_export_controller.dart';
import 'relgeo_theme_extension.dart';
import 'workbench_visual_profile.dart';
import 'workbench_overlay_controller.dart';
import 'workbench_composition_shell.dart';
import 'workbench_document_controller.dart';
import 'workbench_editor_controller.dart';
import 'workbench_document_session.dart';
import '../features/workbench_feature_surfaces.dart';
import 'workbench_navbar.dart';
import 'workbench_commands.dart';
import 'workbench_menu_bar.dart';
import 'workbench_platform_menu_bar.dart';
import 'workbench_viewport_controller.dart';
import 'workbench_layout_controller.dart';
import 'workbench_layout_model.dart';
import 'workbench_layout_persistence.dart';
import 'workbench_layout_profiles.dart';

class CADWorkbenchPage extends StatefulWidget {
  const CADWorkbenchPage({
    super.key,
    this.initialDsl,
    this.themePreference,
    this.showInWindowMenu,
    this.onNewDocument,
    this.onOpenDocument,
    this.onSaveDocument,
    this.onSaveAsDocument,
    this.onSaveDocumentWithResult,
    this.onCloseDocument,
    this.onQuitApplication,
    this.onConfirmDiscardChanges,
    this.onDocumentDirtyChanged,
    this.fileService,
    this.onThemePreferenceChanged,
    this.onResetThemePreference,
    this.workbenchProfileId = 'cad',
    this.onWorkbenchProfileChanged,
    this.onResetWorkbenchPreferences,
  });

  final String? initialDsl;
  final RelGeoThemePreference? themePreference;
  final bool? showInWindowMenu;
  final VoidCallback? onNewDocument;
  final VoidCallback? onOpenDocument;
  final VoidCallback? onSaveDocument;
  final VoidCallback? onSaveAsDocument;
  final WorkbenchDocumentSaveHandler? onSaveDocumentWithResult;
  final VoidCallback? onCloseDocument;
  final VoidCallback? onQuitApplication;
  final Future<bool> Function()? onConfirmDiscardChanges;
  final ValueChanged<bool>? onDocumentDirtyChanged;
  final WorkbenchFileService? fileService;
  final ValueChanged<RelGeoThemePreference>? onThemePreferenceChanged;
  final VoidCallback? onResetThemePreference;
  final String workbenchProfileId;
  final ValueChanged<String>? onWorkbenchProfileChanged;
  final Future<void> Function()? onResetWorkbenchPreferences;

  @override
  State<CADWorkbenchPage> createState() => _CADWorkbenchPageState();
}

class _CADWorkbenchPageState extends State<CADWorkbenchPage> {
  late final WorkbenchEditorController _editorController;
  late final WorkbenchDocumentSession _documentSession;

  // Compile state
  final WorkbenchDocumentController _documentController =
      WorkbenchDocumentController();

  // Temporary compatibility façade while the remaining page composition is
  // being decomposed. The source of truth is the document controller.
  String? get _yamlError => _documentController.yamlError;
  set _yamlError(String? value) => _documentController.setYamlError(value);
  String? get _compilerError => _documentController.compilerError;
  set _compilerError(String? value) =>
      _documentController.setCompilerError(value);
  ResolvedScene? get _scene => _documentController.scene;
  set _scene(ResolvedScene? value) => _documentController.setScene(value);
  Map<String, double> get _paramValues => _documentController.paramValues;
  set _paramValues(Map<String, double> value) =>
      _documentController.setParamValues(value);
  Map<String, dynamic> get _paramOverrides =>
      _documentController.paramOverrides;
  set _paramOverrides(Map<String, dynamic> value) =>
      _documentController.setParamOverrides(value);
  Map<String, Map<String, dynamic>> get _profiles =>
      _documentController.profiles;
  set _profiles(Map<String, Map<String, dynamic>> value) =>
      _documentController.setProfiles(value);
  String? get _activeProfile => _documentController.activeProfile;
  set _activeProfile(String? value) =>
      _documentController.setActiveProfile(value);
  String? get _selectedSheetId => _documentController.selectedSheetId;
  set _selectedSheetId(String? value) =>
      _documentController.setSelectedSheetId(value);
  LengthUnit get _targetUnit => _documentController.targetUnit;
  set _targetUnit(LengthUnit value) => _documentController.setTargetUnit(value);

  // Viewport navigation
  final WorkbenchViewportController _viewportController =
      WorkbenchViewportController();

  // Overlay state boundary
  final WorkbenchOverlayController _overlayController =
      WorkbenchOverlayController();
  final WorkbenchPreferencesController _preferencesController =
      WorkbenchPreferencesController();
  final WorkbenchSvgExportController _svgExportController =
      WorkbenchSvgExportController();
  final WorkbenchLayoutController _layoutController =
      WorkbenchLayoutController();
  final WorkbenchLayoutPersistenceController _layoutPersistenceController =
      WorkbenchLayoutPersistenceController();

  String? _documentPath;
  String? _documentName;

  Future<void> _openDocumentFromFileService() async {
    if (!await _confirmDiscardChangesIfNeeded()) return;
    final service = widget.fileService;
    if (service == null) return;

    if (service is WorkbenchDocumentFileService) {
      final document = await service.openDocumentWithIdentity();
      if (!mounted || document == null) return;
      _documentPath = document.path;
      _documentName = document.name;
      _documentSession.markLoaded(
        source: document.source,
        path: document.path,
        name: document.name,
      );
      _editorController.editingController.text = document.source;
      _compileDSL(document.source);
      return;
    }

    final source = await service.openDocument();
    if (!mounted || source == null) return;
    _documentPath = null;
    _documentName = null;
    _documentSession.markLoaded(source: source);
    _editorController.editingController.text = source;
    _compileDSL(source);
  }

  Future<void> _saveDocumentToFileService({required bool saveAs}) async {
    final service = widget.fileService;
    if (service == null) return;
    if (service is WorkbenchDocumentFileService) {
      final saved = await service.saveDocumentWithIdentity(
        _editorController.text,
        saveAs: saveAs,
        currentPath: _documentPath,
        currentName: _documentName,
      );
      if (saved != null) {
        _documentPath = saved.path;
        _documentName = saved.name;
        _documentSession.markSaved(
          source: saved.source,
          path: saved.path,
          name: saved.name,
        );
      }
      return;
    }

    final saved = await service.saveDocument(
      _editorController.text,
      saveAs: saveAs,
    );
    if (saved) {
      _documentSession.markSaved(
        source: _editorController.text,
        path: _documentPath,
        name: _documentName,
      );
    }
  }

  Future<void> _saveDocumentWithHostResult({required bool saveAs}) async {
    final handler = widget.onSaveDocumentWithResult;
    if (handler == null) return;
    final result = await handler(
      WorkbenchDocumentSaveRequest(
        source: _editorController.text,
        saveAs: saveAs,
        currentPath: _documentPath,
        currentName: _documentName,
      ),
    );
    if (!result.saved) return;
    _documentPath = result.path ?? _documentPath;
    _documentName = result.name ?? _documentName;
    _documentSession.markSaved(
      source: _editorController.text,
      path: _documentPath,
      name: _documentName,
    );
  }

  WorkbenchVisualProfile get _workbenchProfile =>
      WorkbenchVisualProfile.byId(widget.workbenchProfileId);

  Size get _fallbackViewportSize => Size(
    MediaQuery.of(context).size.width * 0.43,
    MediaQuery.of(context).size.height * 0.7,
  );

  ResolvedSheet? get _activeSheet => _scene != null && _selectedSheetId != null
      ? _scene!.sheets[_selectedSheetId!]
      : null;

  String _formatLength(double value) => value.toStringAsFixed(1);

  String get _activeSheetOrientation {
    final sheet = _activeSheet;
    if (sheet == null) return '';
    return sheet.width >= sheet.height ? 'LANDSCAPE' : 'PORTRAIT';
  }

  String get _activeSheetSizeLabel {
    final sheet = _activeSheet;
    if (sheet == null) return '';
    return (sheet.meta?.extra['sheetSize'] ??
            (sheet.size is String ? sheet.size : 'Custom'))
        .toString();
  }

  String get _activeSheetPhysicalTargetLabel {
    final sheet = _activeSheet;
    if (sheet == null) return '';
    return 'TARGET: $_activeSheetSizeLabel · '
        '${_formatLength(sheet.width)} × ${_formatLength(sheet.height)} '
        '${_targetUnit.name.toUpperCase()} · $_activeSheetOrientation';
  }

  String get _activeSheetViewSummaryLabel {
    final sheet = _activeSheet;
    final scene = _scene;
    if (sheet == null || scene == null) return '';

    final scaleLabels = <String>[];
    for (final placement in sheet.views) {
      final view = scene.views[placement.use];
      scaleLabels.add((view?.scale ?? '1:1').toString());
    }

    final uniqueScales = <String>[];
    for (final scale in scaleLabels) {
      if (!uniqueScales.contains(scale)) uniqueScales.add(scale);
    }

    final scalePart = uniqueScales.length == 1
        ? 'SCALE: ${uniqueScales.first}'
        : 'SCALES: ${uniqueScales.join(', ')}';

    return 'VIEWS: ${sheet.views.length} · $scalePart';
  }

  OverlayOptions _overlayFromProfile(WorkbenchVisualProfile profile) {
    return OverlayOptions(
      showAnchors: profile.behavior.showAnchors,
      showLabels: profile.behavior.showLabels,
      showBoundingBoxes: profile.behavior.showBoundingBoxes,
    );
  }

  Set<String> _hiddenRolesFromProfile(WorkbenchVisualProfile profile) {
    return Set<String>.from(profile.behavior.hiddenRoles);
  }

  void _applyBehaviorPreset(
    WorkbenchVisualProfile profile, {
    bool includeOverlay = true,
    bool includeRoleFilter = true,
  }) {
    _overlayController.applyProfile(
      overlay: _overlayFromProfile(profile),
      hiddenRoles: _hiddenRolesFromProfile(profile),
      includeOverlay: includeOverlay,
      includeRoleFilter: includeRoleFilter,
    );
  }

  Future<void> _persistWorkbenchPreferences() async {
    await _preferencesController.persist(
      workbenchProfileId: widget.workbenchProfileId,
      followProfileOverlay: _overlayController.followProfileOverlay,
      followProfileRoleFilter: _overlayController.followProfileRoleFilter,
      showAnchors: _overlayController.overlay.showAnchors,
      showLabels: _overlayController.overlay.showLabels,
      showBoundingBoxes: _overlayController.overlay.showBoundingBoxes,
      hiddenRoles: _overlayController.hiddenRoles,
    );
  }

  Future<void> _resetWorkbenchPreferences() async {
    const defaults = WorkbenchPreferencesData.defaults;
    await widget.onResetWorkbenchPreferences?.call();
    if (!mounted) return;

    _layoutController.reset();

    _overlayController.restore(
      overlay: const OverlayOptions(
        showAnchors: false,
        showLabels: false,
        showBoundingBoxes: false,
      ),
      hiddenRoles: defaults.hiddenRoles,
      followProfileOverlay: defaults.followProfileOverlay,
      followProfileRoleFilter: defaults.followProfileRoleFilter,
    );

    if (widget.onWorkbenchProfileChanged != null &&
        widget.workbenchProfileId != defaults.workbenchProfileId) {
      widget.onWorkbenchProfileChanged!(defaults.workbenchProfileId);
    } else {
      await _persistWorkbenchPreferences();
    }
  }

  void _resetDocumentParameters() {
    if (_paramValues.isEmpty) return;
    _documentController.clearParamOverrides();
    _compileDSL(_editorController.text);
  }

  void _copySourceToClipboard() {
    Clipboard.setData(ClipboardData(text: _editorController.text));
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'RelGeo',
      applicationVersion: 'DSL 0.5',
      applicationLegalese: 'Relation-first vector authoring',
    );
  }

  void _setFollowProfileOverlay(bool value) {
    _overlayController.setFollowProfileOverlay(
      value,
      profileOverlay: _overlayFromProfile(_workbenchProfile),
    );
    _persistWorkbenchPreferences();
  }

  void _setFollowProfileRoleFilter(bool value) {
    _overlayController.setFollowProfileRoleFilter(
      value,
      profileHiddenRoles: _hiddenRolesFromProfile(_workbenchProfile),
    );
    _persistWorkbenchPreferences();
  }

  void _setOverlayManual(OverlayOptions overlay) {
    _overlayController.setOverlayManual(overlay);
    _persistWorkbenchPreferences();
  }

  void _setHiddenRolesManual(Set<String> hiddenRoles) {
    _overlayController.setHiddenRolesManual(hiddenRoles);
    _persistWorkbenchPreferences();
  }

  BoundingBox? get _displayBounds {
    if (_scene == null) return null;
    if (_selectedSheetId != null &&
        _scene!.sheets.containsKey(_selectedSheetId)) {
      final sheet = _scene!.sheets[_selectedSheetId]!;
      return BoundingBox(x: 0, y: 0, width: sheet.width, height: sheet.height);
    }
    return _scene!.bbox;
  }

  // Default starter DSL
  static const String _defaultDSL = '''# RelGeo CAD Workbench v0.5
scene:
  unit: mm
  padding: 20

parameters:
  lebar: 120
  tinggi: 80
  lubang_r: 18

derived:
  cx: lebar / 2
  cy: tinggi / 2

objects:
  plat:
    type: rect
    size: [lebar, tinggi]
    meta:
      role: final
      fill: "#1e293b"
      stroke: "#00FFCC"

  c_lubang:
    type: circle
    center: [cx, cy]
    radius: lubang_r
    meta:
      role: centerline
      stroke: "#F43F5E"

  sub_lubang:
    type: boolean
    operation: subtract
    shapes: [plat, c_lubang]
    meta:
      role: final
      fill: "#1e293b"
      stroke: "#00FFCC"

  as_horizontal:
    type: line
    start: [-20, cy]
    end: [lebar + 20, cy]
    meta:
      role: centerline

  as_vertical:
    type: line
    start: [cx, -20]
    end: [cx, tinggi + 20]
    meta:
      role: centerline

  dim_lebar:
    type: dimension
    kind: linear
    from: plat.topLeft
    to: plat.topRight
    offset: -30
    text: "L = \${lebar} mm"
    meta:
      role: dimension

  dim_tinggi:
    type: dimension
    kind: linear
    from: plat.topLeft
    to: plat.bottomLeft
    offset: -35
    text: "H = \${tinggi} mm"
    meta:
      role: dimension
''';

  @override
  void initState() {
    super.initState();
    final initialDsl = widget.initialDsl ?? _defaultDSL;
    _documentSession = WorkbenchDocumentSession(initialSource: initialDsl);
    _documentSession.addListener(_onDocumentSessionChanged);
    _editorController = WorkbenchEditorController.fromText(initialDsl);
    _editorController.addListener(_onCodeChanged);
    _viewportController.addListener(() {
      if (mounted) setState(() {});
    });
    _overlayController.addListener(() {
      if (mounted) setState(() {});
    });
    _documentController.addListener(() {
      if (mounted) setState(() {});
    });
    _layoutController.addListener(_onLayoutChanged);
    _applyBehaviorPreset(_workbenchProfile);
    _loadWorkbenchPreferences(initialDsl);
    _loadLayoutPreferences();
  }

  Future<void> _loadWorkbenchPreferences(String initialDsl) async {
    final saved = await _preferencesController.load();
    if (!mounted || saved == null) {
      _compileDSL(initialDsl);
      return;
    }

    _overlayController.restore(
      overlay: OverlayOptions(
        showAnchors: saved.showAnchors,
        showLabels: saved.showLabels,
        showBoundingBoxes: saved.showBoundingBoxes,
      ),
      hiddenRoles: saved.hiddenRoles,
      followProfileOverlay: saved.followProfileOverlay,
      followProfileRoleFilter: saved.followProfileRoleFilter,
    );
    _compileDSL(initialDsl);
  }

  Future<void> _loadLayoutPreferences() async {
    final saved = await _layoutPersistenceController.load();
    if (!mounted || saved == null) return;
    _layoutController.restore(saved);
  }

  @override
  void didUpdateWidget(covariant CADWorkbenchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workbenchProfileId != widget.workbenchProfileId) {
      if (_overlayController.followProfileOverlay ||
          _overlayController.followProfileRoleFilter) {
        _applyBehaviorPreset(
          _workbenchProfile,
          includeOverlay: _overlayController.followProfileOverlay,
          includeRoleFilter: _overlayController.followProfileRoleFilter,
        );
      }
      _persistWorkbenchPreferences();
    }
  }

  @override
  void dispose() {
    _documentSession.removeListener(_onDocumentSessionChanged);
    _documentSession.dispose();
    _layoutController.removeListener(_onLayoutChanged);
    unawaited(_layoutPersistenceController.flush());
    _layoutPersistenceController.dispose();
    _layoutController.dispose();
    _editorController.dispose();
    _viewportController.dispose();
    _overlayController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  void _onLayoutChanged() {
    _layoutPersistenceController.scheduleSave(_layoutController.layout);
    if (mounted) setState(() {});
  }

  void _onDocumentSessionChanged() {
    widget.onDocumentDirtyChanged?.call(_documentSession.isDirty);
  }

  Future<bool> _confirmDiscardChangesIfNeeded() async {
    if (!_documentSession.isDirty) return true;
    final confirm = widget.onConfirmDiscardChanges;
    if (confirm == null) return false;
    return await confirm();
  }

  Future<void> _runLifecycleAction(VoidCallback? action) async {
    if (action == null || !await _confirmDiscardChangesIfNeeded()) return;
    action();
  }

  void _applyLayoutProfile(WorkbenchLayoutProfile profile) {
    _layoutController.applyProfile(profile);
  }

  void _onCodeChanged() {
    _documentSession.updateSource(_editorController.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _compileDSL(_editorController.text);
      }
    });
  }

  void _compileDSL(String code) {
    try {
      setState(() {
        _yamlError = null;
        _compilerError = null;
      });

      final doc = loadYaml(code);
      if (doc is! Map) {
        throw Exception('YAML format must represent a Map structure.');
      }

      final documentSettings = WorkbenchDocumentSettings.fromDocument(
        doc,
        existingParamOverrides: _paramOverrides,
        currentTargetUnit: _targetUnit,
      );
      _profiles = documentSettings.profiles;
      if (_activeProfile != null && !_profiles.containsKey(_activeProfile)) {
        _activeProfile = null;
      }
      _paramValues = documentSettings.paramValues;
      _paramOverrides = documentSettings.paramOverrides;
      _targetUnit = documentSettings.targetUnit;

      // ── Compile ──────────────────────────────────
      final scene = resolveGeometry(
        doc,
        ResolveOptions(overrides: _paramOverrides, targetUnit: _targetUnit),
      );

      setState(() {
        _scene = scene;
        if (scene.sheets.isEmpty) {
          _selectedSheetId = null;
        } else if (_selectedSheetId == null ||
            !scene.sheets.containsKey(_selectedSheetId)) {
          _selectedSheetId = scene.sheets.keys.first;
        }
      });
    } on YamlException catch (e) {
      setState(() {
        _yamlError = e.message;
      });
    } catch (e) {
      setState(() {
        _compilerError = e.toString();
      });
    }
  }

  void _applyProfile(String? profileName) {
    final documentSettings = WorkbenchDocumentSettings(
      profiles: _profiles,
      paramValues: _paramValues,
      paramOverrides: _paramOverrides,
      targetUnit: _targetUnit,
    );
    setState(() {
      _activeProfile = profileName;
      _documentController.setParamOverrides(
        documentSettings.overridesForProfile(profileName),
      );
    });
    _compileDSL(_editorController.text);
  }

  // ─────────────────────────────────────────────
  // Viewport Controls
  // ─────────────────────────────────────────────

  void _resetViewport() {
    final bbox = _displayBounds;
    if (bbox == null) return;
    _viewportController.reset(
      bbox,
      fallbackViewportSize: _fallbackViewportSize,
    );
  }

  void _fitViewport() {
    final bbox = _displayBounds;
    if (bbox == null) return;
    if (bbox.width < 1 || bbox.height < 1) return;

    _viewportController.fit(bbox, fallbackViewportSize: _fallbackViewportSize);
  }

  void _zoomIn() {
    if (_scene == null) return;
    _viewportController.zoomIn(fallbackViewportSize: _fallbackViewportSize);
  }

  void _zoomOut() {
    if (_scene == null) return;
    _viewportController.zoomOut(fallbackViewportSize: _fallbackViewportSize);
  }

  String get _activeSurfaceLabel => _selectedSheetId != null
      ? 'Sheet/View: ${_selectedSheetId!}'
      : 'Model Preview';

  String get _activePreviewRouteLabel => _selectedSheetId != null
      ? 'Sheet/view physical preview route'
      : 'Scene model preview route';

  String get _exportButtonLabel =>
      _selectedSheetId != null ? 'SVG SHEET' : 'SVG MODEL';

  // ─────────────────────────────────────────────
  // SVG Export
  // ─────────────────────────────────────────────

  Future<void> _exportSVG() => _exportSVGTarget(_selectedSheetId);

  Future<void> _exportModelSVG() => _exportSVGTarget(null);

  Future<void> _exportSheetSVG() {
    final sheetId = _selectedSheetId;
    if (sheetId == null) return Future<void>.value();
    return _exportSVGTarget(sheetId);
  }

  Future<void> _exportSVGTarget(String? sheetId) async {
    try {
      final scene = _scene;
      if (scene == null) throw Exception('Scene belum dikompilasi.');
      final svg = SvgExporter.generateSVG(
        scene,
        hiddenRoles: _overlayController.hiddenRoles,
        sheetId: sheetId,
      );
      if (svg.isEmpty) throw Exception('Hasil kompilasi kosong.');

      final surfaceLabel = sheetId != null
          ? 'Sheet/View: $sheetId'
          : 'Model Preview';
      final dialogTitle = sheetId != null
          ? 'Simpan SVG Sheet/View'
          : 'Simpan SVG Model Preview';
      final fileName = sheetId != null
          ? 'relgeo-sheet-$sheetId.svg'
          : 'relgeo-model-preview.svg';

      final outputFile = await _svgExportController.saveSvg(
        dialogTitle: dialogTitle,
        fileName: fileName,
        svg: svg,
      );
      if (outputFile == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SVG $surfaceLabel berhasil disimpan ke: $outputFile',
            ),
            action: SnackBarAction(
              label: 'LIHAT',
              onPressed: () => _showSVGDialog(svg, surfaceLabel: surfaceLabel),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Gagal menyimpan SVG: $e'),
          ),
        );
      }
    }
  }

  void _showSVGDialog(String code, {String? surfaceLabel}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('SVG EXPORT · ${surfaceLabel ?? _activeSurfaceLabel}'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasError = _yamlError != null || _compilerError != null;
    final commandRegistry = _buildCommandRegistry();

    final shell = WorkbenchCompositionShell(
      menuBar: WorkbenchPlatformMenuBar.usesNativeMenu
          ? (widget.showInWindowMenu == true
                ? WorkbenchMenuBar(registry: commandRegistry)
                : null)
          : WorkbenchMenuBar(registry: commandRegistry),
      navbar: _buildNavbar(hasError, commandRegistry),
      layoutController: _layoutController,
      editor: WorkbenchEditorFeature(
        contract: WorkbenchEditorContract(
          controller: _editorController.editingController,
          visualProfile: _workbenchProfile,
        ),
      ),
      parameters: _paramValues.isEmpty
          ? null
          : WorkbenchParametersFeature(
              contract: WorkbenchParametersContract(
                paramValues: _paramValues,
                paramOverrides: _paramOverrides,
                targetUnit: _targetUnit.name,
                onParamChanged: (pName, value) {
                  _documentController.setParamOverride(pName, value);
                  _compileDSL(_editorController.text);
                },
                onParamReset: () {
                  _documentController.clearParamOverrides();
                  _compileDSL(_editorController.text);
                },
                visualProfile: _workbenchProfile,
              ),
            ),
      viewport: _buildViewportPanel(commandRegistry),
      inspector: WorkbenchInspectorFeature(
        contract: WorkbenchInspectorContract(
          scene: _scene,
          yamlError: _yamlError,
          compilerError: _compilerError,
          targetUnit: _targetUnit.name,
          visualProfile: _workbenchProfile,
          themeTokens: Theme.of(context).extension<RelGeoThemeExtension>(),
        ),
      ),
    );

    final commandSurface = WorkbenchCommandSurface(
      registry: commandRegistry,
      child: shell,
    );
    return WorkbenchPlatformMenuBar(
      registry: commandRegistry,
      child: commandSurface,
    );
  }

  WorkbenchCommandRegistry _buildCommandRegistry() {
    return WorkbenchCommandRegistry([
      WorkbenchCommand(
        id: WorkbenchCommandId.newDocument,
        menu: 'File',
        label: 'New document',
        enabled: widget.onNewDocument != null,
        onInvoke: () => unawaited(_runLifecycleAction(widget.onNewDocument)),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.openDocument,
        menu: 'File',
        label: 'Open document…',
        enabled: widget.onOpenDocument != null || widget.fileService != null,
        onInvoke: () {
          if (widget.onOpenDocument != null) {
            unawaited(_runLifecycleAction(widget.onOpenDocument));
          } else {
            unawaited(_openDocumentFromFileService());
          }
        },
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.saveDocument,
        menu: 'File',
        label: 'Save document',
        enabled:
            widget.onSaveDocument != null ||
            widget.onSaveDocumentWithResult != null ||
            widget.fileService != null,
        onInvoke: () {
          if (widget.onSaveDocumentWithResult != null) {
            unawaited(_saveDocumentWithHostResult(saveAs: false));
          } else if (widget.onSaveDocument != null) {
            widget.onSaveDocument!.call();
          } else {
            unawaited(_saveDocumentToFileService(saveAs: false));
          }
        },
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.saveAsDocument,
        menu: 'File',
        label: 'Save document as…',
        enabled:
            widget.onSaveAsDocument != null ||
            widget.onSaveDocumentWithResult != null ||
            widget.fileService != null,
        onInvoke: () {
          if (widget.onSaveDocumentWithResult != null) {
            unawaited(_saveDocumentWithHostResult(saveAs: true));
          } else if (widget.onSaveAsDocument != null) {
            widget.onSaveAsDocument!.call();
          } else {
            unawaited(_saveDocumentToFileService(saveAs: true));
          }
        },
        shortcut: const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.closeDocument,
        menu: 'File',
        label: 'Close document',
        enabled: widget.onCloseDocument != null,
        onInvoke: () => unawaited(_runLifecycleAction(widget.onCloseDocument)),
        shortcut: const SingleActivator(LogicalKeyboardKey.keyW, control: true),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.keyW,
          control: true,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.quitApplication,
        menu: 'File',
        label: 'Quit RelGeo',
        enabled: widget.onQuitApplication != null,
        onInvoke: () =>
            unawaited(_runLifecycleAction(widget.onQuitApplication)),
        shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, control: true),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.keyQ,
          control: true,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.exportSvg,
        menu: 'Toolbar',
        label: _exportButtonLabel,
        enabled: _scene != null,
        onInvoke: _exportSVG,
        shortcut: const SingleActivator(LogicalKeyboardKey.keyE, control: true),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.keyE,
          control: true,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.exportSvgModel,
        menu: 'File',
        submenuPath: const ['Export', 'SVG'],
        label: 'Model',
        enabled: _scene != null,
        onInvoke: _exportModelSVG,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.exportSvgSheet,
        menu: 'File',
        submenuPath: const ['Export', 'SVG'],
        label: 'Sheet / View',
        enabled: _scene?.sheets.isNotEmpty == true && _selectedSheetId != null,
        onInvoke: _exportSheetSVG,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.undo,
        menu: 'Edit',
        label: 'Undo',
        enabled: _editorController.editingController.canUndo,
        onInvoke: _editorController.editingController.undo,
        shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.redo,
        menu: 'Edit',
        label: 'Redo',
        enabled: _editorController.editingController.canRedo,
        onInvoke: _editorController.editingController.redo,
        shortcut: const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.copySource,
        menu: 'Edit',
        label: 'Copy source',
        onInvoke: _copySourceToClipboard,
        shortcut: const SingleActivator(LogicalKeyboardKey.keyC, control: true),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.keyC,
          control: true,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.recompileDocument,
        menu: 'Document',
        label: 'Recompile document',
        onInvoke: () => _compileDSL(_editorController.text),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.resetDocumentParameters,
        menu: 'Document',
        label: 'Reset parameter overrides',
        enabled: _paramValues.isNotEmpty,
        onInvoke: _resetDocumentParameters,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.zoomIn,
        menu: 'View',
        label: 'Zoom in',
        onInvoke: _zoomIn,
        shortcut: const SingleActivator(LogicalKeyboardKey.add, control: true),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.add,
          control: true,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.zoomOut,
        menu: 'View',
        label: 'Zoom out',
        onInvoke: _zoomOut,
        shortcut: const SingleActivator(
          LogicalKeyboardKey.minus,
          control: true,
        ),
        shortcutActivator: const SingleActivator(
          LogicalKeyboardKey.minus,
          control: true,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.fitViewport,
        menu: 'View',
        label: 'Fit viewport',
        onInvoke: _fitViewport,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.resetViewport,
        menu: 'View',
        label: 'Reset viewport',
        onInvoke: _resetViewport,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.toggleEditorPanel,
        menu: 'View',
        label: 'Code editor',
        checked: _layoutController.isPanelVisible(WorkbenchPanelId.editor),
        onInvoke: () => _layoutController.togglePanel(WorkbenchPanelId.editor),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.togglePreviewPanel,
        menu: 'View',
        label: 'Preview',
        checked: _layoutController.isPanelVisible(WorkbenchPanelId.preview),
        onInvoke: () => _layoutController.togglePanel(WorkbenchPanelId.preview),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.toggleInspectorPanel,
        menu: 'View',
        label: 'Inspector',
        checked: _layoutController.isPanelVisible(WorkbenchPanelId.inspector),
        onInvoke: () =>
            _layoutController.togglePanel(WorkbenchPanelId.inspector),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.toggleParametersPanel,
        menu: 'View',
        label: 'Parameters',
        enabled: _paramValues.isNotEmpty,
        checked:
            _paramValues.isNotEmpty &&
            _layoutController.isPanelVisible(WorkbenchPanelId.parameters),
        onInvoke: () => _layoutController.togglePanel(
          WorkbenchPanelId.parameters,
          availability: _paramValues.isEmpty
              ? WorkbenchPanelAvailability.unavailable
              : WorkbenchPanelAvailability.available,
        ),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.collapseEditorPanel,
        menu: 'View',
        label: 'Collapse Code editor',
        checked: _layoutController.isPanelCollapsed(WorkbenchPanelId.editor),
        onInvoke: () =>
            _layoutController.toggleCollapsed(WorkbenchPanelId.editor),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.collapsePreviewPanel,
        menu: 'View',
        label: 'Collapse Preview',
        checked: _layoutController.isPanelCollapsed(WorkbenchPanelId.preview),
        onInvoke: () =>
            _layoutController.toggleCollapsed(WorkbenchPanelId.preview),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.collapseInspectorPanel,
        menu: 'View',
        label: 'Collapse Inspector',
        checked: _layoutController.isPanelCollapsed(WorkbenchPanelId.inspector),
        onInvoke: () =>
            _layoutController.toggleCollapsed(WorkbenchPanelId.inspector),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.collapseParametersPanel,
        menu: 'View',
        label: 'Collapse Parameters',
        enabled: _paramValues.isNotEmpty,
        checked:
            _paramValues.isNotEmpty &&
            _layoutController.isPanelCollapsed(WorkbenchPanelId.parameters),
        onInvoke: () =>
            _layoutController.toggleCollapsed(WorkbenchPanelId.parameters),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.resetLayout,
        menu: 'View',
        label: 'Reset layout',
        onInvoke: _layoutController.reset,
      ),
      ..._buildPanelPlacementCommands(),
      for (final profile in WorkbenchLayoutProfiles.all)
        WorkbenchCommand(
          id: switch (profile.id) {
            'standard' => WorkbenchCommandId.standardLayoutProfile,
            'writing' => WorkbenchCommandId.writingLayoutProfile,
            'preview' => WorkbenchCommandId.previewLayoutProfile,
            'inspect' => WorkbenchCommandId.inspectLayoutProfile,
            _ => WorkbenchCommandId.minimalLayoutProfile,
          },
          menu: 'Workbench',
          label: profile.label,
          checked: _layoutController.layout.activeProfileId == profile.id,
          onInvoke: () => _applyLayoutProfile(profile),
        ),
      WorkbenchCommand(
        id: WorkbenchCommandId.lightTheme,
        menu: 'Appearance',
        label: 'Light',
        onInvoke: () =>
            widget.onThemePreferenceChanged?.call(RelGeoThemePreference.light),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.darkTheme,
        menu: 'Appearance',
        label: 'Dark',
        onInvoke: () =>
            widget.onThemePreferenceChanged?.call(RelGeoThemePreference.dark),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.followSystemTheme,
        menu: 'Appearance',
        label: 'Follow system appearance',
        enabled: widget.onResetThemePreference != null,
        onInvoke: () => widget.onResetThemePreference?.call(),
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.resetPreferences,
        menu: 'Workbench',
        label: 'Reset workbench preferences',
        onInvoke: _resetWorkbenchPreferences,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.aboutRelGeo,
        menu: 'Help',
        label: 'About RelGeo',
        onInvoke: _showAboutDialog,
      ),
    ]);
  }

  List<WorkbenchCommand> _buildPanelPlacementCommands() {
    WorkbenchCommand placementCommand({
      required WorkbenchCommandId id,
      required WorkbenchPanelId panel,
      required WorkbenchPanelPlacement placement,
      required String label,
      bool enabled = true,
    }) {
      return WorkbenchCommand(
        id: id,
        menu: 'Workbench',
        label: label,
        enabled: enabled,
        onInvoke: () => _layoutController.setPlacement(panel, placement),
      );
    }

    final parametersAvailable = _paramValues.isNotEmpty;
    return [
      placementCommand(
        id: WorkbenchCommandId.dockEditorLeft,
        panel: WorkbenchPanelId.editor,
        placement: WorkbenchPanelPlacement.left,
        label: 'Dock Code editor left',
      ),
      placementCommand(
        id: WorkbenchCommandId.dockPreviewCenter,
        panel: WorkbenchPanelId.preview,
        placement: WorkbenchPanelPlacement.center,
        label: 'Dock Preview center',
      ),
      placementCommand(
        id: WorkbenchCommandId.dockInspectorRight,
        panel: WorkbenchPanelId.inspector,
        placement: WorkbenchPanelPlacement.right,
        label: 'Dock Inspector right',
      ),
      placementCommand(
        id: WorkbenchCommandId.dockParametersBottom,
        panel: WorkbenchPanelId.parameters,
        placement: WorkbenchPanelPlacement.bottom,
        label: 'Dock Parameters bottom',
        enabled: parametersAvailable,
      ),
      placementCommand(
        id: WorkbenchCommandId.floatEditor,
        panel: WorkbenchPanelId.editor,
        placement: WorkbenchPanelPlacement.floating,
        label: 'Float Code editor',
      ),
      placementCommand(
        id: WorkbenchCommandId.floatPreview,
        panel: WorkbenchPanelId.preview,
        placement: WorkbenchPanelPlacement.floating,
        label: 'Float Preview',
      ),
      placementCommand(
        id: WorkbenchCommandId.floatInspector,
        panel: WorkbenchPanelId.inspector,
        placement: WorkbenchPanelPlacement.floating,
        label: 'Float Inspector',
      ),
      placementCommand(
        id: WorkbenchCommandId.floatParameters,
        panel: WorkbenchPanelId.parameters,
        placement: WorkbenchPanelPlacement.floating,
        label: 'Float Parameters',
        enabled: parametersAvailable,
      ),
      placementCommand(
        id: WorkbenchCommandId.overlayEditor,
        panel: WorkbenchPanelId.editor,
        placement: WorkbenchPanelPlacement.overlay,
        label: 'Overlay Code editor',
      ),
      placementCommand(
        id: WorkbenchCommandId.overlayPreview,
        panel: WorkbenchPanelId.preview,
        placement: WorkbenchPanelPlacement.overlay,
        label: 'Overlay Preview',
      ),
      placementCommand(
        id: WorkbenchCommandId.overlayInspector,
        panel: WorkbenchPanelId.inspector,
        placement: WorkbenchPanelPlacement.overlay,
        label: 'Overlay Inspector',
      ),
      placementCommand(
        id: WorkbenchCommandId.overlayParameters,
        panel: WorkbenchPanelId.parameters,
        placement: WorkbenchPanelPlacement.overlay,
        label: 'Overlay Parameters',
        enabled: parametersAvailable,
      ),
    ];
  }

  // ── Navbar ─────────────────────────────────────

  Widget _buildNavbar(bool hasError, WorkbenchCommandRegistry commandRegistry) {
    return WorkbenchNavbar(
      hasError: hasError,
      exportButtonLabel: _exportButtonLabel,
      onExport: _exportSVG,
      commandRegistry: commandRegistry,
    );
  }

  // ── Viewport Panel (tengah) ─────────────────

  Widget _buildViewportPanel(WorkbenchCommandRegistry commandRegistry) {
    return WorkbenchPreviewFeature(
      toolbar: _buildViewportToolbar(commandRegistry),
      overlayToolbar: _buildOverlayToolbar(),
      panel: WorkbenchViewportPanel(
        visualProfile: _workbenchProfile,
        viewportController: _viewportController.transformationController,
        scene: _scene,
        displayBounds: _displayBounds,
        overlay: _overlayController.overlay,
        zoomLevel: _viewportController.zoomLevel,
        selectedSheetId: _selectedSheetId,
        hiddenRoles: _overlayController.hiddenRoles,
        onViewportSizeChanged: (size) {
          _viewportController.setViewportSize(size);
        },
        activeSheetPhysicalTargetLabel: _activeSheet != null
            ? _activeSheetPhysicalTargetLabel
            : null,
        activeSheetViewSummaryLabel: _activeSheet != null
            ? _activeSheetViewSummaryLabel
            : null,
      ),
    );
  }

  Widget _buildViewportToolbar(WorkbenchCommandRegistry commandRegistry) {
    return WorkbenchViewportToolbar(
      visualProfile: _workbenchProfile,
      commandRegistry: commandRegistry,
      zoomLevel: _viewportController.zoomLevel,
      targetUnitLabel: _targetUnit.name.toUpperCase(),
      previewRouteLabel: _activePreviewRouteLabel,
      workbenchProfileId: widget.workbenchProfileId,
      themePreference: widget.themePreference,
      onWorkbenchProfileChanged: widget.onWorkbenchProfileChanged,
      onThemePreferenceChanged: widget.onThemePreferenceChanged,
      documentProfileNames: _profiles.keys.toList(),
      activeProfile: _activeProfile,
      onProfileChanged: _applyProfile,
      sheetIds: _scene?.sheets.keys.toList() ?? const [],
      selectedSheetId: _selectedSheetId,
      onSheetChanged: (value) {
        setState(() {
          _selectedSheetId = value;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fitViewport();
        });
      },
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
      onFitViewport: _fitViewport,
      onResetViewport: _resetViewport,
    );
  }

  Widget _buildOverlayToolbar() {
    return WorkbenchOverlayToolbar(
      visualProfile: _workbenchProfile,
      overlay: _overlayController.overlay,
      hiddenRoles: _overlayController.hiddenRoles,
      followProfileOverlay: _overlayController.followProfileOverlay,
      followProfileRoleFilter: _overlayController.followProfileRoleFilter,
      onFollowProfileOverlayChanged: _setFollowProfileOverlay,
      onFollowProfileRoleFilterChanged: _setFollowProfileRoleFilter,
      onOverlayChanged: _setOverlayManual,
      onHiddenRolesChanged: _setHiddenRolesManual,
    );
  }
}
