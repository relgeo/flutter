import '../geometry/types.dart';

typedef HierarchyPrimitiveRenderer = void Function(ResolvedObject obj, Meta meta);
typedef HierarchyTransformScope = void Function(
  List<ResolvedTransformOp> transforms,
  void Function() renderChild,
);
typedef HierarchyRolePredicate = bool Function(String role);

class RenderHierarchy {
  static List<String> rootObjectIds(Map<String, ResolvedObject> objects) {
    final childIds = <String>{};
    for (final obj in objects.values) {
      if (obj is BaseResolvedGroup) {
        childIds.addAll(obj.children);
      }
    }
    return objects.keys.where((id) => !childIds.contains(id)).toList();
  }

  static void renderRootedObjects({
    required Map<String, ResolvedObject> objects,
    Map<String, ResolvedObject>? objectLookup,
    required HierarchyRolePredicate shouldRenderRole,
    required HierarchyPrimitiveRenderer renderPrimitive,
    required HierarchyTransformScope withTransformScope,
  }) {
    final lookup = objectLookup ?? objects;

    void renderWithNodeTransform(
      List<ResolvedTransformOp> transforms,
      void Function() renderChild,
    ) {
      if (transforms.isEmpty) {
        renderChild();
        return;
      }
      withTransformScope(transforms, renderChild);
    }

    void renderNode(
      ResolvedObject obj, {
      Meta? metaOverride,
      bool isCloneDescendant = false,
    }) {
      final effectiveMeta = metaOverride == null
          ? obj.meta
          : (isCloneDescendant
              ? mergeCloneDescendantMeta(obj.meta, metaOverride)
              : mergeInheritedMeta(metaOverride, obj.meta));

      if (!effectiveMeta.visible || !shouldRenderRole(effectiveMeta.role)) return;

      switch (obj) {
        case ResolvedClone():
          final targetObj = lookup[obj.of];
          if (targetObj == null) return;
          renderWithNodeTransform(
            obj.transforms,
            () => renderNode(
              targetObj,
              metaOverride: effectiveMeta,
              isCloneDescendant: true,
            ),
          );
        case BaseResolvedGroup():
          renderWithNodeTransform(obj.transforms, () {
            for (final childId in obj.children) {
              final child = lookup[childId];
              if (child == null) continue;
              renderNode(
                child,
                metaOverride: effectiveMeta,
              );
            }
          });
        default:
          renderPrimitive(obj, effectiveMeta);
      }
    }

    for (final rootId in rootObjectIds(objects)) {
      final obj = lookup[rootId];
      if (obj == null) continue;
      renderNode(obj);
    }
  }

  static Meta mergeInheritedMeta(Meta parent, Meta child) {
    return Meta(
      visible: parent.visible && child.visible,
      stroke: child.stroke ?? parent.stroke,
      fill: child.fill ?? parent.fill,
      strokeWidth: child.strokeWidth ?? parent.strokeWidth,
      opacity: (parent.opacity != null && child.opacity != null)
          ? parent.opacity! * child.opacity!
          : (child.opacity ?? parent.opacity),
      label: child.label ?? parent.label,
      role: child.role != 'final' ? child.role : parent.role,
      layer: child.layer ?? parent.layer,
      dash: child.dash ?? parent.dash,
      material: child.material ?? parent.material,
      thickness: child.thickness ?? parent.thickness,
      process: child.process ?? parent.process,
      partNo: child.partNo ?? parent.partNo,
      quantity: child.quantity ?? parent.quantity,
      finish: child.finish ?? parent.finish,
      tolerance: child.tolerance ?? parent.tolerance,
      extra: {
        ...parent.extra,
        ...child.extra,
      },
    );
  }

  static Meta mergeCloneDescendantMeta(Meta target, Meta cloneMeta) {
    return Meta(
      visible: target.visible && cloneMeta.visible,
      stroke: cloneMeta.stroke ?? target.stroke,
      fill: cloneMeta.fill ?? target.fill,
      strokeWidth: cloneMeta.strokeWidth ?? target.strokeWidth,
      opacity: (cloneMeta.opacity != null && target.opacity != null)
          ? cloneMeta.opacity! * target.opacity!
          : (cloneMeta.opacity ?? target.opacity),
      label: cloneMeta.label ?? target.label,
      role: cloneMeta.role != 'final' ? cloneMeta.role : target.role,
      layer: cloneMeta.layer ?? target.layer,
      dash: cloneMeta.dash ?? target.dash,
      material: cloneMeta.material ?? target.material,
      thickness: cloneMeta.thickness ?? target.thickness,
      process: cloneMeta.process ?? target.process,
      partNo: cloneMeta.partNo ?? target.partNo,
      quantity: cloneMeta.quantity ?? target.quantity,
      finish: cloneMeta.finish ?? target.finish,
      tolerance: cloneMeta.tolerance ?? target.tolerance,
      extra: {
        ...target.extra,
        ...cloneMeta.extra,
      },
    );
  }

  static String? transformToSvg(List<ResolvedTransformOp> transforms) {
    if (transforms.isEmpty) return null;
    final parts = <String>[];
    for (final op in transforms) {
      switch (op) {
        case TranslateOp(:final x, :final y):
          parts.add('translate($x, $y)');
        case RotateOp(:final angle, :final origin):
          parts.add('translate(${origin.x}, ${origin.y})');
          parts.add('rotate($angle)');
          parts.add('translate(${-origin.x}, ${-origin.y})');
        case ScaleOp(:final sx, :final sy, :final origin):
          parts.add('translate(${origin.x}, ${origin.y})');
          parts.add('scale($sx, $sy)');
          parts.add('translate(${-origin.x}, ${-origin.y})');
        case MirrorOp(:final axis, :final origin):
          parts.add('translate(${origin.x}, ${origin.y})');
          if (axis.toLowerCase() == 'x') {
            parts.add('scale(1, -1)');
          } else {
            parts.add('scale(-1, 1)');
          }
          parts.add('translate(${-origin.x}, ${-origin.y})');
      }
    }
    return parts.join(' ');
  }
}
