/// Pustaka tipe data dan struktur geometri dasar RelGeo.
///
/// Berkas ini memetakan seluruh representasi objek yang diselesaikan (Resolved Objects)
/// dari baseline TypeScript RelGeo ke sistem tipe Dart asli yang kuat (typed).

typedef Point2D = ({double x, double y});

enum LengthUnit { px, mm, cm, m, ip } // ip = inch (atau in)

enum Orientation { yDown, yUp }

enum Origin { topLeft, bottomLeft, center }

const List<String> technicalRoles = [
  "final",
  "construction",
  "guide",
  "centerline",
  "hidden",
  "section",
  "cut",
  "fold",
  "dimension",
  "annotation",
];

class Meta {
  final bool visible;
  final String? stroke;
  final String? fill;
  final double? strokeWidth;
  final double? opacity;
  final String? label;
  final String role;
  final String? layer;
  final String? dash;
  // Manufacturing metadata from the historical v0.4 contract, retained for
  // compatibility while the active contract line is v0.5.
  final String? material;
  final String? thickness;
  final String? process;
  final String? partNo;
  final int? quantity;
  final String? finish;
  final String? tolerance;
  final Map<String, dynamic> extra;

  Meta({
    this.visible = true,
    this.stroke,
    this.fill,
    this.strokeWidth,
    this.opacity,
    this.label,
    this.role = 'final',
    this.layer,
    this.dash,
    this.material,
    this.thickness,
    this.process,
    this.partNo,
    this.quantity,
    this.finish,
    this.tolerance,
    this.extra = const {},
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    const knownKeys = {
      'visible',
      'stroke',
      'fill',
      'width',
      'strokeWidth',
      'opacity',
      'label',
      'role',
      'layer',
      'dash',
      'material',
      'thickness',
      'process',
      'partNo',
      'quantity',
      'finish',
      'tolerance',
    };
    return Meta(
      visible: json['visible'] as bool? ?? true,
      stroke: json['stroke'] as String?,
      fill: json['fill'] as String?,
      strokeWidth: (json['width'] ?? json['strokeWidth'])?.toDouble(),
      opacity: json['opacity']?.toDouble(),
      label: json['label'] as String?,
      role: json['role'] as String? ?? 'final',
      layer: json['layer'] as String?,
      dash: json['dash'] as String?,
      material: json['material'] as String?,
      thickness: json['thickness'] as String?,
      process: json['process'] as String?,
      partNo: json['partNo'] as String?,
      quantity: json['quantity'] as int?,
      finish: json['finish'] as String?,
      tolerance: json['tolerance'] as String?,
      extra: Map<String, dynamic>.from(json)
        ..removeWhere((key, _) => knownKeys.contains(key)),
    );
  }
}

class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get right => x + width;
  double get bottom => y + height;
}

sealed class ResolvedObject {
  final String id;
  Meta meta;
  final Map<String, Point2D> anchors;
  List<ResolvedTransformOp> transforms;

  ResolvedObject({
    required this.id,
    required this.meta,
    Map<String, Point2D>? anchors,
    this.transforms = const [],
  }) : anchors = anchors ?? {};
}

class ResolvedPoint extends ResolvedObject {
  final double x;
  final double y;

  ResolvedPoint({
    required super.id,
    required super.meta,
    required this.x,
    required this.y,
    super.anchors,
    super.transforms,
  });
}

class ResolvedLine extends ResolvedObject {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  ResolvedLine({
    required super.id,
    required super.meta,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    super.anchors,
    super.transforms,
  });
}

class ResolvedRect extends ResolvedObject {
  final double x;
  final double y;
  final double width;
  final double height;
  final List<ResolvedHole> holes;

  ResolvedRect({
    required super.id,
    required super.meta,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.holes = const [],
    super.anchors,
    super.transforms,
  });
}

class ResolvedCircle extends ResolvedObject {
  final double cx;
  final double cy;
  final double radius;
  final List<ResolvedHole> holes;

  ResolvedCircle({
    required super.id,
    required super.meta,
    required this.cx,
    required this.cy,
    required this.radius,
    this.holes = const [],
    super.anchors,
    super.transforms,
  });
}

class ResolvedEllipse extends ResolvedObject {
  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double rotation;
  final List<ResolvedHole> holes;

  ResolvedEllipse({
    required super.id,
    required super.meta,
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    this.rotation = 0.0,
    this.holes = const [],
    super.anchors,
    super.transforms,
  });
}

class ResolvedArc extends ResolvedObject {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double cx;
  final double cy;
  final double radius;
  final double startAngle;
  final double endAngle;
  final int sweep; // 0 | 1
  final int largeArc; // 0 | 1

  ResolvedArc({
    required super.id,
    required super.meta,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.startAngle,
    required this.endAngle,
    required this.sweep,
    required this.largeArc,
    super.anchors,
    super.transforms,
  });
}

class ResolvedQuadratic extends ResolvedObject {
  final double x1;
  final double y1;
  final double cpx;
  final double cpy;
  final double x2;
  final double y2;

  ResolvedQuadratic({
    required super.id,
    required super.meta,
    required this.x1,
    required this.y1,
    required this.cpx,
    required this.cpy,
    required this.x2,
    required this.y2,
    super.anchors,
    super.transforms,
  });
}

class ResolvedCubic extends ResolvedObject {
  final double x1;
  final double y1;
  final double cp1x;
  final double cp1y;
  final double cp2x;
  final double cp2y;
  final double x2;
  final double y2;

  ResolvedCubic({
    required super.id,
    required super.meta,
    required this.x1,
    required this.y1,
    required this.cp1x,
    required this.cp1y,
    required this.cp2x,
    required this.cp2y,
    required this.x2,
    required this.y2,
    super.anchors,
    super.transforms,
  });
}

sealed class PathResolvedSegment {}

class LineSegment extends PathResolvedSegment {
  final double x1, y1, x2, y2;
  LineSegment(this.x1, this.y1, this.x2, this.y2);
}

class ArcSegment extends PathResolvedSegment {
  final double x1, y1, x2, y2, cx, cy, radius;
  final int sweep;
  final int largeArc;
  ArcSegment({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.sweep,
    required this.largeArc,
  });
}

class QuadraticSegment extends PathResolvedSegment {
  final double x1, y1, cpx, cpy, x2, y2;
  QuadraticSegment(this.x1, this.y1, this.cpx, this.cpy, this.x2, this.y2);
}

class CubicSegment extends PathResolvedSegment {
  final double x1, y1, cp1x, cp1y, cp2x, cp2y, x2, y2;
  CubicSegment(
    this.x1,
    this.y1,
    this.cp1x,
    this.cp1y,
    this.cp2x,
    this.cp2y,
    this.x2,
    this.y2,
  );
}

class ResolvedHole {
  final List<PathResolvedSegment> segments;
  ResolvedHole(this.segments);
}

class ResolvedPath extends ResolvedObject {
  final List<Point2D> points;
  final List<PathResolvedSegment> segments;
  final bool closed;
  final List<ResolvedHole> holes;

  ResolvedPath({
    required super.id,
    required super.meta,
    this.points = const [],
    this.segments = const [],
    this.closed = false,
    this.holes = const [],
    super.anchors,
    super.transforms,
  });
}

class ResolvedPolygon extends ResolvedObject {
  final List<Point2D> points;
  final List<PathResolvedSegment> segments;
  final List<ResolvedHole> holes;

  ResolvedPolygon({
    required super.id,
    required super.meta,
    required this.points,
    this.segments = const [],
    this.holes = const [],
    super.anchors,
    super.transforms,
  });
}

class ResolvedBoolean extends ResolvedObject {
  final String operation; // union | subtract | intersect | xor
  final List<Point2D> points;
  final List<PathResolvedSegment> segments;
  final List<ResolvedHole> holes;

  ResolvedBoolean({
    required super.id,
    required super.meta,
    required this.operation,
    this.points = const [],
    this.segments = const [],
    this.holes = const [],
    super.anchors,
    super.transforms,
  });
}

class ResolvedText extends ResolvedObject {
  final double x;
  final double y;
  final double width;
  final double height;
  final String content;
  final String anchor; // topLeft, center, etc.

  ResolvedText({
    required super.id,
    required super.meta,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.content,
    this.anchor = 'topLeft',
    super.anchors,
    super.transforms,
  });
}

class ResolvedDimension extends ResolvedObject {
  final String kind; // linear | radius | diameter | angle
  final Point2D? fromPoint;
  final Point2D? toPoint;
  final double offset;
  final String? target;
  final List<String> between;
  final String text;
  final double? distance;
  final double? angle;

  ResolvedDimension({
    required super.id,
    required super.meta,
    required this.kind,
    this.fromPoint,
    this.toPoint,
    this.offset = 0.0,
    this.target,
    this.between = const [],
    required this.text,
    this.distance,
    this.angle,
    super.anchors,
    super.transforms,
  });
}

class ResolvedAnnotation extends ResolvedObject {
  final String? target;
  final String text;
  final ({Point2D fromPoint, Point2D toPoint})? leader;

  ResolvedAnnotation({
    required super.id,
    required super.meta,
    this.target,
    required this.text,
    this.leader,
    super.anchors,
    super.transforms,
  });
}

sealed class BaseResolvedGroup extends ResolvedObject {
  final List<String> children;

  BaseResolvedGroup({
    required super.id,
    required super.meta,
    required this.children,
    super.anchors,
    super.transforms,
  });
}

class ResolvedGroup extends BaseResolvedGroup {
  ResolvedGroup({
    required super.id,
    required super.meta,
    required super.children,
    super.anchors,
    super.transforms,
  });
}

class ResolvedClone extends BaseResolvedGroup {
  final String of;

  ResolvedClone({
    required super.id,
    required super.meta,
    required super.children,
    required this.of,
    super.anchors,
    super.transforms,
  });
}

class ResolvedCollection extends BaseResolvedGroup {
  ResolvedCollection({
    required super.id,
    required super.meta,
    required super.children,
    super.anchors,
    super.transforms,
  });
}

class ResolvedComponent extends BaseResolvedGroup {
  final bool hasExports;

  ResolvedComponent({
    required super.id,
    required super.meta,
    required super.children,
    required this.hasExports,
    super.anchors,
    super.transforms,
  });
}

sealed class ResolvedTransformOp {}

class TranslateOp extends ResolvedTransformOp {
  final double x, y;
  TranslateOp(this.x, this.y);
}

class RotateOp extends ResolvedTransformOp {
  final double angle;
  final Point2D origin;
  RotateOp(this.angle, this.origin);
}

class ScaleOp extends ResolvedTransformOp {
  final double sx, sy;
  final Point2D origin;
  ScaleOp(this.sx, this.sy, this.origin);
}

class MirrorOp extends ResolvedTransformOp {
  final String axis; // x | y | both
  final Point2D origin;
  MirrorOp(this.axis, this.origin);
}

class ResolvedSheetView {
  final String use;
  final double x;
  final double y;
  final double width;
  final double height;

  ResolvedSheetView({
    required this.use,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class ResolvedSheet {
  final String id;
  final dynamic size; // String | (double, double)
  final double width;
  final double height;
  final List<ResolvedSheetView> views;
  final Meta? meta;

  ResolvedSheet({
    required this.id,
    required this.size,
    required this.width,
    required this.height,
    required this.views,
    this.meta,
  });
}

class ResolvedView {
  final String id;
  final String target;
  final dynamic scale; // String | double
  final double scaleFactor;
  final Map<String, ResolvedObject> objects;
  final BoundingBox bbox;
  final Meta? meta;

  ResolvedView({
    required this.id,
    required this.target,
    required this.scale,
    required this.scaleFactor,
    required this.objects,
    required this.bbox,
    this.meta,
  });
}

class ConstraintViolation {
  final String type; // align | equal | parallel | perpendicular | tangent
  final String message;
  final double deviation;
  final String path;
  final List<String> involvedObjects;
  final ({double x1, double y1, double x2, double y2})? visualHelper;

  ConstraintViolation({
    required this.type,
    required this.message,
    required this.deviation,
    required this.path,
    required this.involvedObjects,
    this.visualHelper,
  });
}

class ResolvedScene {
  final LengthUnit unit;
  final Orientation orientation;
  final Origin origin;
  final bool autoSize;
  final double padding;
  final Map<String, ResolvedObject> objects;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> values;
  final BoundingBox bbox;
  final Meta? meta;
  final List<ConstraintViolation> violations;
  final Map<String, ResolvedSheet> sheets;
  final Map<String, ResolvedView> views;

  ResolvedScene({
    required this.unit,
    this.orientation = Orientation.yDown,
    this.origin = Origin.topLeft,
    this.autoSize = true,
    this.padding = 20.0,
    required this.objects,
    required this.parameters,
    required this.values,
    required this.bbox,
    this.meta,
    this.violations = const [],
    this.sheets = const {},
    this.views = const {},
  });
}
