import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../geometry/types.dart';
import '../geometry/utils.dart' as geom;
import 'workbench_visual_profile.dart';

// ─────────────────────────────────────────────
// Inspector Panel — Tab Objects / Values / Errors / BOM
// ─────────────────────────────────────────────

/// Panel Inspector dengan 4 tab untuk menginspeksi scene yang telah dikompilasi.
class InspectorPanel extends StatefulWidget {
  final ResolvedScene? scene;
  final String? yamlError;
  final String? compilerError;
  final String targetUnit;
  final WorkbenchVisualProfile visualProfile;

  const InspectorPanel({
    super.key,
    required this.scene,
    required this.yamlError,
    required this.compilerError,
    required this.targetUnit,
    this.visualProfile = WorkbenchVisualProfile.cadDark,
  });

  @override
  State<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<InspectorPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, bool> _expandedObjects = {};

  static const _errorColor = Color(0xFFEF4444);
  static const _errorSoftColor = Color(0x1AEF4444);
  static const _readyColor = Color(0xFF10B981);
  static const _accentColor = Color(0xFFF59E0B);

  WorkbenchVisualProfile get _visualProfile => widget.visualProfile;
  Color get _bgColor => _visualProfile.overlayBackgroundColor;
  Color get _surfaceColor => _visualProfile.toolbarBackgroundColor;
  Color get _surfaceStrongColor =>
      _visualProfile.toolbarBackgroundColor.withOpacity(0.9);
  Color get _borderColor => _visualProfile.borderColor;
  Color get _mutedColor => _visualProfile.mutedColor;
  Color get _brandColor => _visualProfile.accentColor;
  Color get _brandSoftColor => _visualProfile.accentSoftColor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Tab: Objects ───────────────────────────

  Widget _buildObjectsTab() {
    final scene = widget.scene;
    if (scene == null || scene.objects.isEmpty) {
      return _emptyState('Belum ada objek yang dikompilasi.');
    }

    final entries = scene.objects.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final id = entries[i].key;
        final obj = entries[i].value;
        final isExpanded = _expandedObjects[id] ?? false;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isExpanded ? _surfaceStrongColor : _surfaceColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isExpanded ? _brandColor.withOpacity(0.4) : _borderColor,
            ),
          ),
          child: Column(
            children: [
              // Header card
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() {
                  _expandedObjects[id] = !isExpanded;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: _mutedColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                id,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _brandSoftColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _typeLabel(obj),
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _brandColor,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Role badge
                      if (obj.meta.role.isNotEmpty && obj.meta.role != 'final')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _roleBadgeColor(
                              obj.meta.role,
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: _roleBadgeColor(
                                obj.meta.role,
                              ).withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            obj.meta.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: _roleBadgeColor(obj.meta.role),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Expanded details
              if (isExpanded) ...[
                Divider(height: 1, color: _borderColor),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: _buildObjectDetails(obj),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildObjectDetails(ResolvedObject obj) {
    final rows = <_DetailRow>[];
    final unit = widget.targetUnit;
    final fmt = (double? v) => v != null ? v.toStringAsFixed(2) : '?';

    switch (obj) {
      case ResolvedPoint(:final x, :final y):
        rows.addAll([_DetailRow('Coordinate', '(${fmt(x)}, ${fmt(y)}) $unit')]);
      case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
        final len = geom.hypot(x2 - x1, y2 - y1);
        final angle = math.atan2(y2 - y1, x2 - x1) * 180 / math.pi;
        rows.addAll([
          _DetailRow('Start', '(${fmt(x1)}, ${fmt(y1)})'),
          _DetailRow('End', '(${fmt(x2)}, ${fmt(y2)})'),
          _DetailRow('Length', '${len.toStringAsFixed(2)} $unit'),
          _DetailRow('Angle', '${angle.toStringAsFixed(1)}°'),
        ]);
      case ResolvedRect(:final x, :final y, :final width, :final height):
        rows.addAll([
          _DetailRow('Size', '${fmt(width)} × ${fmt(height)} $unit'),
          _DetailRow('Area', '${(width * height).toStringAsFixed(1)} ${unit}²'),
          _DetailRow(
            'Center',
            '(${(x + width / 2).toStringAsFixed(1)}, ${(y + height / 2).toStringAsFixed(1)})',
          ),
          _DetailRow('Origin', '(${fmt(x)}, ${fmt(y)})'),
        ]);
      case ResolvedCircle(:final cx, :final cy, :final radius):
        rows.addAll([
          _DetailRow('Center', '(${fmt(cx)}, ${fmt(cy)})'),
          _DetailRow('Radius', '${fmt(radius)} $unit'),
          _DetailRow('Diameter', '${(radius * 2).toStringAsFixed(2)} $unit'),
          _DetailRow(
            'Area',
            '${(math.pi * radius * radius).toStringAsFixed(1)} ${unit}²',
          ),
        ]);
      case ResolvedEllipse(
        :final cx,
        :final cy,
        :final rx,
        :final ry,
        :final rotation,
      ):
        final h = math.pow(rx - ry, 2) / math.pow(rx + ry, 2);
        final perimeter =
            math.pi * (rx + ry) * (1 + (3 * h) / (10 + math.sqrt(4 - 3 * h)));
        rows.addAll([
          _DetailRow('Center', '(${fmt(cx)}, ${fmt(cy)})'),
          _DetailRow('Radii', '${fmt(rx)} × ${fmt(ry)} $unit'),
          _DetailRow(
            'Rotation',
            '${(rotation * 180 / math.pi).toStringAsFixed(1)}°',
          ),
          _DetailRow(
            'Area',
            '${(math.pi * rx * ry).toStringAsFixed(1)} ${unit}²',
          ),
          _DetailRow('Perimeter', '${perimeter.toStringAsFixed(1)} $unit'),
        ]);
      case ResolvedArc(
        :final cx,
        :final cy,
        :final radius,
        :final startAngle,
        :final endAngle,
      ):
        rows.addAll([
          _DetailRow('Center', '(${fmt(cx)}, ${fmt(cy)})'),
          _DetailRow('Radius', '${fmt(radius)} $unit'),
          _DetailRow(
            'Angles',
            '${(startAngle * 180 / math.pi).toStringAsFixed(0)}° → ${(endAngle * 180 / math.pi).toStringAsFixed(0)}°',
          ),
        ]);
      case ResolvedPath(:final segments, :final closed):
        rows.addAll([
          _DetailRow('Closed', closed ? 'YES' : 'NO'),
          _DetailRow('Segments', segments.length.toString()),
        ]);
      case ResolvedPolygon(:final segments):
        rows.addAll([
          _DetailRow('Closed', 'YES'),
          _DetailRow('Segments', segments.length.toString()),
        ]);
      case ResolvedText(:final content, :final x, :final y):
        rows.addAll([
          _DetailRow('Content', '"$content"'),
          _DetailRow('Position', '(${fmt(x)}, ${fmt(y)})'),
        ]);
      case ResolvedDimension(:final text):
        rows.addAll([_DetailRow('Text', text)]);
      case ResolvedAnnotation(:final text):
        rows.addAll([_DetailRow('Text', text)]);
      case ResolvedComponent(:final children):
        rows.addAll([
          _DetailRow('Type', 'Component Instance'),
          _DetailRow('Children', children.length.toString()),
        ]);
        if (obj.anchors.isNotEmpty) {
          rows.add(_DetailRow('Exports', obj.anchors.keys.join(', ')));
        }
      case BaseResolvedGroup(:final children):
        rows.addAll([_DetailRow('Children', children.length.toString())]);
      default:
        break;
    }

    if (rows.isEmpty) {
      return Text(
        'Type: ${_typeLabel(obj)}',
        style: TextStyle(
          color: _mutedColor,
          fontFamily: 'Courier',
          fontSize: 11,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  row.label,
                  style: TextStyle(
                    color: _mutedColor,
                    fontFamily: 'Courier',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Flexible(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _brandColor,
                      fontFamily: 'Courier',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Transforms info
        if (obj.transforms.isNotEmpty) ...[
          const SizedBox(height: 4),
          Divider(height: 1, color: _borderColor),
          const SizedBox(height: 4),
          Text(
            'Transforms (${obj.transforms.length})',
            style: TextStyle(
              color: _mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          for (final t in obj.transforms)
            Text(
              '  ${_transformLabel(t)}',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontFamily: 'Courier',
                fontSize: 10,
              ),
            ),
        ],
      ],
    );
  }

  // ─── Tab: Values ───────────────────────────

  Widget _buildValuesTab() {
    final scene = widget.scene;
    if (scene == null || scene.values.isEmpty) {
      return _emptyState('Tidak ada parameter atau derived scalar.');
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final entry in scene.values.entries)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _formatDerivedValue(entry.value, widget.targetUnit),
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _brandColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Tab: Errors ───────────────────────────

  Widget _buildErrorsTab() {
    final yamlErr = widget.yamlError;
    final compErr = widget.compilerError;
    final scene = widget.scene;

    if (yamlErr == null && compErr == null) {
      if (scene != null && scene.violations.isNotEmpty) {
        return _buildViolationsList(scene.violations);
      }
      return _buildCompilationSummary();
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (yamlErr != null) _buildErrorCard('YAML SYNTAX ERROR', yamlErr),
        if (compErr != null)
          _buildErrorCard('COMPILER / TOPOLOGY ERROR', compErr),
      ],
    );
  }

  Widget _buildErrorCard(String title, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorSoftColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _errorColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: _errorColor, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: _errorColor,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 11,
              color: Color(0xFFFDA4AF),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationsList(List<ConstraintViolation> violations) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: violations.length,
      itemBuilder: (context, i) {
        final v = violations[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _accentColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    color: _accentColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      v.message,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 11,
                        color: _accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompilationSummary() {
    final scene = widget.scene;
    if (scene == null) {
      return _emptyState('Ketik DSL untuk memulai kompilasi.');
    }

    final stats = [
      ('Resolved Objects', '${scene.objects.length} items'),
      ('Constraint Violations', '${scene.violations.length}'),
      ('Target Unit', scene.unit.name.toUpperCase()),
      (
        'Scene Width',
        '${scene.bbox.width.toStringAsFixed(1)} ${scene.unit.name}',
      ),
      (
        'Scene Height',
        '${scene.bbox.height.toStringAsFixed(1)} ${scene.unit.name}',
      ),
      (
        'Bounds X',
        '${scene.bbox.x.toStringAsFixed(1)} → ${(scene.bbox.x + scene.bbox.width).toStringAsFixed(1)}',
      ),
      (
        'Bounds Y',
        '${scene.bbox.y.toStringAsFixed(1)} → ${(scene.bbox.y + scene.bbox.height).toStringAsFixed(1)}',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _readyColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _readyColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: _readyColor,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'COMPILATION SUCCESSFUL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: _readyColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final stat in stats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stat.$1,
                        style: TextStyle(
                          color: _mutedColor,
                          fontFamily: 'Courier',
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        stat.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Courier',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Tab: BOM ───────────────────────────

  Widget _buildBomTab() {
    final scene = widget.scene;
    if (scene == null || scene.objects.isEmpty) {
      return _emptyState('Tidak ada data manufacturing tersedia.');
    }

    final unit = widget.targetUnit;
    final bomMap = <String, _BomItem>{};
    double totalCutLength = 0.0;
    double totalArea = 0.0;

    for (final obj in scene.objects.values) {
      String key;
      String details;
      String type;

      switch (obj) {
        case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
          final len = geom.hypot(x2 - x1, y2 - y1);
          totalCutLength += len;
          key = 'Line';
          details = 'Length: ${len.toStringAsFixed(1)} $unit';
          type = 'Cut';
        case ResolvedRect(:final width, :final height):
          final area = width * height;
          totalArea += area;
          key =
              'Rect (${width.toStringAsFixed(0)}×${height.toStringAsFixed(0)})';
          details =
              'Perimeter: ${(2 * (width + height)).toStringAsFixed(1)} $unit, Area: ${area.toStringAsFixed(1)} ${unit}²';
          type = 'Plate';
        case ResolvedCircle(:final radius):
          final area = math.pi * radius * radius;
          totalArea += area;
          key = 'Circle (r=${radius.toStringAsFixed(1)})';
          details =
              'Ø ${(radius * 2).toStringAsFixed(1)} $unit, Area: ${area.toStringAsFixed(1)} ${unit}²';
          type = 'Hole';
        case ResolvedEllipse(:final rx, :final ry):
          final area = math.pi * rx * ry;
          final h = math.pow(rx - ry, 2) / math.pow(rx + ry, 2);
          final perimeter =
              math.pi * (rx + ry) * (1 + (3 * h) / (10 + math.sqrt(4 - 3 * h)));
          totalArea += area;
          key = 'Ellipse (${rx.toStringAsFixed(0)}×${ry.toStringAsFixed(0)})';
          details =
              'Perimeter: ${perimeter.toStringAsFixed(1)} $unit, Area: ${area.toStringAsFixed(1)} ${unit}²';
          type = 'Profile';
        case ResolvedPath(:final segments):
          double len = 0;
          for (final seg in segments) {
            final pts = geom.sampleSegmentLikePoints(seg);
            for (int i = 1; i < pts.length; i++) {
              len += geom.hypot(
                pts[i].x - pts[i - 1].x,
                pts[i].y - pts[i - 1].y,
              );
            }
          }
          totalCutLength += len;
          key = 'Path';
          details = 'Length: ${len.toStringAsFixed(1)} $unit';
          type = 'Cut';
        case ResolvedPolygon(:final segments):
          double len = 0;
          for (final seg in segments) {
            final pts = geom.sampleSegmentLikePoints(seg);
            for (int i = 1; i < pts.length; i++) {
              len += geom.hypot(
                pts[i].x - pts[i - 1].x,
                pts[i].y - pts[i - 1].y,
              );
            }
          }
          totalCutLength += len;
          key = 'Polygon';
          details = 'Perimeter: ${len.toStringAsFixed(1)} $unit';
          type = 'Cut';
        case ResolvedComponent(:final children):
          totalCutLength += 0;
          key = 'Component Instance';
          details = '${children.length} child objects';
          type = 'Component';
        default:
          continue;
      }

      if (bomMap.containsKey(key)) {
        bomMap[key]!.count++;
      } else {
        bomMap[key] = _BomItem(count: 1, details: details, type: type);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Summary row
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _brandSoftColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _brandColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL CUT LENGTH',
                      style: TextStyle(
                        color: _brandColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${totalCutLength.toStringAsFixed(1)} $unit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'MATERIAL AREA',
                      style: TextStyle(
                        color: _brandColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${totalArea.toStringAsFixed(1)} ${unit}²',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // BOM table
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _surfaceStrongColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Part Item',
                        style: TextStyle(
                          color: _mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        'Qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Specs',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _borderColor),
              // Table rows
              for (final entry in bomMap.entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: _borderColor, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Courier',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          entry.value.count.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _brandColor,
                            fontFamily: 'Courier',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          entry.value.details,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: _mutedColor,
                            fontFamily: 'Courier',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────

  Widget _emptyState(String msg) {
    return Center(
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(color: _mutedColor, fontSize: 12),
      ),
    );
  }

  String _typeLabel(ResolvedObject obj) {
    return switch (obj) {
      ResolvedPoint() => 'POINT',
      ResolvedLine() => 'LINE',
      ResolvedRect() => 'RECT',
      ResolvedCircle() => 'CIRCLE',
      ResolvedEllipse() => 'ELLIPSE',
      ResolvedArc() => 'ARC',
      ResolvedQuadratic() => 'QUAD',
      ResolvedCubic() => 'CUBIC',
      ResolvedPath() => 'PATH',
      ResolvedPolygon() => 'POLYGON',
      ResolvedBoolean() => 'BOOLEAN',
      ResolvedText() => 'TEXT',
      ResolvedDimension() => 'DIMENSION',
      ResolvedAnnotation() => 'ANNOTATION',
      ResolvedComponent() => 'COMPONENT',
      ResolvedClone() => 'CLONE',
      ResolvedCollection() => 'COLLECTION',
      ResolvedGroup() => 'GROUP',
      _ => 'OBJECT',
    };
  }

  Color _roleBadgeColor(String role) {
    return _visualProfile.roleColor(role);
  }

  String _transformLabel(ResolvedTransformOp op) {
    return switch (op) {
      TranslateOp(:final x, :final y) =>
        'Translate(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})',
      RotateOp(:final angle) => 'Rotate(${angle.toStringAsFixed(1)}°)',
      ScaleOp(:final sx, :final sy) =>
        'Scale(${sx.toStringAsFixed(2)}, ${sy.toStringAsFixed(2)})',
      MirrorOp(:final axis) => 'Mirror($axis)',
    };
  }

  String _smartFmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _formatDerivedValue(dynamic v, String unit) {
    if (v is double) {
      return '${_smartFmt(v)} $unit';
    }
    if (v is num) {
      return '${_smartFmt(v.toDouble())} $unit';
    }
    // Handle Point2D ({x, y} record)
    if (v != null) {
      final str = v.toString();
      // Coba parsing record ({x: ..., y: ...})
      final xMatch = RegExp(r'x:\s*([\-\d.]+)').firstMatch(str);
      final yMatch = RegExp(r'y:\s*([\-\d.]+)').firstMatch(str);
      if (xMatch != null && yMatch != null) {
        final x = double.tryParse(xMatch.group(1)!);
        final y = double.tryParse(yMatch.group(1)!);
        if (x != null && y != null) {
          return '(${_smartFmt(x)}, ${_smartFmt(y)}) $unit';
        }
      }
      return str;
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.yamlError != null || widget.compilerError != null;

    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border(left: BorderSide(color: _borderColor, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: _surfaceColor,
            child: Row(
              children: [
                Icon(Icons.analytics_outlined, color: _brandColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  'INSPECTOR',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: _brandColor,
                  ),
                ),
                const Spacer(),
                if (hasError)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _errorSoftColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _errorColor.withOpacity(0.5)),
                    ),
                    child: const Text(
                      'ERROR',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _errorColor,
                      ),
                    ),
                  )
                else if (widget.scene != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _readyColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _readyColor.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _readyColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Tab Bar
          Container(
            color: _surfaceColor,
            child: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'OBJECTS'),
                const Tab(text: 'VALUES'),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ERRORS',
                          style: TextStyle(
                            color: hasError ? _errorColor : null,
                          ),
                        ),
                        if (hasError) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: _errorColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Tab(text: 'BOM'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildObjectsTab(),
                _buildValuesTab(),
                _buildErrorsTab(),
                _buildBomTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data classes ─────────────────────────────

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}

class _BomItem {
  int count;
  final String details;
  final String type;
  _BomItem({required this.count, required this.details, required this.type});
}
