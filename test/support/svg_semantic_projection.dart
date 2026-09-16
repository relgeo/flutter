import 'package:xml/xml.dart';

import 'semantic_projection.dart';

/// Projects the geometry-bearing part of an SVG and intentionally ignores
/// presentation policy such as background, styles, whitespace, and viewBox.
Map<String, dynamic> projectSvgSemantics(String svg) {
  final document = XmlDocument.parse(svg);
  final objects = <String, dynamic>{};

  for (final element in document.descendants.whereType<XmlElement>()) {
    final id = element.getAttribute('id');
    if (id == null || id.isEmpty) continue;
    if (!const {
      'line',
      'rect',
      'circle',
      'polygon',
      'path',
    }.contains(element.name.local)) {
      continue;
    }

    objects[id] = switch (element.name.local) {
      'line' => {
        'type': 'line',
        'x1': _attributeNumber(element, 'x1'),
        'y1': _attributeNumber(element, 'y1'),
        'x2': _attributeNumber(element, 'x2'),
        'y2': _attributeNumber(element, 'y2'),
      },
      'rect' => {
        'type': 'rect',
        'x': _attributeNumber(element, 'x'),
        'y': _attributeNumber(element, 'y'),
        'width': _attributeNumber(element, 'width'),
        'height': _attributeNumber(element, 'height'),
      },
      'circle' => {
        'type': 'circle',
        'cx': _attributeNumber(element, 'cx'),
        'cy': _attributeNumber(element, 'cy'),
        'radius': _attributeNumber(element, 'r'),
      },
      'polygon' => {
        'type': 'path',
        'subpaths': [_projectPolygonPath(element.getAttribute('points') ?? '')],
      },
      'path' => {
        'type': 'path',
        'subpaths': _projectPath(element.getAttribute('d') ?? ''),
      },
      _ => throw StateError('Unreachable SVG semantic projection branch.'),
    };
  }

  return {'objects': objects};
}

List<Map<String, dynamic>> _projectPolygonPath(String data) {
  final values = _numbers(data);
  if (values.length < 6 || values.length.isOdd) {
    throw FormatException('Invalid SVG polygon points.');
  }
  final points = [
    for (var index = 0; index < values.length; index += 2)
      {'x': values[index], 'y': values[index + 1]},
  ];
  return _canonicalizePath([
    for (var index = 0; index < points.length; index++)
      _line(points[index], points[(index + 1) % points.length]),
  ]);
}

void expectSvgSemanticEqual(String expected, String actual) {
  expectSemanticEqual(
    projectSvgSemantics(expected),
    projectSvgSemantics(actual),
  );
}

double _attributeNumber(XmlElement element, String name) {
  final value = element.getAttribute(name);
  if (value == null) {
    throw FormatException(
      'SVG element ${element.name.local} is missing $name.',
    );
  }
  return double.parse(value);
}

List<dynamic> _projectPath(String data) {
  final subpaths = <List<Map<String, dynamic>>>[];
  var current = <String, double>{};
  var start = <String, double>{};
  var active = <Map<String, dynamic>>[];

  void flush() {
    if (active.isEmpty) return;
    subpaths.add(_canonicalizePath(active));
    active = [];
  }

  final commandPattern = RegExp(r'([AaCcHhLlMmQqVvZz])([^AaCcHhLlMmQqVvZz]*)');
  for (final match in commandPattern.allMatches(data)) {
    final command = match.group(1)!;
    final values = _numbers(match.group(2)!);
    switch (command.toUpperCase()) {
      case 'M':
        if (values.length < 2 || values.length.isOdd) {
          throw FormatException('Invalid SVG move command: $command');
        }
        flush();
        for (var index = 0; index < values.length; index += 2) {
          final point = {'x': values[index], 'y': values[index + 1]};
          if (index == 0) {
            current = point;
            start = point;
          } else {
            active.add(_line(current, point));
            current = point;
          }
        }
      case 'L':
        if (values.length < 2 || values.length.isOdd) {
          throw FormatException('Invalid SVG line command: $command');
        }
        for (var index = 0; index < values.length; index += 2) {
          final point = {'x': values[index], 'y': values[index + 1]};
          active.add(_line(current, point));
          current = point;
        }
      case 'H':
        for (final value in values) {
          final point = {'x': value, 'y': current['y']!};
          active.add(_line(current, point));
          current = point;
        }
      case 'V':
        for (final value in values) {
          final point = {'x': current['x']!, 'y': value};
          active.add(_line(current, point));
          current = point;
        }
      case 'C':
        if (values.length < 6 || values.length % 6 != 0) {
          throw FormatException('Invalid SVG cubic command: $command');
        }
        for (var index = 0; index < values.length; index += 6) {
          final point = {'x': values[index + 4], 'y': values[index + 5]};
          active.add({
            'type': 'cubic',
            'x1': current['x'],
            'y1': current['y'],
            'cp1x': values[index],
            'cp1y': values[index + 1],
            'cp2x': values[index + 2],
            'cp2y': values[index + 3],
            'x2': point['x'],
            'y2': point['y'],
          });
          current = point;
        }
      case 'Q':
        if (values.length < 4 || values.length % 4 != 0) {
          throw FormatException('Invalid SVG quadratic command: $command');
        }
        for (var index = 0; index < values.length; index += 4) {
          final point = {'x': values[index + 2], 'y': values[index + 3]};
          active.add({
            'type': 'quadratic',
            'x1': current['x'],
            'y1': current['y'],
            'cpx': values[index],
            'cpy': values[index + 1],
            'x2': point['x'],
            'y2': point['y'],
          });
          current = point;
        }
      case 'A':
        if (values.length < 7 || values.length % 7 != 0) {
          throw FormatException('Invalid SVG arc command: $command');
        }
        for (var index = 0; index < values.length; index += 7) {
          final point = {'x': values[index + 5], 'y': values[index + 6]};
          active.add({
            'type': 'arc',
            'x1': current['x'],
            'y1': current['y'],
            'rx': values[index],
            'ry': values[index + 1],
            'rotation': values[index + 2],
            'largeArc': values[index + 3],
            'sweep': values[index + 4],
            'x2': point['x'],
            'y2': point['y'],
          });
          current = point;
        }
      case 'Z':
        if (current.isNotEmpty &&
            start.isNotEmpty &&
            !_samePoint(current, start)) {
          active.add(_line(current, start));
        }
        current = start;
      default:
        throw FormatException('Unsupported SVG path command: $command');
    }
  }
  flush();
  return subpaths;
}

List<double> _numbers(String value) {
  return [
    for (final match in RegExp(
      r'[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?',
    ).allMatches(value))
      double.parse(match.group(0)!),
  ];
}

Map<String, dynamic> _line(Map<String, double> from, Map<String, double> to) {
  return {
    'type': 'line',
    'x1': from['x'],
    'y1': from['y'],
    'x2': to['x'],
    'y2': to['y'],
  };
}

List<Map<String, dynamic>> _canonicalizePath(
  List<Map<String, dynamic>> segments,
) {
  final normalized = [
    for (final segment in segments)
      if (!_isDegenerateLine(segment)) segment,
  ];
  if (normalized.length < 2) return normalized;

  final isClosed = _sameEndpoint(normalized.last, normalized.first);
  if (!isClosed || normalized.any((segment) => segment['type'] != 'line')) {
    return normalized;
  }

  final variants = <List<Map<String, dynamic>>>[];
  for (var index = 0; index < normalized.length; index++) {
    variants.add(_rotate(normalized, index));
  }
  final reversed = [
    for (final segment in normalized.reversed) _reverseLine(segment),
  ];
  for (var index = 0; index < reversed.length; index++) {
    variants.add(_rotate(reversed, index));
  }
  variants.sort(
    (left, right) => _pathSignature(left).compareTo(_pathSignature(right)),
  );
  return variants.first;
}

List<Map<String, dynamic>> _rotate(
  List<Map<String, dynamic>> segments,
  int start,
) {
  return [
    for (var offset = 0; offset < segments.length; offset++)
      segments[(start + offset) % segments.length],
  ];
}

Map<String, dynamic> _reverseLine(Map<String, dynamic> segment) {
  return {
    ...segment,
    'x1': segment['x2'],
    'y1': segment['y2'],
    'x2': segment['x1'],
    'y2': segment['y1'],
  };
}

bool _sameEndpoint(Map<String, dynamic> left, Map<String, dynamic> right) {
  return _samePoint(
    {'x': left['x2'], 'y': left['y2']},
    {'x': right['x1'], 'y': right['y1']},
  );
}

bool _samePoint(Map<String, dynamic> left, Map<String, dynamic> right) {
  return left['x'] == right['x'] && left['y'] == right['y'];
}

bool _isDegenerateLine(Map<String, dynamic> segment) {
  return segment['type'] == 'line' &&
      segment['x1'] == segment['x2'] &&
      segment['y1'] == segment['y2'];
}

String _pathSignature(List<Map<String, dynamic>> segments) {
  return segments.map((segment) => segment.toString()).join('|');
}
