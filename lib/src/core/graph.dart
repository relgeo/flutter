/// Engine topological sorting (Toposort) dan deteksi siklus dependensi RelGeo.
///
/// Modul ini menganalisis hubungan relasional antara variabel (derived) dan
/// objek geometri, lalu menyusun urutan evaluasi deterministik yang aman dari loop.
library;

const Set<String> knownFunctions = {
  "min",
  "max",
  "abs",
  "clamp",
  "sin",
  "cos",
  "tan",
  "sqrt",
  "pow",
  "round",
  "floor",
  "ceil",
  "distance",
  "length",
  "perimeter",
  "area",
  "bbox",
  "midpoint",
  "polar",
  "angleBetween",
  "width",
  "height",
  "minX",
  "maxX",
  "minY",
  "maxY",
  "pointAt",
  "closestPoint",
  "project",
  "reflect",
  "toWorld",
  "toLocal",
  "intersection",
  "tangentAt",
  "normalAt",
  "frameAt",
  "tAtLength",
};

class CircularDependencyException implements Exception {
  final String message;
  final String startId;
  final String chain;

  CircularDependencyException(this.message, this.startId, this.chain);

  @override
  String toString() => 'CircularDependencyException: $message';
}

List<String> getExpressionIdentifiers(String expr) {
  final Set<String> deps = {};
  final matches = RegExp(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b').allMatches(expr);
  for (final m in matches) {
    final id = m.group(0)!;
    if (knownFunctions.contains(id)) continue;
    deps.add(id);
  }
  return deps.toList();
}

List<String> extractObjectRefs(dynamic value, Set<String> objectIds) {
  if (value is List) {
    final List<String> refs = [];
    for (final item in value) {
      refs.addAll(extractObjectRefs(item, objectIds));
    }
    return refs.toSet().toList();
  }

  if (value is Map) {
    final List<String> refs = [];
    for (final item in value.values) {
      refs.addAll(extractObjectRefs(item, objectIds));
    }
    return refs.toSet().toList();
  }

  if (value is! String) return [];

  // Bersihkan literal string untuk menghindari deteksi palsu
  final cleaned = value.replaceAll(RegExp(r''''[^']*'|"[^"]*"'''), "");
  final List<String> refs = [];

  for (final id in objectIds) {
    final pattern = RegExp('\\b${RegExp.escape(id)}\\b');
    if (pattern.hasMatch(cleaned) && !knownFunctions.contains(id)) {
      refs.add(id);
    }
  }

  return refs;
}

bool isDescendant(
  String childId,
  String potentialParentId,
  Map<String, String> parentMap,
) {
  String? p = parentMap[childId];
  while (p != null) {
    if (p == potentialParentId) return true;
    p = parentMap[p];
  }
  return false;
}

void collectFromPlace(
  Map<dynamic, dynamic>? place,
  void Function(dynamic) addRef,
) {
  if (place == null) return;
  for (final val in place.values) {
    addRef(val);
  }
}

void collectFromOn(Map<dynamic, dynamic>? on, void Function(dynamic) addRef) {
  if (on == null) return;

  if (on.containsKey('point')) {
    final pt = on['point'];
    if (pt is Map) {
      addRef(pt['at']);
      addRef(pt['anchor']);
    }
  }
  if (on.containsKey('path')) {
    final pathSpec = on['path'];
    if (pathSpec is Map) {
      addRef(pathSpec['path']);
      addRef(pathSpec['t']);
      addRef(pathSpec['anchor']);
    }
  }
  if (on.containsKey('frame')) {
    final frameSpec = on['frame'];
    if (frameSpec is Map) {
      addRef(frameSpec['path']);
      addRef(frameSpec['t']);
      addRef(frameSpec['anchor']);
    }
  }
}

void addTransformDependencies(
  dynamic transform,
  void Function(dynamic) addRef,
) {
  if (transform == null) return;

  void addOpDeps(dynamic op) {
    if (op is! Map) return;
    if (op.containsKey('translate')) {
      final t = op['translate'];
      if (t is List && t.length >= 2) {
        addRef(t[0]);
        addRef(t[1]);
      }
    }
    if (op.containsKey('rotate')) {
      final r = op['rotate'];
      if (r is Map) {
        addRef(r['angle']);
        addRef(r['origin']);
      } else {
        addRef(r);
      }
    }
    if (op.containsKey('scale')) {
      final s = op['scale'];
      if (s is Map) {
        addRef(s['factor']);
        addRef(s['origin']);
      } else {
        addRef(s);
      }
    }
    if (op.containsKey('mirror')) {
      final m = op['mirror'];
      if (m is Map) {
        addRef(m['origin']);
      }
    }
    if (op.containsKey('origin')) {
      addRef(op['origin']);
    }
  }

  if (transform is List) {
    for (final op in transform) {
      addOpDeps(op);
    }
  } else {
    addOpDeps(transform);
  }
}

void addDeepDeps(dynamic obj, void Function(dynamic) addRef) {
  if (obj == null) return;
  if (obj is! Map && obj is! List) {
    addRef(obj);
    return;
  }
  if (obj is List) {
    for (final item in obj) {
      addDeepDeps(item, addRef);
    }
    return;
  }
  for (final val in obj.values) {
    addDeepDeps(val, addRef);
  }
}

List<String> getObjectDependencies(
  String id,
  Map<dynamic, dynamic> obj,
  Set<String> objectIds, [
  Map<String, String>? parentMap,
  Map<String, dynamic>? doc,
]) {
  final Set<String> deps = {};
  final type = obj['type']?.toString() ?? '';

  void addRef(dynamic val) {
    for (final refId in extractObjectRefs(val, objectIds)) {
      if (refId != id) {
        deps.add(refId);
        if (parentMap != null) {
          String? parent = parentMap[refId];
          while (parent != null) {
            if (parent != id && !isDescendant(id, parent, parentMap)) {
              deps.add(parent);
            }
            parent = parentMap[parent];
          }
        }
      }
    }
  }

  // 1. Ambil dependensi utama berdasarkan tipe objek geometri
  if (type == 'point') {
    addRef(obj['at']);
    addRef(obj['from']);
    collectFromOn(obj['on'] as Map?, addRef);
    final move = obj['move'];
    if (move is Map) {
      addRef(move['angle']);
      addRef(move['distance']);
      addRef(move['left']);
      addRef(move['right']);
      addRef(move['up']);
      addRef(move['down']);
    }
  } else if (type == 'line') {
    addRef(obj['from']);
    addRef(obj['to']);
    addRef(obj['length']);
    addRef(obj['direction']);
    final tangent = obj['tangent'];
    if (tangent is Map) {
      addRef(tangent['from']);
      addRef(tangent['to']);
    }
  } else if (type == 'rect') {
    final size = obj['size'];
    if (size is List && size.length >= 2) {
      addRef(size[0]);
      addRef(size[1]);
    }
    collectFromPlace(obj['place'] as Map?, addRef);
    addDeepDeps(obj['holes'], addRef);
  } else if (type == 'circle') {
    addRef(obj['center']);
    addRef(obj['radius']);
    addRef(obj['through']);
    collectFromPlace(obj['place'] as Map?, addRef);
    addDeepDeps(obj['holes'], addRef);
  } else if (type == 'arc') {
    addRef(obj['from']);
    addRef(obj['through']);
    addRef(obj['to']);
    addRef(obj['center']);
    addRef(obj['radius']);
    addRef(obj['startAngle']);
    addRef(obj['endAngle']);
    collectFromPlace(obj['place'] as Map?, addRef);
    addTransformDependencies(obj['transform'], addRef);
  } else if (type == 'quadratic' || type == 'cubic') {
    addRef(obj['from']);
    addRef(obj['to']);
    if (type == 'quadratic') {
      addRef(obj['cp']);
    } else {
      addRef(obj['cp1']);
      addRef(obj['cp2']);
    }
    collectFromPlace(obj['place'] as Map?, addRef);
    addTransformDependencies(obj['transform'], addRef);
  } else if (type == 'path' || type == 'polygon') {
    final points = obj['points'];
    if (points is List) {
      for (final pt in points) {
        addRef(pt);
      }
    }
    addDeepDeps(obj['holes'], addRef);
    if (type == 'path') {
      final segments = obj['segments'];
      if (segments is List) {
        for (final seg in segments) {
          if (seg is Map) {
            if (seg.containsKey('line')) addDeepDeps(seg['line'], addRef);
            if (seg.containsKey('arc')) addDeepDeps(seg['arc'], addRef);
            if (seg.containsKey('quadratic')) {
              addDeepDeps(seg['quadratic'], addRef);
            }
            if (seg.containsKey('cubic')) addDeepDeps(seg['cubic'], addRef);
          }
        }
      }
      final offset = obj['offset'];
      if (offset is Map) {
        addRef(offset['from']);
        addRef(offset['distance']);
      }
    }
    collectFromPlace(obj['place'] as Map?, addRef);
    addTransformDependencies(obj['transform'], addRef);
  } else if (type == 'component') {
    final extendsComp = obj['extends'];
    if (extendsComp is String && doc != null) {
      final components = doc['components'];
      if (components is Map && components.containsKey(extendsComp)) {
        final compDef = components[extendsComp];
        if (compDef is Map) {
          final compChildren = compDef['children'];
          if (compChildren is Map) {
            // Kita tidak perlu menambahkan children definition sebagai graph dependency
            // karena mereka di-resolve secara terpisah di ResolveContext komponen.
            // Namun, jika ada dependencies ke object global dari dalam komponen,
            // kita harus extract semuanya. (Ini adalah simple scan)
            final allRefs = extractObjectRefs(compDef, objectIds);
            for (final ref in allRefs) {
              if (ref != id) addRef(ref);
            }
          }
        }
      }
    }
    final children = obj['children'];
    if (children is List) {
      for (final c in children) {
        addRef(c);
      }
    }
    addTransformDependencies(obj['transform'], addRef);
    collectFromPlace(obj['place'] as Map?, addRef);
  } else if (type == 'group' || type == 'clone' || type == 'collection') {
    final children = obj['children'];
    if (children is List) {
      for (final c in children) {
        addRef(c);
      }
    }
    if (type == 'clone') {
      addRef(obj['of']);
    }
    addTransformDependencies(obj['transform'], addRef);
    collectFromPlace(obj['place'] as Map?, addRef);
  } else if (type == 'text') {
    addRef(obj['at']);
    final content = obj['content'];
    if (content is String) {
      final matches = RegExp(r'\{([^{}]+)\}').allMatches(content);
      for (final m in matches) {
        addRef(m.group(1)!.trim());
      }
    } else {
      addRef(content);
    }
    collectFromPlace(obj['place'] as Map?, addRef);
  } else if (type == 'repeat') {
    addRef(obj['count']);
    addRef(obj['each']);
    final grid = obj['grid'];
    if (grid is Map) {
      addRef(grid['rows']);
      addRef(grid['cols']);
      final gap = grid['gap'];
      if (gap is List) {
        addRef(gap[0]);
        addRef(gap[1]);
      } else {
        addRef(gap);
      }
    }
    final polar = obj['polar'];
    if (polar is Map) {
      addRef(polar['count']);
      addRef(polar['center']);
      addRef(polar['radius']);
    }
    addDeepDeps(obj['item'], addRef);
  } else if (type == 'divide') {
    addRef(obj['target']);
    addRef(obj['count']);
  } else if (type == 'dimension') {
    addRef(obj['from']);
    addRef(obj['to']);
    addRef(obj['offset']);
    addRef(obj['target']);
    final between = obj['between'];
    if (between is List) {
      for (final b in between) {
        addRef(b);
      }
    }
    final text = obj['text'];
    if (text is String) {
      final matches = RegExp(r'\{([^{}]+)\}').allMatches(text);
      for (final m in matches) {
        addRef(m.group(1)!.trim());
      }
    }
  } else if (type == 'annotation') {
    addRef(obj['target']);
    final leader = obj['leader'];
    if (leader is Map) {
      addRef(leader['from']);
      addRef(leader['to']);
    }
    collectFromPlace(obj['place'] as Map?, addRef);
  } else if (type == 'boolean') {
    addRef(obj['shapes']);
    addRef(obj['base']);
    addRef(obj['tools']);
    collectFromPlace(obj['place'] as Map?, addRef);
    addTransformDependencies(obj['transform'], addRef);
  }

  // 2. Scan peletakan "on" untuk objek geometri non-point
  if (obj.containsKey('on') && type != 'point') {
    collectFromOn(obj['on'] as Map?, addRef);
  }

  // 3. Scan custom anchors
  final anchors = obj['anchors'];
  if (anchors is Map) {
    for (final pos in anchors.values) {
      if (pos is List && pos.length >= 2) {
        addRef(pos[0]);
        addRef(pos[1]);
      }
    }
  }

  return deps.toList();
}

List<String> sortNodes(
  List<String> nodeIds,
  List<String> Function(String id) getDeps,
) {
  final List<String> sorted = [];
  final Set<String> visited = {};
  final Set<String> visiting = {};
  final Set<String> nodeSet = nodeIds.toSet();
  final List<String> stack = [];

  void visit(String id) {
    if (!nodeSet.contains(id)) return;

    if (visiting.contains(id)) {
      final cycleStartIdx = stack.indexOf(id);
      final chain = [...stack.sublist(cycleStartIdx), id];
      throw CircularDependencyException(
        'Circular dependency detected: ${chain.join(" -> ")}',
        id,
        chain.join(" -> "),
      );
    }

    if (visited.contains(id)) return;

    visiting.add(id);
    stack.add(id);

    for (final depId in getDeps(id)) {
      visit(depId);
    }

    stack.removeLast();
    visiting.remove(id);
    visited.add(id);
    sorted.add(id);
  }

  for (final id in nodeIds) {
    visit(id);
  }

  return sorted;
}

List<String> sortObjects(
  Map<String, dynamic> objects, [
  Map<String, dynamic>? doc,
]) {
  final objectIds = objects.keys.toSet();

  final parentMap = <String, String>{};
  for (final entry in objects.entries) {
    final obj = entry.value;
    if (obj is Map && obj['type'] == 'group') {
      final children = obj['children'];
      if (children is List) {
        for (final childId in children) {
          if (childId is String) {
            parentMap[childId] = entry.key;
          }
        }
      }
    }
  }

  return sortNodes(objectIds.toList(), (id) {
    final obj = objects[id];
    if (obj is! Map) return [];
    return getObjectDependencies(id, obj, objectIds, parentMap, doc);
  });
}

List<String> extractObjectRefsFromAny(
  dynamic val,
  Set<String> objectIds,
  Set<String> derivedIds,
) {
  if (val is String) {
    final List<String> refs = [];
    final identifiers = getExpressionIdentifiers(val);
    for (final id in identifiers) {
      if (objectIds.contains(id) || derivedIds.contains(id)) {
        refs.add(id);
      }
    }
    return refs;
  }
  if (val is List) {
    final List<String> refs = [];
    for (final item in val) {
      refs.addAll(extractObjectRefsFromAny(item, objectIds, derivedIds));
    }
    return refs;
  }
  if (val is Map) {
    final List<String> refs = [];
    for (final v in val.values) {
      refs.addAll(extractObjectRefsFromAny(v, objectIds, derivedIds));
    }
    return refs;
  }
  return [];
}

class UnifiedNode {
  final String kind; // 'object' | 'derived'
  final String id;

  UnifiedNode({required this.kind, required this.id});

  @override
  String toString() => 'UnifiedNode(kind: $kind, id: $id)';
}

List<UnifiedNode> sortUnified(
  Map<String, dynamic> objects,
  Map<String, dynamic> derived, [
  Map<String, dynamic>? doc,
]) {
  final objectIds = objects.keys.toSet();
  final derivedIds = derived.keys.toSet();

  String objKey(String id) => 'obj:$id';
  String drvKey(String id) => 'drv:$id';

  // Bangun parent map
  final parentMap = <String, String>{};
  for (final entry in objects.entries) {
    final obj = entry.value;
    if (obj is Map && obj['type'] == 'group') {
      final children = obj['children'];
      if (children is List) {
        for (final childId in children) {
          if (childId is String) {
            parentMap[childId] = entry.key;
          }
        }
      }
    }
  }

  final allNodes = [...objects.keys.map(objKey), ...derived.keys.map(drvKey)];

  List<String> getDeps(String prefixedId) {
    if (prefixedId.startsWith('obj:')) {
      final id = prefixedId.substring(4);
      final obj = objects[id];
      if (obj is! Map) return [];

      final objDeps = getObjectDependencies(
        id,
        obj,
        objectIds,
        parentMap,
        doc,
      ).map(objKey).toList();
      final allRefs = extractObjectRefsFromAny(obj, objectIds, derivedIds);
      final drvDeps = allRefs
          .where((ref) => derivedIds.contains(ref))
          .map(drvKey)
          .toList();
      return [...objDeps, ...drvDeps];
    } else {
      // drv:X
      final id = prefixedId.substring(4);
      final def = derived[id];
      final expr = (def is Map && def.containsKey('value'))
          ? def['value']
          : def;
      if (expr is! String) return [];

      final idents = getExpressionIdentifiers(expr);
      final drvDeps = idents
          .where((ref) => derivedIds.contains(ref) && ref != id)
          .map(drvKey)
          .toList();
      final objDeps = idents
          .where((ref) => objectIds.contains(ref))
          .map(objKey)
          .toList();
      return [...drvDeps, ...objDeps];
    }
  }

  final sortedPrefixed = sortNodes(allNodes, getDeps);

  return sortedPrefixed.map((prefixedId) {
    if (prefixedId.startsWith('obj:')) {
      return UnifiedNode(kind: 'object', id: prefixedId.substring(4));
    } else {
      return UnifiedNode(kind: 'derived', id: prefixedId.substring(4));
    }
  }).toList();
}
