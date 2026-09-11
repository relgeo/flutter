import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:yaml/yaml.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'inspector_panel.dart';
import 'canvas_painter.dart';
import 'grid_painter.dart';
import 'editor_panel.dart';
import 'svg_exporter.dart';
import 'package:file_picker/file_picker.dart';
import 'workbench_preferences.dart';
import 'workbench_visual_profile.dart';

class CADWorkbenchPage extends StatefulWidget {
  const CADWorkbenchPage({
    super.key,
    this.initialDsl,
    this.workbenchProfileId = 'cad-dark',
    this.onWorkbenchProfileChanged,
    this.onResetWorkbenchPreferences,
  });

  final String? initialDsl;
  final String workbenchProfileId;
  final ValueChanged<String>? onWorkbenchProfileChanged;
  final Future<void> Function()? onResetWorkbenchPreferences;

  @override
  State<CADWorkbenchPage> createState() => _CADWorkbenchPageState();
}

class _CADWorkbenchPageState extends State<CADWorkbenchPage> {
  late final CodeLineEditingController _editorController;

  // Compile state
  String? _yamlError;
  String? _compilerError;
  ResolvedScene? _scene;
  Map<String, double> _paramValues = {};
  Map<String, dynamic> _paramOverrides = {};
  Map<String, Map<String, dynamic>> _profiles = {};
  String? _activeProfile;
  String? _selectedSheetId;
  LengthUnit _targetUnit = LengthUnit.mm;

  // Viewport navigation
  final TransformationController _viewportController =
      TransformationController();
  double _zoomLevel = 1.0;
  Size? _viewportSize;

  // Overlay options
  OverlayOptions _overlay = const OverlayOptions();
  Set<String> _hiddenRoles = {'construction'};
  bool _followProfileOverlay = true;
  bool _followProfileRoleFilter = true;

  WorkbenchVisualProfile get _workbenchProfile =>
      WorkbenchVisualProfile.byId(widget.workbenchProfileId);

  ResolvedSheet? get _activeSheet =>
      _scene != null && _selectedSheetId != null
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
    return (sheet.meta?.extra?['sheetSize'] ??
            (sheet.size is String ? sheet.size : 'Custom'))
        .toString();
  }

  String get _activeSheetPhysicalTargetLabel {
    final sheet = _activeSheet;
    if (sheet == null) return '';
    return 'TARGET: ${_activeSheetSizeLabel} · '
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
    if (includeOverlay) {
      _overlay = _overlayFromProfile(profile);
    }
    if (includeRoleFilter) {
      _hiddenRoles = _hiddenRolesFromProfile(profile);
    }
  }

  Future<void> _persistWorkbenchPreferences() async {
    final current =
        await WorkbenchPreferencesStore.load() ??
        WorkbenchPreferencesData.defaults;
    await WorkbenchPreferencesStore.save(
      current.copyWith(
        workbenchProfileId: widget.workbenchProfileId,
        followProfileOverlay: _followProfileOverlay,
        followProfileRoleFilter: _followProfileRoleFilter,
        showAnchors: _overlay.showAnchors,
        showLabels: _overlay.showLabels,
        showBoundingBoxes: _overlay.showBoundingBoxes,
        hiddenRoles: _hiddenRoles,
      ),
    );
  }

  Future<void> _resetWorkbenchPreferences() async {
    const defaults = WorkbenchPreferencesData.defaults;
    await widget.onResetWorkbenchPreferences?.call();
    if (!mounted) return;

    setState(() {
      _followProfileOverlay = defaults.followProfileOverlay;
      _followProfileRoleFilter = defaults.followProfileRoleFilter;
      _overlay = const OverlayOptions(
        showAnchors: false,
        showLabels: false,
        showBoundingBoxes: false,
      );
      _hiddenRoles = Set<String>.from(defaults.hiddenRoles);
    });

    if (widget.onWorkbenchProfileChanged != null &&
        widget.workbenchProfileId != defaults.workbenchProfileId) {
      widget.onWorkbenchProfileChanged!(defaults.workbenchProfileId);
    } else {
      await _persistWorkbenchPreferences();
    }
  }

  void _setFollowProfileOverlay(bool value) {
    setState(() {
      _followProfileOverlay = value;
      if (value) {
        _applyBehaviorPreset(_workbenchProfile, includeRoleFilter: false);
      }
    });
    _persistWorkbenchPreferences();
  }

  void _setFollowProfileRoleFilter(bool value) {
    setState(() {
      _followProfileRoleFilter = value;
      if (value) {
        _applyBehaviorPreset(_workbenchProfile, includeOverlay: false);
      }
    });
    _persistWorkbenchPreferences();
  }

  void _setOverlayManual(OverlayOptions overlay) {
    setState(() {
      _followProfileOverlay = false;
      _overlay = overlay;
    });
    _persistWorkbenchPreferences();
  }

  void _setHiddenRolesManual(Set<String> hiddenRoles) {
    setState(() {
      _followProfileRoleFilter = false;
      _hiddenRoles = hiddenRoles;
    });
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
    _editorController = CodeLineEditingController.fromText(initialDsl);
    _editorController.addListener(_onCodeChanged);
    _viewportController.addListener(() {
      setState(() {
        _zoomLevel = _viewportController.value.getMaxScaleOnAxis();
      });
    });
    _applyBehaviorPreset(_workbenchProfile);
    _loadWorkbenchPreferences(initialDsl);
  }

  Future<void> _loadWorkbenchPreferences(String initialDsl) async {
    final saved = await WorkbenchPreferencesStore.load();
    if (!mounted || saved == null) {
      _compileDSL(initialDsl);
      return;
    }

    setState(() {
      _followProfileOverlay = saved.followProfileOverlay;
      _followProfileRoleFilter = saved.followProfileRoleFilter;
      _overlay = OverlayOptions(
        showAnchors: saved.showAnchors,
        showLabels: saved.showLabels,
        showBoundingBoxes: saved.showBoundingBoxes,
      );
      _hiddenRoles = saved.hiddenRoles;
    });
    _compileDSL(initialDsl);
  }

  @override
  void didUpdateWidget(covariant CADWorkbenchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workbenchProfileId != widget.workbenchProfileId) {
      if (_followProfileOverlay || _followProfileRoleFilter) {
        setState(() {
          _applyBehaviorPreset(
            _workbenchProfile,
            includeOverlay: _followProfileOverlay,
            includeRoleFilter: _followProfileRoleFilter,
          );
        });
      }
      _persistWorkbenchPreferences();
    }
  }

  @override
  void dispose() {
    _editorController.dispose();
    _viewportController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _compileDSL(_editorController.text.toString());
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

      // ── Parse profiles ───────────────────────────
      if (doc.containsKey('profiles') && doc['profiles'] is Map) {
        final Map<String, Map<String, dynamic>> newProfiles = {};
        for (final entry in (doc['profiles'] as Map).entries) {
          if (entry.value is Map) {
            newProfiles[entry.key.toString()] = Map<String, dynamic>.from(
              entry.value,
            );
          }
        }
        _profiles = newProfiles;
        if (_activeProfile != null && !_profiles.containsKey(_activeProfile)) {
          _activeProfile = null;
        }
      } else {
        _profiles.clear();
        _activeProfile = null;
      }

      // ── Sync parameters ──────────────────────────
      final newParams = <String, double>{};
      final newOverrides = <String, dynamic>{};

      if (doc.containsKey('parameters') && doc['parameters'] is Map) {
        for (final entry in (doc['parameters'] as Map).entries) {
          final id = entry.key.toString();
          final val = entry.value;
          final double valDouble = val is num
              ? val.toDouble()
              : (val is Map && val.containsKey('default')
                    ? (val['default'] is num ? val['default'].toDouble() : 50.0)
                    : double.tryParse(val.toString()) ?? 50.0);
          newParams[id] = valDouble;
        }

        // Pertahankan override yang masih relevan; hapus yang sudah tidak ada
        for (final id in newParams.keys) {
          newOverrides[id] = _paramOverrides.containsKey(id)
              ? _paramOverrides[id]
              : newParams[id];
        }
      }
      // Jika tidak ada 'parameters' sama sekali, bersihkan semua
      _paramValues = newParams;
      _paramOverrides = newOverrides;

      // ── Target unit ──────────────────────────────
      if (doc.containsKey('scene') && doc['scene'] is Map) {
        final sceneMap = doc['scene'] as Map;
        if (sceneMap.containsKey('unit')) {
          _targetUnit = LengthUnit.values.firstWhere(
            (u) => u.name == sceneMap['unit'].toString(),
            orElse: () => LengthUnit.mm,
          );
        }
      }

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
    setState(() {
      _activeProfile = profileName;
      if (profileName != null && _profiles.containsKey(profileName)) {
        final profileData = _profiles[profileName]!;
        for (final key in profileData.keys) {
          if (_paramValues.containsKey(key)) {
            final val = profileData[key];
            _paramOverrides[key] = val is num ? val.toDouble() : val;
          }
        }
      } else {
        // Jika profile dilepas, kembalikan ke default parameters
        _paramOverrides.clear();
      }
    });
    _compileDSL(_editorController.text);
  }

  // ─────────────────────────────────────────────
  // Viewport Controls
  // ─────────────────────────────────────────────

  void _resetViewport() {
    final bbox = _displayBounds;
    if (bbox == null) return;
    final double vw =
        _viewportSize?.width ?? (MediaQuery.of(context).size.width * 0.43);
    final double vh =
        _viewportSize?.height ?? (MediaQuery.of(context).size.height * 0.7);

    final bboxCx = bbox.width / 2;
    final bboxCy = bbox.height / 2;

    _viewportController.value = Matrix4.identity()
      ..translate(vw / 2, vh / 2)
      ..scale(1.0)
      ..translate(-bboxCx, -bboxCy);

    setState(() => _zoomLevel = 1.0);
  }

  void _fitViewport() {
    final bbox = _displayBounds;
    if (bbox == null) return;
    if (bbox.width < 1 || bbox.height < 1) return;

    final double vw =
        _viewportSize?.width ?? (MediaQuery.of(context).size.width * 0.43);
    final double vh =
        _viewportSize?.height ?? (MediaQuery.of(context).size.height * 0.7);

    // Padding 60px pada setiap sisi
    const pad = 60.0;
    final scaleX = (vw - pad * 2) / bbox.width;
    final scaleY = (vh - pad * 2) / bbox.height;
    final scale = math.min(scaleX, scaleY).clamp(0.0001, 10000.0);

    // Center viewport ke center dari bbox
    final bboxCx = bbox.width / 2;
    final bboxCy = bbox.height / 2;

    _viewportController.value = Matrix4.identity()
      ..translate(vw / 2, vh / 2)
      ..scale(scale)
      ..translate(-bboxCx, -bboxCy);

    setState(() => _zoomLevel = scale);
  }

  void _zoomIn() {
    if (_scene == null) return;
    final currentScale = _viewportController.value.getMaxScaleOnAxis();
    if (currentScale >= 20.0) return;

    final double vw =
        _viewportSize?.width ?? (MediaQuery.of(context).size.width * 0.43);
    final double vh =
        _viewportSize?.height ?? (MediaQuery.of(context).size.height * 0.7);
    final double px = vw / 2;
    final double py = vh / 2;

    final Matrix4 zoomMatrix = Matrix4.identity()
      ..translate(px, py)
      ..scale(1.2, 1.2, 1.0)
      ..translate(-px, -py);

    _viewportController.value = zoomMatrix * _viewportController.value;
    setState(() => _zoomLevel = _viewportController.value.getMaxScaleOnAxis());
  }

  void _zoomOut() {
    if (_scene == null) return;
    final currentScale = _viewportController.value.getMaxScaleOnAxis();
    if (currentScale <= 0.05) return;

    final double vw =
        _viewportSize?.width ?? (MediaQuery.of(context).size.width * 0.43);
    final double vh =
        _viewportSize?.height ?? (MediaQuery.of(context).size.height * 0.7);
    final double px = vw / 2;
    final double py = vh / 2;

    final Matrix4 zoomMatrix = Matrix4.identity()
      ..translate(px, py)
      ..scale(0.8, 0.8, 1.0)
      ..translate(-px, -py);

    _viewportController.value = zoomMatrix * _viewportController.value;
    setState(() => _zoomLevel = _viewportController.value.getMaxScaleOnAxis());
  }

  String get _activeSurfaceLabel =>
      _selectedSheetId != null
          ? 'Sheet/View: ${_selectedSheetId!}'
          : 'Model Preview';

  String get _activePreviewRouteLabel =>
      _selectedSheetId != null
          ? 'Sheet/view physical preview route'
          : 'Scene model preview route';

  String get _exportDialogTitle =>
      _selectedSheetId != null
          ? 'Simpan SVG Sheet/View'
          : 'Simpan SVG Model Preview';

  String get _exportFileName =>
      _selectedSheetId != null
          ? 'relgeo-sheet-${_selectedSheetId!}.svg'
          : 'relgeo-model-preview.svg';

  String get _exportButtonLabel =>
      _selectedSheetId != null ? 'SVG SHEET' : 'SVG MODEL';

  // ─────────────────────────────────────────────
  // SVG Export
  // ─────────────────────────────────────────────

  Future<void> _exportSVG() async {
    try {
      final scene = _scene;
      if (scene == null) throw Exception('Scene belum dikompilasi.');
      final svg = SvgExporter.generateSVG(
        scene,
        hiddenRoles: _hiddenRoles,
        sheetId: _selectedSheetId,
      );
      if (svg.isEmpty) throw Exception('Hasil kompilasi kosong.');

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: _exportDialogTitle,
        fileName: _exportFileName,
        allowedExtensions: ['svg'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        return; // Dibatalkan oleh pengguna
      }

      final file = File(outputFile);
      await file.writeAsString(svg);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SVG ${_activeSurfaceLabel} berhasil disimpan ke: $outputFile',
            ),
            action: SnackBarAction(
              label: 'LIHAT',
              onPressed: () => _showSVGDialog(svg),
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

  void _showSVGDialog(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('SVG EXPORT · $_activeSurfaceLabel'),
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

    return Scaffold(
      body: Column(
        children: [
          // ── Top Navbar ─────────────────────────────
          _buildNavbar(hasError),

          // ── Main 3-Panel Layout ────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Panel 1: DSL Editor (32%)
                Expanded(
                  flex: 32,
                  child: EditorPanel(
                    controller: _editorController,
                    paramValues: _paramValues,
                    paramOverrides: _paramOverrides,
                    targetUnit: _targetUnit.name,
                    onParamChanged: (pName, v) {
                      setState(() => _paramOverrides[pName] = v);
                      _compileDSL(_editorController.text.toString());
                    },
                    onParamReset: () {
                      setState(() => _paramOverrides.clear());
                      _compileDSL(_editorController.text.toString());
                    },
                    visualProfile: _workbenchProfile,
                  ),
                ),
                // Panel 2: Viewport (43%)
                Expanded(flex: 43, child: _buildViewportPanel()),
                // Panel 3: Inspector (25%)
                Expanded(
                  flex: 25,
                  child: InspectorPanel(
                    scene: _scene,
                    yamlError: _yamlError,
                    compilerError: _compilerError,
                    targetUnit: _targetUnit.name,
                    visualProfile: _workbenchProfile,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Navbar ─────────────────────────────────────

  Widget _buildNavbar(bool hasError) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: [
          // Brand
          const Icon(
            Icons.hexagon_outlined,
            color: Color(0xFF00FFCC),
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'RelGeo',
            style: TextStyle(
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF00FFCC),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'CAD Workbench',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x1A00FFCC),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'v0.5',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 10,
                color: Color(0xFF00FFCC),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasError
                  ? const Color(0x1AEF4444)
                  : const Color(0x1A10B981),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: hasError
                    ? const Color(0x55EF4444)
                    : const Color(0x5510B981),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  hasError ? 'ERROR' : 'COMPILED OK',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Export SVG button
          ElevatedButton.icon(
            key: const Key('export-svg-button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            icon: const Icon(Icons.download, size: 14),
            label: Text(
              _exportButtonLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
            onPressed: _exportSVG,
          ),
        ],
      ),
    );
  }

  // ── Viewport Panel (tengah) ─────────────────

  Widget _buildViewportPanel() {
    return Container(
      color: _workbenchProfile.viewportBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Viewport toolbar
          _buildViewportToolbar(),

          // Overlay toggles
          _buildOverlayToolbar(),

          // Canvas
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Stack(
                  children: [
                    // Grid background
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GridPainter(
                          transform: _viewportController.value.clone(),
                          bbox: _displayBounds,
                          minorColor: _workbenchProfile.gridMinorColor,
                          majorColor: _workbenchProfile.gridMajorColor,
                          baseWorldStep:
                              _workbenchProfile.behavior.baseGridWorldStep,
                        ),
                      ),
                    ),
                    // Interactive scene
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: _viewportController,
                        boundaryMargin: const EdgeInsets.all(10000),
                        minScale: 0.0001,
                        maxScale: 10000.0,
                        child: _scene != null
                            ? SizedBox(
                                width: _displayBounds!.width,
                                height: _displayBounds!.height,
                                child: CustomPaint(
                                  key: const Key('scene-canvas'),
                                  painter: CanvasPainter(
                                    scene: _scene!,
                                    backgroundColor: _workbenchProfile
                                        .viewportBackgroundColor,
                                    overlay: _overlay,
                                    zoomScale: _zoomLevel,
                                    sheetId: _selectedSheetId,
                                    hiddenRoles: _hiddenRoles,
                                    visualProfile: _workbenchProfile,
                                  ),
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00FFCC),
                                ),
                              ),
                      ),
                    ),
                    // Bounds info badge
                    if (_scene != null)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          key: const Key('bounds-badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _workbenchProfile.toolbarBackgroundColor
                                .withOpacity(0.8),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: _workbenchProfile.borderColor,
                            ),
                          ),
                          child: Text(
                            'BOUNDS: (${_displayBounds!.x.toStringAsFixed(1)}, '
                            '${_displayBounds!.y.toStringAsFixed(1)}) → '
                            '${(_displayBounds!.x + _displayBounds!.width).toStringAsFixed(1)}, '
                            '${(_displayBounds!.y + _displayBounds!.height).toStringAsFixed(1)}) '
                            '${_scene!.unit.name}',
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 9,
                              color: Color(0xFF00FFCC),
                            ),
                          ),
                        ),
                      ),
                    if (_scene != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          key: const Key('preview-surface-badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _workbenchProfile.toolbarBackgroundColor
                                .withOpacity(0.88),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: _selectedSheetId != null
                                  ? const Color(0xFF10B981)
                                  : _workbenchProfile.borderColor,
                            ),
                          ),
                          child: Text(
                            _selectedSheetId != null
                                ? 'PHYSICAL PREVIEW · ${_selectedSheetId!}'
                                : 'MODEL PREVIEW',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _selectedSheetId != null
                                  ? const Color(0xFF10B981)
                                  : _workbenchProfile.accentColor,
                            ),
                          ),
                        ),
                      ),
                    if (_activeSheet != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          key: const Key('physical-target-badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _workbenchProfile.toolbarBackgroundColor
                                .withOpacity(0.88),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: const Color(0x5510B981),
                            ),
                          ),
                          child: Text(
                            _activeSheetPhysicalTargetLabel,
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    if (_activeSheet != null)
                      Positioned(
                        top: 44,
                        right: 12,
                        child: Container(
                          key: const Key('physical-view-summary-badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _workbenchProfile.toolbarBackgroundColor
                                .withOpacity(0.88),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: _workbenchProfile.borderColor,
                            ),
                          ),
                          child: Text(
                            _activeSheetViewSummaryLabel,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _workbenchProfile.accentColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewportToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration:
          const BoxDecoration(
            border: Border(bottom: BorderSide(width: 1)),
          ).copyWith(
            color: _workbenchProfile.toolbarBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: _workbenchProfile.borderColor,
                width: 1,
              ),
            ),
          ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.blur_circular,
            color: _workbenchProfile.accentColor,
            size: 14,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VIEWPORT',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: _workbenchProfile.accentColor,
                ),
              ),
              Text(
                'Zoom: ${(_zoomLevel * 100).toInt()}% · ${_targetUnit.name.toUpperCase()}',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 9,
                  color: _workbenchProfile.mutedColor,
                ),
              ),
              Text(
                _activePreviewRouteLabel,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 9,
                  color: _selectedSheetId != null
                      ? const Color(0xFF10B981)
                      : _workbenchProfile.mutedColor,
                ),
              ),
            ],
          ),
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _workbenchProfile.overlayBackgroundColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _workbenchProfile.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('workbench-profile-selector'),
                value: widget.workbenchProfileId,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: _workbenchProfile.mutedColor,
                  size: 16,
                ),
                dropdownColor: _workbenchProfile.toolbarBackgroundColor,
                style: TextStyle(
                  color: _workbenchProfile.accentColor,
                  fontSize: 11,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (value) {
                  if (value == null) return;
                  widget.onWorkbenchProfileChanged?.call(value);
                },
                items: WorkbenchVisualProfile.all
                    .map(
                      (profile) => DropdownMenuItem<String>(
                        value: profile.id,
                        key: Key('workbench-profile-option-${profile.id}'),
                        child: Text(profile.label),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          if (_profiles.isNotEmpty) ...[
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _workbenchProfile.overlayBackgroundColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _workbenchProfile.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _activeProfile,
                  hint: const Text(
                    'Select Profile',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontFamily: 'Courier',
                    ),
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: _workbenchProfile.mutedColor,
                    size: 16,
                  ),
                  dropdownColor: _workbenchProfile.toolbarBackgroundColor,
                  style: TextStyle(
                    color: _workbenchProfile.accentColor,
                    fontSize: 11,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: _applyProfile,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Default'),
                    ),
                    ..._profiles.keys.map(
                      (p) =>
                          DropdownMenuItem<String?>(value: p, child: Text(p)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_scene != null && _scene!.sheets.isNotEmpty) ...[
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _workbenchProfile.overlayBackgroundColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _workbenchProfile.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  key: const Key('sheet-selector'),
                  value: _selectedSheetId,
                  hint: const Text(
                    'Surface',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontFamily: 'Courier',
                    ),
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: _workbenchProfile.mutedColor,
                    size: 16,
                  ),
                  dropdownColor: _workbenchProfile.toolbarBackgroundColor,
                  style: TextStyle(
                    color: _workbenchProfile.accentColor,
                    fontSize: 11,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedSheetId = value;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _fitViewport();
                    });
                  },
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      key: Key('sheet-option-model-preview'),
                      child: Text('Model Preview'),
                    ),
                    ..._scene!.sheets.keys.map(
                      (id) => DropdownMenuItem<String?>(
                        value: id,
                        key: Key('sheet-option-$id'),
                        child: Text('Sheet/View: $id'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          _iconBtn(
            Icons.restart_alt,
            'Reset Workbench Preferences',
            _resetWorkbenchPreferences,
            color: _workbenchProfile.mutedColor,
            key: const Key('reset-workbench-preferences'),
          ),
          _iconBtn(Icons.zoom_in, 'Perbesar', _zoomIn),
          _iconBtn(Icons.zoom_out, 'Perkecil', _zoomOut),
          _iconBtn(
            Icons.center_focus_strong,
            'Fit',
            _fitViewport,
            color: const Color(0xFF00FFCC),
          ),
          _iconBtn(Icons.refresh, 'Reset', _resetViewport),
        ],
      ),
    );
  }

  Widget _buildOverlayToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _workbenchProfile.overlayBackgroundColor,
        border: Border(
          bottom: BorderSide(color: _workbenchProfile.borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'IDE OVERLAY',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _workbenchProfile.mutedColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              _behaviorSyncChip(
                key: const Key('overlay-sync-toggle'),
                synced: _followProfileOverlay,
                syncedLabel: 'Overlay Sync',
                customLabel: 'Overlay Custom',
                onTap: () => _setFollowProfileOverlay(!_followProfileOverlay),
              ),
              const SizedBox(width: 10),
              _behaviorStatusBadge(
                key: const Key('overlay-status-badge'),
                synced: _followProfileOverlay,
                presetLabel: 'Preset Active',
                customLabel: 'Locally Overridden',
              ),
              const SizedBox(width: 10),
              _overlayToggle(
                icon: Icons.add_circle_outline,
                label: 'Anchors',
                active: _overlay.showAnchors,
                onTap: () => _setOverlayManual(
                  OverlayOptions(
                    showAnchors: !_overlay.showAnchors,
                    showLabels: _overlay.showLabels,
                    showBoundingBoxes: _overlay.showBoundingBoxes,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _overlayToggle(
                icon: Icons.label_outline,
                label: 'Labels',
                active: _overlay.showLabels,
                onTap: () => _setOverlayManual(
                  OverlayOptions(
                    showAnchors: _overlay.showAnchors,
                    showLabels: !_overlay.showLabels,
                    showBoundingBoxes: _overlay.showBoundingBoxes,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _overlayToggle(
                icon: Icons.crop_free,
                label: 'BBox',
                active: _overlay.showBoundingBoxes,
                onTap: () => _setOverlayManual(
                  OverlayOptions(
                    showAnchors: _overlay.showAnchors,
                    showLabels: _overlay.showLabels,
                    showBoundingBoxes: !_overlay.showBoundingBoxes,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ROLE FILTER',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _workbenchProfile.mutedColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              _behaviorSyncChip(
                key: const Key('role-filter-sync-toggle'),
                synced: _followProfileRoleFilter,
                syncedLabel: 'Role Sync',
                customLabel: 'Role Custom',
                onTap: () =>
                    _setFollowProfileRoleFilter(!_followProfileRoleFilter),
              ),
              const SizedBox(width: 10),
              _behaviorStatusBadge(
                key: const Key('role-status-badge'),
                synced: _followProfileRoleFilter,
                presetLabel: 'Preset Active',
                customLabel: 'Locally Overridden',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: technicalRoles
                      .where((role) => role != 'final')
                      .map((role) => _roleToggle(role))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleToggle(String role) {
    final active = !_hiddenRoles.contains(role);
    final label = role[0].toUpperCase() + role.substring(1);
    return GestureDetector(
      onTap: () {
        final next = Set<String>.from(_hiddenRoles);
        if (next.contains(role)) {
          next.remove(role);
        } else {
          next.add(role);
        }
        _setHiddenRolesManual(next);
      },
      child: AnimatedContainer(
        key: Key('role-toggle-$role'),
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? _workbenchProfile.accentSoftColor
              : _workbenchProfile.toolbarBackgroundColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active
                ? _workbenchProfile.accentColor
                : _workbenchProfile.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: active
                ? _workbenchProfile.accentColor
                : _workbenchProfile.mutedColor,
          ),
        ),
      ),
    );
  }

  Widget _overlayToggle({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? _workbenchProfile.accentSoftColor
              : _workbenchProfile.toolbarBackgroundColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active
                ? _workbenchProfile.accentColor
                : _workbenchProfile.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: active
                  ? _workbenchProfile.accentColor
                  : _workbenchProfile.mutedColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: active
                    ? _workbenchProfile.accentColor
                    : _workbenchProfile.mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _behaviorSyncChip({
    required Key key,
    required bool synced,
    required String syncedLabel,
    required String customLabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: synced
              ? _workbenchProfile.accentSoftColor
              : _workbenchProfile.toolbarBackgroundColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: synced
                ? _workbenchProfile.accentColor
                : _workbenchProfile.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              synced ? Icons.lock_outline : Icons.tune,
              size: 12,
              color: synced
                  ? _workbenchProfile.accentColor
                  : _workbenchProfile.mutedColor,
            ),
            const SizedBox(width: 4),
            Text(
              synced ? syncedLabel : customLabel,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: synced
                    ? _workbenchProfile.accentColor
                    : _workbenchProfile.mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _behaviorStatusBadge({
    required Key key,
    required bool synced,
    required String presetLabel,
    required String customLabel,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: synced
            ? _workbenchProfile.accentSoftColor
            : _workbenchProfile.borderColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: synced
              ? _workbenchProfile.accentColor.withOpacity(0.5)
              : _workbenchProfile.borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            synced ? Icons.check_circle_outline : Icons.edit_note,
            size: 12,
            color: synced
                ? _workbenchProfile.accentColor
                : _workbenchProfile.mutedColor,
          ),
          const SizedBox(width: 4),
          Text(
            synced ? presetLabel : customLabel,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: synced
                  ? _workbenchProfile.accentColor
                  : _workbenchProfile.mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    Color color = Colors.white,
    Key? key,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: key,
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}
