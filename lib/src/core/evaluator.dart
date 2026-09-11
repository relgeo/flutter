/// Mesin Parser Ekspresi Matematika dan Evaluator Dinamis RelGeo.
///
/// Berkas ini mengimplementasikan parser rekursif (recursive descent parser) murni
/// yang mendukung aritmatika, boolean, ternary, pemanggilan fungsi standard math,
/// dan seluruh fungsi geometri bawaan RelGeo (seperti distance, pointAt, intersection, dll.).

import 'dart:math' as math;
import '../geometry/types.dart';
import '../geometry/utils.dart' as geom;
import '../geometry/intersection.dart';
import '../geometry/transforms.dart' as tfm;
import 'units.dart';

double _hypot(double x, double y) => math.sqrt(x * x + y * y);

class TypedValue {
  final String
  type; // 'number' | 'length' | 'point' | 'vector' | 'object' | 'array' | 'collection' | 'frame2d' | 'bbox2d' | 'boolean' | 'string'
  final dynamic value;

  TypedValue({required this.type, required this.value});

  @override
  String toString() => 'TypedValue(type: $type, value: $value)';
}

abstract class EvalContext {
  Map<String, dynamic> get scalars;
  LengthUnit get targetUnit;
  Map<String, ResolvedObject>? get objects;
  Map<String, String>? get parentMap;

  TypedValue? get(String name);
  TypedValue? getMember(TypedValue value, String key);
  TypedValue? getIndex(TypedValue value, dynamic index);
  TypedValue? callFunction(String name, List<TypedValue> args);
  dynamic resolveIdentifier(String name);
}

class SimpleEvalContext extends EvalContext {
  @override
  final Map<String, dynamic> scalars;
  @override
  final LengthUnit targetUnit;
  @override
  final Map<String, ResolvedObject>? objects;
  @override
  final Map<String, String>? parentMap;

  SimpleEvalContext({
    required this.scalars,
    this.targetUnit = LengthUnit.px,
    this.objects,
    this.parentMap,
  });

  @override
  TypedValue? get(String name) {
    if (scalars.containsKey(name)) {
      return wrap(scalars[name]);
    }
    return null;
  }

  @override
  TypedValue? getMember(TypedValue value, String key) {
    final val = value.value;
    if (val is Map && val.containsKey(key)) {
      return wrap(val[key]);
    }
    if (value.type == 'point') {
      final p = val as Point2D;
      if (key == 'x') return wrap(p.x);
      if (key == 'y') return wrap(p.y);
    }
    return null;
  }

  @override
  TypedValue? getIndex(TypedValue value, dynamic index) {
    if (value.type == 'array' || value.type == 'collection') {
      final list = value.value as List;
      final idx = index is num ? index.toInt() : int.parse(index.toString());
      if (idx >= 0 && idx < list.length) {
        return wrap(list[idx]);
      }
    }
    return null;
  }

  @override
  TypedValue? callFunction(String name, List<TypedValue> args) {
    return null;
  }

  @override
  dynamic resolveIdentifier(String name) {
    if (scalars.containsKey(name)) {
      return scalars[name];
    }
    return null;
  }
}

TypedValue wrap(dynamic val) {
  if (val is TypedValue) return val;
  if (val is num) return TypedValue(type: 'number', value: val.toDouble());
  if (val is bool) return TypedValue(type: 'boolean', value: val);
  if (val is String) return TypedValue(type: 'string', value: val);
  if (val is Point2D) return TypedValue(type: 'point', value: val);
  if (val is List) return TypedValue(type: 'array', value: val);
  if (val is Map) return TypedValue(type: 'object', value: val);
  return TypedValue(type: 'object', value: val);
}

dynamic unwrap(dynamic val) {
  if (val is TypedValue) return val.value;
  return val;
}

class Evaluator {
  final EvalContext context;
  final bool allowUnknownIdentifiers;
  final bool allowUnknownGeometryObjects;

  List<String> _tokens = [];
  int _pos = 0;

  Evaluator(
    this.context, {
    this.allowUnknownIdentifiers = false,
    this.allowUnknownGeometryObjects = false,
  });

  dynamic evaluate(dynamic expression) {
    if (expression is num) return expression.toDouble();
    if (expression == null) return null;

    final String exprStr = expression.toString().trim();
    if (exprStr.isEmpty) return 0.0;

    _tokens = tokenize(exprStr);
    _pos = 0;

    if (_tokens.isEmpty) return 0.0;

    final result = parseExpression();
    if (_pos != _tokens.length) {
      throw Exception('Unexpected token: ${_tokens[_pos]} at position $_pos');
    }

    return unwrap(result);
  }

  TypedValue evaluateTyped(dynamic expression) {
    if (expression is num) {
      return TypedValue(type: 'number', value: expression.toDouble());
    }

    final String exprStr = expression.toString().trim();
    if (exprStr.isEmpty) {
      return TypedValue(type: 'number', value: 0.0);
    }

    _tokens = tokenize(exprStr);
    _pos = 0;

    if (_tokens.isEmpty) {
      return TypedValue(type: 'number', value: 0.0);
    }

    final result = parseExpression();
    if (_pos != _tokens.length) {
      throw Exception('Unexpected token: ${_tokens[_pos]}');
    }

    return result;
  }

  List<String> tokenize(String expr) {
    final tokens = <String>[];
    var i = 0;

    bool isDigit(String ch) => RegExp(r'^\d$').hasMatch(ch);
    bool isIdentifierStart(String ch) => RegExp(r'^[a-zA-Z_]$').hasMatch(ch);
    bool isIdentifierPart(String ch) => RegExp(r'^[a-zA-Z0-9_]$').hasMatch(ch);

    while (i < expr.length) {
      final ch = expr[i];

      if (RegExp(r'^\s$').hasMatch(ch)) {
        i++;
        continue;
      }

      if (ch == '"' || ch == "'") {
        final quote = ch;
        final buffer = StringBuffer()..write(quote);
        i++;
        var closed = false;
        while (i < expr.length) {
          final current = expr[i];
          buffer.write(current);
          i++;
          if (current == r'\' && i < expr.length) {
            buffer.write(expr[i]);
            i++;
            continue;
          }
          if (current == quote) {
            closed = true;
            break;
          }
        }
        if (!closed) {
          throw Exception('Unterminated string literal: $expr');
        }
        tokens.add(buffer.toString());
        continue;
      }

      if (i + 1 < expr.length) {
        final two = expr.substring(i, i + 2);
        if (const {'==', '!=', '<=', '>=', '&&', '||'}.contains(two)) {
          tokens.add(two);
          i += 2;
          continue;
        }
      }

      if (isDigit(ch)) {
        var j = i + 1;
        while (j < expr.length && isDigit(expr[j])) {
          j++;
        }
        if (j < expr.length && expr[j] == '.') {
          j++;
          while (j < expr.length && isDigit(expr[j])) {
            j++;
          }
        }
        while (j < expr.length && RegExp(r'^[a-zA-Z%]$').hasMatch(expr[j])) {
          j++;
        }
        tokens.add(expr.substring(i, j));
        i = j;
        continue;
      }

      if (isIdentifierStart(ch)) {
        var j = i + 1;
        while (j < expr.length && isIdentifierPart(expr[j])) {
          j++;
        }
        tokens.add(expr.substring(i, j));
        i = j;
        continue;
      }

      if ('-+*/(),:{}[].<>?%^!'.contains(ch)) {
        tokens.add(ch);
        i++;
        continue;
      }

      throw Exception('Invalid expression syntax: $expr');
    }

    return tokens;
  }

  TypedValue parseExpression() {
    return parseTernary();
  }

  TypedValue parseTernary() {
    var result = parseLogicalOr();
    if (_pos < _tokens.length && _tokens[_pos] == '?') {
      _pos++;
      final trueVal = parseExpression();
      if (_pos >= _tokens.length || _tokens[_pos] != ':') {
        throw Exception("Expected ':' in ternary operator");
      }
      _pos++;
      final falseVal = parseExpression();
      final cond = unwrap(result);
      result = (cond == true) ? trueVal : falseVal;
    }
    return result;
  }

  TypedValue parseLogicalOr() {
    var result = parseLogicalAnd();
    while (_pos < _tokens.length && _tokens[_pos] == '||') {
      _pos++;
      final right = parseLogicalAnd();
      result = TypedValue(
        type: 'boolean',
        value: (unwrap(result) == true) || (unwrap(right) == true),
      );
    }
    return result;
  }

  TypedValue parseLogicalAnd() {
    var result = parseEquality();
    while (_pos < _tokens.length && _tokens[_pos] == '&&') {
      _pos++;
      final right = parseEquality();
      result = TypedValue(
        type: 'boolean',
        value: (unwrap(result) == true) && (unwrap(right) == true),
      );
    }
    return result;
  }

  TypedValue parseEquality() {
    var result = parseRelational();
    while (_pos < _tokens.length) {
      final token = _tokens[_pos];
      if (token == '==' || token == '!=') {
        _pos++;
        final right = parseRelational();
        final lVal = unwrap(result);
        final rVal = unwrap(right);
        if (token == '==') {
          result = TypedValue(type: 'boolean', value: lVal == rVal);
        } else {
          result = TypedValue(type: 'boolean', value: lVal != rVal);
        }
      } else {
        break;
      }
    }
    return result;
  }

  TypedValue parseRelational() {
    var result = parseAdditive();
    while (_pos < _tokens.length) {
      final token = _tokens[_pos];
      if (token == '<' || token == '>' || token == '<=' || token == '>=') {
        _pos++;
        final right = parseAdditive();
        final lVal = unwrap(result);
        final rVal = unwrap(right);
        if (lVal is! num || rVal is! num) {
          throw Exception("Relational operators are only allowed on numbers");
        }
        if (token == '<') {
          result = TypedValue(type: 'boolean', value: lVal < rVal);
        } else if (token == '>') {
          result = TypedValue(type: 'boolean', value: lVal > rVal);
        } else if (token == '<=') {
          result = TypedValue(type: 'boolean', value: lVal <= rVal);
        } else if (token == '>=') {
          result = TypedValue(type: 'boolean', value: lVal >= rVal);
        }
      } else {
        break;
      }
    }
    return result;
  }

  TypedValue parseAdditive() {
    var result = parseTerm();
    while (_pos < _tokens.length) {
      final token = _tokens[_pos];
      if (token == '+' || token == '-') {
        _pos++;
        final term = parseTerm();
        final rVal = unwrap(result);
        final tVal = unwrap(term);
        if (rVal is! num || tVal is! num) {
          throw Exception(
            "Arithmetic operations are only allowed on numbers/lengths",
          );
        }
        result = TypedValue(
          type: 'number',
          value: token == '+' ? rVal + tVal : rVal - tVal,
        );
      } else {
        break;
      }
    }
    return result;
  }

  TypedValue parseTerm() {
    var result = parseExponentiation();
    while (_pos < _tokens.length) {
      final token = _tokens[_pos];
      if (token == '*' || token == '/' || token == '%') {
        _pos++;
        final factor = parseExponentiation();
        final rVal = unwrap(result);
        final fVal = unwrap(factor);
        if (rVal is! num || fVal is! num) {
          throw Exception(
            "Arithmetic operations are only allowed on numbers/lengths",
          );
        }
        if (token == '*') {
          result = TypedValue(type: 'number', value: rVal * fVal);
        } else if (token == '/') {
          if (fVal == 0) throw Exception("Division by zero");
          result = TypedValue(type: 'number', value: rVal / fVal);
        } else if (token == '%') {
          result = TypedValue(type: 'number', value: rVal % fVal);
        }
      } else {
        break;
      }
    }
    return result;
  }

  TypedValue parseExponentiation() {
    var result = parseFactor();
    while (_pos < _tokens.length && _tokens[_pos] == '^') {
      _pos++;
      final right = parseExponentiation();
      final lVal = unwrap(result);
      final rVal = unwrap(right);
      if (lVal is! num || rVal is! num) {
        throw Exception("Exponentiation is only allowed on numbers");
      }
      result = TypedValue(
        type: 'number',
        value: math.pow(lVal, rVal).toDouble(),
      );
    }
    return result;
  }

  TypedValue? tryReconstructAndResolve(String baseToken) {
    var path = baseToken;
    var lookAheadPos = _pos;

    while (lookAheadPos < _tokens.length) {
      if (_tokens[lookAheadPos] == '.') {
        if (lookAheadPos + 1 < _tokens.length) {
          final nextId = _tokens[lookAheadPos + 1];
          if (RegExp(r'^[a-zA-Z_]').hasMatch(nextId)) {
            path += "." + nextId;
            lookAheadPos += 2;
            final resolved = context.resolveIdentifier(path);
            if (resolved != null) {
              _pos = lookAheadPos;
              return wrap(resolved);
            }
          } else {
            break;
          }
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return null;
  }

  TypedValue parseFactor() {
    var result = parseBaseFactor();

    while (_pos < _tokens.length) {
      final nextToken = _tokens[_pos];
      if (nextToken == '.') {
        _pos++; // consume '.'
        final member = _tokens[_pos++];
        if (!RegExp(r'^[a-zA-Z_]').hasMatch(member)) {
          throw Exception("Expected member identifier after '.'");
        }
        result = evaluateMember(result, member);
      } else if (nextToken == '[') {
        _pos++; // consume '['
        final List<TypedValue> indexExpressions = [parseExpression()];
        while (_tokens[_pos] == ',') {
          _pos++; // consume ','
          indexExpressions.add(parseExpression());
        }
        if (_tokens[_pos++] != ']') {
          throw Exception("Missing closing bracket ']'");
        }
        result = evaluateIndex(
          result,
          indexExpressions.length == 1 ? indexExpressions[0] : indexExpressions,
        );
      } else {
        break;
      }
    }

    return result;
  }

  TypedValue evaluateMember(TypedValue obj, String member) {
    final val = context.getMember(obj, member);
    if (val != null) return val;

    final rawObj = obj.value;
    if (rawObj is Map && rawObj.containsKey(member)) {
      return wrap(rawObj[member]);
    }

    if (allowUnknownIdentifiers) {
      return TypedValue(type: 'number', value: 1.0);
    }
    throw Exception(
      'Cannot access member "$member" on value of type "${obj.type}"',
    );
  }

  TypedValue evaluateIndex(TypedValue arr, dynamic indexVal) {
    final unwrappedIdx = indexVal is List
        ? indexVal.map((idx) => unwrap(idx)).toList()
        : unwrap(indexVal);

    final val = context.getIndex(arr, unwrappedIdx);
    if (val != null) return val;

    if (unwrappedIdx is num) {
      final int idx = unwrappedIdx.toInt();
      if (arr.type == 'array' ||
          arr.type == 'collection' ||
          arr.value is List) {
        final list = arr.value as List;
        if (idx >= 0 && idx < list.length) {
          return wrap(list[idx]);
        }
        if (allowUnknownIdentifiers) {
          return TypedValue(type: 'number', value: 1.0);
        }
        throw Exception('Index $idx out of bounds');
      }
    }

    if (allowUnknownIdentifiers) {
      return TypedValue(type: 'number', value: 1.0);
    }
    throw Exception('Cannot index into value of type "${arr.type}"');
  }

  TypedValue parseBaseFactor() {
    final token = _tokens[_pos++];

    if ((token.startsWith('"') && token.endsWith('"')) ||
        (token.startsWith("'") && token.endsWith("'"))) {
      final inner = token.substring(1, token.length - 1);
      return TypedValue(
        type: 'string',
        value: inner
            .replaceAll(r'\"', '"')
            .replaceAll(r"\'", "'")
            .replaceAll(r'\\', r'\'),
      );
    }

    if (token == '(') {
      final result = parseExpression();
      if (_tokens[_pos++] != ')') {
        throw Exception("Missing closing parenthesis");
      }
      return result;
    }

    if (token == '-') {
      final factor = parseFactor();
      final val = unwrap(factor);
      if (val is! num) {
        throw Exception("Unary minus can only be applied to numbers");
      }
      return TypedValue(type: 'number', value: -val.toDouble());
    }

    if (token == '!') {
      final factor = parseFactor();
      final val = unwrap(factor);
      return TypedValue(type: 'boolean', value: val != true);
    }

    // Identifikator (variabel atau fungsi)
    if (RegExp(r'^[a-zA-Z_]').hasMatch(token)) {
      // Pemanggilan fungsi
      if (_pos < _tokens.length && _tokens[_pos] == '(') {
        _pos++; // consume '('

        // Penanganan fungsi geometri RelGeo bawaan
        final geoFunctions = {
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

        if (geoFunctions.contains(token)) {
          final List<String> args = [];

          String readGeoArg() {
            var content = "";
            var depth = 0;
            while (_pos < _tokens.length) {
              final next = _tokens[_pos];
              if (next == ',' && depth == 0) break;
              if (next == ')' && depth == 0) break;

              _pos++; // consume
              if (next == '(' || next == '[' || next == '{') {
                depth++;
              } else if (next == ')' || next == ']' || next == '}') {
                depth--;
              }
              content += next;
            }
            if (content.isEmpty) {
              throw Exception("Expected argument in geometry function $token");
            }
            return content;
          }

          if (_tokens[_pos] != ')') {
            args.add(readGeoArg());
            while (_tokens[_pos] == ',') {
              _pos++; // consume ','
              args.add(readGeoArg());
            }
          }
          if (_tokens[_pos] != ')') {
            throw Exception("Expected ')' after geometry function $token");
          }
          _pos++; // consume ')'

          if (context.objects == null) {
            if (allowUnknownGeometryObjects) {
              return TypedValue(type: 'number', value: 0.0);
            }
            throw Exception(
              "Cannot resolve geometry function \"$token\" without objects context",
            );
          }

          if (allowUnknownGeometryObjects) {
            if (token == 'frameAt') {
              return TypedValue(
                type: 'frame2d',
                value: {
                  'point': (x: 0.0, y: 0.0),
                  'tangent': (x: 1.0, y: 0.0),
                  'normal': (x: 0.0, y: 1.0),
                  'angle': 0.0,
                },
              );
            }
            if (token == 'bbox') {
              return TypedValue(
                type: 'bbox2d',
                value: {
                  'minX': 0.0,
                  'maxX': 0.0,
                  'minY': 0.0,
                  'maxY': 0.0,
                  'width': 0.0,
                  'height': 0.0,
                },
              );
            }
            if ({
              'midpoint',
              'polar',
              'pointAt',
              'closestPoint',
              'project',
              'reflect',
              'toWorld',
              'toLocal',
              'intersection',
            }.contains(token)) {
              return TypedValue(type: 'point', value: (x: 0.0, y: 0.0));
            }
            return TypedValue(type: 'number', value: 0.0);
          }

          ResolvedObject lookupObj(String id, String fnName) {
            final o = context.objects![id];
            if (o == null) {
              throw Exception("Unknown or invalid object in $fnName: $id");
            }
            return o;
          }

          dynamic computedVal;

          if (token == "distance") {
            final obj1 = lookupObj(args[0], "distance");
            final obj2 = lookupObj(args[1], "distance");
            final p1 = getPointFromObject(obj1);
            final p2 = getPointFromObject(obj2);
            computedVal = _hypot(p2.x - p1.x, p2.y - p1.y);
          } else if (token == "length") {
            final obj = lookupObj(args[0], "length");
            computedVal = getLengthFromObject(obj, args[0]);
          } else if (token == "perimeter") {
            final obj = lookupObj(args[0], "perimeter");
            computedVal = getPerimeterFromObject(obj, args[0]);
          } else if (token == "area") {
            final obj = lookupObj(args[0], "area");
            computedVal = getAreaFromObject(obj, args[0]);
          } else if (token == "bbox") {
            final obj = lookupObj(args[0], "bbox");
            final bbox = getBoundingBoxForObject(obj, args[0]);
            return TypedValue(
              type: 'bbox2d',
              value: {
                'minX': bbox.x,
                'maxX': bbox.x + bbox.width,
                'minY': bbox.y,
                'maxY': bbox.y + bbox.height,
                'width': bbox.width,
                'height': bbox.height,
              },
            );
          } else if (token == "width") {
            final obj = lookupObj(args[0], "width");
            computedVal = getBoundingBoxForObject(obj, args[0]).width;
          } else if (token == "height") {
            final obj = lookupObj(args[0], "height");
            computedVal = getBoundingBoxForObject(obj, args[0]).height;
          } else if (token == "minX") {
            final obj = lookupObj(args[0], "minX");
            computedVal = getBoundingBoxForObject(obj, args[0]).x;
          } else if (token == "maxX") {
            final obj = lookupObj(args[0], "maxX");
            final bbox = getBoundingBoxForObject(obj, args[0]);
            computedVal = bbox.x + bbox.width;
          } else if (token == "minY") {
            final obj = lookupObj(args[0], "minY");
            computedVal = getBoundingBoxForObject(obj, args[0]).y;
          } else if (token == "maxY") {
            final obj = lookupObj(args[0], "maxY");
            final bbox = getBoundingBoxForObject(obj, args[0]);
            computedVal = bbox.y + bbox.height;
          } else if (token == "midpoint") {
            final p1 = resolvePointLikeArg(args[0]);
            final p2 = resolvePointLikeArg(args[1]);
            computedVal = (x: (p1.x + p2.x) / 2.0, y: (p1.y + p2.y) / 2.0);
          } else if (token == "polar") {
            final center = resolvePointLikeArg(args[0]);
            final subEval = Evaluator(
              context,
              allowUnknownIdentifiers: allowUnknownIdentifiers,
              allowUnknownGeometryObjects: allowUnknownGeometryObjects,
            );
            final radius = (subEval.evaluate(args[1]) as num).toDouble();
            final angle = (subEval.evaluate(args[2]) as num).toDouble();
            computedVal = (
              x: center.x + radius * math.cos(angle),
              y: center.y + radius * math.sin(angle),
            );
          } else if (token == "angleBetween") {
            final p1 = resolvePointLikeArg(args[0]);
            final p2 = resolvePointLikeArg(args[1]);
            computedVal = math.atan2(p2.y - p1.y, p2.x - p1.x);
          } else if (token == "pointAt") {
            final obj = lookupObj(args[0], "pointAt");
            final subEval = Evaluator(
              context,
              allowUnknownIdentifiers: allowUnknownIdentifiers,
              allowUnknownGeometryObjects: allowUnknownGeometryObjects,
            );
            final t = (subEval.evaluate(args[1]) as num).toDouble();
            computedVal = getPointAtObject(obj, t, args[0]);
          } else if (token == "tangentAt") {
            final obj = lookupObj(args[0], "tangentAt");
            final subEval = Evaluator(
              context,
              allowUnknownIdentifiers: allowUnknownIdentifiers,
              allowUnknownGeometryObjects: allowUnknownGeometryObjects,
            );
            final t = (subEval.evaluate(args[1]) as num).toDouble();
            computedVal = getTangentAtObject(obj, t, args[0]);
          } else if (token == "normalAt") {
            final obj = lookupObj(args[0], "normalAt");
            final subEval = Evaluator(
              context,
              allowUnknownIdentifiers: allowUnknownIdentifiers,
              allowUnknownGeometryObjects: allowUnknownGeometryObjects,
            );
            final t = (subEval.evaluate(args[1]) as num).toDouble();
            computedVal = getNormalAtObject(obj, t, args[0]);
          } else if (token == "frameAt") {
            final obj = lookupObj(args[0], "frameAt");
            final subEval = Evaluator(
              context,
              allowUnknownIdentifiers: allowUnknownIdentifiers,
              allowUnknownGeometryObjects: allowUnknownGeometryObjects,
            );
            final t = (subEval.evaluate(args[1]) as num).toDouble();
            if (t < 0.0 || t > 1.0) {
              throw Exception(
                "FRAME_RESOLUTION_FAILED: parameter t must be between 0 and 1, got $t",
              );
            }
            final point = getPointAtObject(obj, t, args[0]);
            final tangent = getTangentAtObject(obj, t, args[0]);
            final normal = getNormalAtObject(obj, t, args[0]);
            final angle = math.atan2(tangent.y, tangent.x);
            return TypedValue(
              type: 'frame2d',
              value: {
                'point': point,
                'tangent': tangent,
                'normal': normal,
                'angle': angle,
              },
            );
          } else if (token == "closestPoint") {
            final refObj = lookupObj(args[0], "closestPoint");
            final targetObj = lookupObj(args[1], "closestPoint");
            final pRef = getPointFromObject(refObj);
            computedVal = getClosestPoint(pRef, targetObj, args[1]);
          } else if (token == "project") {
            final point = resolvePointLikeArg(args[0]);
            final targetObj = lookupObj(args[1], "project");
            computedVal = projectPointToLine(point, targetObj, args[1]);
          } else if (token == "reflect") {
            final point = resolvePointLikeArg(args[0]);
            final targetObj = lookupObj(args[1], "reflect");
            computedVal = reflectPointAgainstTarget(point, targetObj, args[1]);
          } else if (token == "tAtLength") {
            final obj = lookupObj(args[0], "tAtLength");
            final subEval = Evaluator(
              context,
              allowUnknownIdentifiers: allowUnknownIdentifiers,
              allowUnknownGeometryObjects: allowUnknownGeometryObjects,
            );
            final targetLen = (subEval.evaluate(args[1]) as num).toDouble();
            computedVal = getTAtLengthFromObject(obj, targetLen, args[0]);
          } else if (token == "intersection") {
            if (args.length < 2)
              throw Exception("intersection() requires at least 2 arguments");
            final obj1 = lookupObj(args[0], "intersection");
            final obj2 = lookupObj(args[1], "intersection");
            final label = "intersection(${args[0]}, ${args[1]})";
            final candidates = computeIntersections(obj1, obj2, label);

            IntersectionSelector? selector;
            if (args.length >= 3) {
              final raw = args[2].trim();
              if (raw == 'first') {
                selector = FirstSelector();
              } else if (raw == 'last') {
                selector = LastSelector();
              } else if (RegExp(r'^\d+$').hasMatch(raw)) {
                selector = IndexSelector(int.parse(raw));
              } else if (raw.startsWith('nearest(') && raw.endsWith(')')) {
                final refId = raw.substring(8, raw.length - 1);
                final refObj = context.objects?[refId];
                if (refObj == null)
                  throw Exception('Unknown reference in nearest(): $refId');
                selector = NearestSelector(getPointFromObject(refObj));
              } else if (raw.startsWith('farthest(') && raw.endsWith(')')) {
                final refId = raw.substring(9, raw.length - 1);
                final refObj = context.objects?[refId];
                if (refObj == null)
                  throw Exception('Unknown reference in farthest(): $refId');
                selector = FarthestSelector(getPointFromObject(refObj));
              } else {
                throw Exception('Unsupported intersection selector: $raw');
              }
            }
            computedVal = applySelector(candidates, selector, label);
          } else if (token == "toWorld") {
            // toWorld(point, object) — local space → world space
            // arg0 = point expression (point-like), arg1 = object ID
            final subEval = Evaluator(
              context,
              allowUnknownIdentifiers: allowUnknownIdentifiers,
              allowUnknownGeometryObjects: allowUnknownGeometryObjects,
            );
            final rawPoint = subEval.evaluate(args[0]);
            final Point2D localPt = _extractPoint(rawPoint, "toWorld arg0");
            final obj = lookupObj(args[1], "toWorld");
            computedVal = tfm.applyTransformPipeline(localPt, obj.transforms);
          } else if (token == "toLocal") {
            // toLocal(point, object) — world space → local space
            final subEval = Evaluator(
              context,
              allowUnknownIdentifiers: allowUnknownIdentifiers,
              allowUnknownGeometryObjects: allowUnknownGeometryObjects,
            );
            final rawPoint = subEval.evaluate(args[0]);
            final Point2D worldPt = _extractPoint(rawPoint, "toLocal arg0");
            final obj = lookupObj(args[1], "toLocal");
            computedVal = tfm.applyInverseTransformPipeline(
              worldPt,
              obj.transforms,
            );
          }

          return wrap(computedVal);
        }

        // Fungsi matematika standar
        final List<TypedValue> args = [];
        if (_tokens[_pos] != ')') {
          args.add(parseExpression());
          while (_tokens[_pos] == ',') {
            _pos++; // consume ','
            args.add(parseExpression());
          }
        }
        if (_tokens[_pos] != ')') {
          throw Exception("Expected ')' after function arguments");
        }
        _pos++; // consume ')'

        final unwrappedArgs = args.map((a) => unwrap(a)).toList();

        switch (token) {
          case 'min':
            return TypedValue(
              type: 'number',
              value: unwrappedArgs
                  .map((e) => (e as num).toDouble())
                  .reduce(math.min),
            );
          case 'max':
            return TypedValue(
              type: 'number',
              value: unwrappedArgs
                  .map((e) => (e as num).toDouble())
                  .reduce(math.max),
            );
          case 'abs':
            return TypedValue(
              type: 'number',
              value: (unwrappedArgs[0] as num).toDouble().abs(),
            );
          case 'clamp':
            final val = (unwrappedArgs[0] as num).toDouble();
            final min = (unwrappedArgs[1] as num).toDouble();
            final max = (unwrappedArgs[2] as num).toDouble();
            return TypedValue(
              type: 'number',
              value: math.min(math.max(val, min), max),
            );
          case 'sin':
            return TypedValue(
              type: 'number',
              value: math.sin((unwrappedArgs[0] as num).toDouble()),
            );
          case 'cos':
            return TypedValue(
              type: 'number',
              value: math.cos((unwrappedArgs[0] as num).toDouble()),
            );
          case 'tan':
            return TypedValue(
              type: 'number',
              value: math.tan((unwrappedArgs[0] as num).toDouble()),
            );
          case 'sqrt':
            return TypedValue(
              type: 'number',
              value: math.sqrt((unwrappedArgs[0] as num).toDouble()),
            );
          case 'pow':
            return TypedValue(
              type: 'number',
              value: math
                  .pow(
                    (unwrappedArgs[0] as num).toDouble(),
                    (unwrappedArgs[1] as num).toDouble(),
                  )
                  .toDouble(),
            );
          case 'round':
            return TypedValue(
              type: 'number',
              value: (unwrappedArgs[0] as num).roundToDouble(),
            );
          case 'floor':
            return TypedValue(
              type: 'number',
              value: (unwrappedArgs[0] as num).floorToDouble(),
            );
          case 'ceil':
            return TypedValue(
              type: 'number',
              value: (unwrappedArgs[0] as num).ceilToDouble(),
            );
          case 'concat':
            return TypedValue(
              type: 'string',
              value: unwrappedArgs.map((v) => '$v').join(),
            );
          case 'charAt':
            final str = '${unwrappedArgs[0] ?? ""}';
            final idx = ((unwrappedArgs[1] as num?) ?? 0).floor();
            return TypedValue(
              type: 'string',
              value: idx >= 0 && idx < str.length ? str[idx] : '',
            );
          case 'format':
            var fmt = '${unwrappedArgs[0] ?? ""}';
            for (var i = 1; i < unwrappedArgs.length; i++) {
              fmt = fmt.replaceFirst('{${i - 1}}', '${unwrappedArgs[i] ?? ""}');
            }
            return TypedValue(type: 'string', value: fmt);
          default:
            final custom = context.callFunction(token, args);
            if (custom != null) return custom;
            throw Exception('Unknown function: $token');
        }
      }

      // Resolusi variabel/identifier dinamis
      final hookVal = context.get(token);
      if (hookVal != null) return hookVal;

      final reconstructed = tryReconstructAndResolve(token);
      if (reconstructed != null) return reconstructed;

      final resolved = context.resolveIdentifier(token);
      if (resolved != null) return wrap(resolved);

      if (allowUnknownIdentifiers) {
        return TypedValue(type: 'number', value: 1.0);
      }
      throw Exception('Unknown identifier: $token');
    }

    // Literil bilangan atau unit ukuran
    if (RegExp(r'^\d+(?:\.\d+)?(?:deg|rad)$').hasMatch(token)) {
      final valStr = token.replaceAll(RegExp(r'[a-zA-Z]+'), '');
      final val = double.parse(valStr);
      return TypedValue(
        type: 'number',
        value: token.endsWith('deg') ? val * degToRad : val,
      );
    }

    if (RegExp(r'^\d+(?:\.\d+)?[a-zA-Z%]+$').hasMatch(token)) {
      return TypedValue(
        type: 'length',
        value: normalizeUnit(token, context.targetUnit),
      );
    }

    if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(token)) {
      return TypedValue(type: 'number', value: double.parse(token));
    }

    throw Exception('Invalid token: $token');
  }

  // --- RESOLVER GEOMETRI DI EVALUATOR ---

  Point2D getPointFromObject(ResolvedObject obj) {
    switch (obj) {
      case ResolvedPoint(:final x, :final y):
        return (x: x, y: y);
      case ResolvedRect(:final x, :final y, :final width, :final height):
        return (x: x + width / 2.0, y: y + height / 2.0);
      case ResolvedCircle(:final cx, :final cy):
        return (x: cx, y: cy);
      case ResolvedEllipse(:final cx, :final cy):
        return (x: cx, y: cy);
      case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
        return (x: (x1 + x2) / 2.0, y: (y1 + y2) / 2.0);
      default:
        return (x: 0.0, y: 0.0);
    }
  }

  /// Mengekstrak Point2D dari TypedValue yang mungkin berupa 'point', 'frame2d',
  /// atau bahkan record ({double x, double y}) langsung.
  Point2D _extractPoint(dynamic val, String context) {
    if (val is TypedValue) {
      final v = val.value;
      if (v is ({double x, double y})) return v;
      if (v is Map) {
        final pt = v['point'];
        if (pt is ({double x, double y})) return pt;
      }
      throw Exception('$context: expected a point value, got type=${val.type}');
    }
    if (val is ({double x, double y})) return val;
    throw Exception('$context: cannot extract point from $val');
  }

  Point2D resolvePointLikeArg(String arg) {
    final resolved = this.context.resolveIdentifier(arg);
    if (resolved is ({double x, double y})) return resolved;
    if (context.objects == null) {
      throw Exception('Cannot resolve point-like argument: $arg');
    }
    final obj = context.objects![arg];
    if (obj == null) throw Exception('Unknown object in point-like argument: $arg');
    return getPointFromObject(obj);
  }

  double getLengthFromObject(ResolvedObject obj, String label) {
    switch (obj) {
      case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
        return _hypot(x2 - x1, y2 - y1);
      case ResolvedRect(:final width, :final height):
        return 2 * (width + height);
      case ResolvedCircle(:final radius):
        return 2 * math.pi * radius;
      case ResolvedArc(:final radius, :final startAngle, :final endAngle):
        return radius * (endAngle - startAngle).abs();
      case ResolvedEllipse(:final rx, :final ry):
        final h = math.pow(rx - ry, 2) / math.pow(rx + ry, 2);
        return math.pi *
            (rx + ry) *
            (1 + (3 * h) / (10 + math.sqrt(4 - 3 * h)));
      case ResolvedPath(:final segments, :final points, :final closed):
        if (segments.isNotEmpty) {
          return segments
              .map((s) => getLengthFromSegment(s, label))
              .reduce((a, b) => a + b);
        }
        return geom.polylineLength(points, closed);
      case ResolvedPolygon(:final segments, :final points):
        if (segments.isNotEmpty) {
          return segments
              .map((s) => getLengthFromSegment(s, label))
              .reduce((a, b) => a + b);
        }
        return geom.polylineLength(points, true);
      case ResolvedQuadratic(
        :final x1,
        :final y1,
        :final cpx,
        :final cpy,
        :final x2,
        :final y2,
      ):
        return geom.approximateQuadraticLength(
          (x: x1, y: y1),
          (x: cpx, y: cpy),
          (x: x2, y: y2),
        );
      case ResolvedCubic(
        :final x1,
        :final y1,
        :final cp1x,
        :final cp1y,
        :final cp2x,
        :final cp2y,
        :final x2,
        :final y2,
      ):
        return geom.approximateCubicLength(
          (x: x1, y: y1),
          (x: cp1x, y: cp1y),
          (x: cp2x, y: cp2y),
          (x: x2, y: y2),
        );
      default:
        throw Exception(
          'PATH_LENGTH_UNAVAILABLE: Object "$label" does not expose length',
        );
    }
  }

  double getPerimeterFromObject(ResolvedObject obj, String label) {
    switch (obj) {
      case ResolvedRect():
      case ResolvedCircle():
      case ResolvedEllipse():
      case ResolvedPolygon():
        return getLengthFromObject(obj, label);
      case ResolvedPath(:final closed):
        if (!closed) {
          throw Exception('Path "$label" must be closed to expose perimeter');
        }
        return getLengthFromObject(obj, label);
      default:
        throw Exception('Unknown or invalid object in perimeter: $label');
    }
  }

  double getLengthFromSegment(PathResolvedSegment segment, String label) {
    switch (segment) {
      case LineSegment(:final x1, :final y1, :final x2, :final y2):
        return _hypot(x2 - x1, y2 - y1);
      case ArcSegment(
        :final cx,
        :final cy,
        :final radius,
        :final x1,
        :final y1,
        :final x2,
        :final y2,
        :final sweep,
      ):
        final startAngle = math.atan2(y1 - cy, x1 - cx);
        double endAngle = math.atan2(y2 - cy, x2 - cx);
        if (sweep == 1 && endAngle < startAngle) endAngle += math.pi * 2;
        if (sweep == 0 && endAngle > startAngle) endAngle -= math.pi * 2;
        return radius * (endAngle - startAngle).abs();
      case QuadraticSegment(
        :final x1,
        :final y1,
        :final cpx,
        :final cpy,
        :final x2,
        :final y2,
      ):
        return geom.approximateQuadraticLength(
          (x: x1, y: y1),
          (x: cpx, y: cpy),
          (x: x2, y: y2),
        );
      case CubicSegment(
        :final x1,
        :final y1,
        :final cp1x,
        :final cp1y,
        :final cp2x,
        :final cp2y,
        :final x2,
        :final y2,
      ):
        return geom.approximateCubicLength(
          (x: x1, y: y1),
          (x: cp1x, y: cp1y),
          (x: cp2x, y: cp2y),
          (x: x2, y: y2),
        );
    }
  }

  double getAreaFromObject(ResolvedObject obj, String label) {
    switch (obj) {
      case ResolvedRect(:final width, :final height):
        return width * height;
      case ResolvedCircle(:final radius):
        return math.pi * radius * radius;
      case ResolvedEllipse(:final rx, :final ry):
        return math.pi * rx * ry;
      case ResolvedPolygon(:final points):
        return geom.polygonArea(points);
      case ResolvedPath(:final points, :final closed):
        if (!closed)
          throw Exception('Path "$label" must be closed to expose area');
        return geom.polygonArea(points);
      default:
        throw Exception('Unknown or invalid object in area: $label');
    }
  }

  ({double x, double y, double width, double height}) getBoundingBoxForObject(
    ResolvedObject obj,
    String label,
  ) {
    switch (obj) {
      case ResolvedPoint(:final x, :final y):
        return (x: x, y: y, width: 0.0, height: 0.0);
      case ResolvedRect(:final x, :final y, :final width, :final height):
        return (x: x, y: y, width: width, height: height);
      case ResolvedCircle(:final cx, :final cy, :final radius):
        return (
          x: cx - radius,
          y: cy - radius,
          width: radius * 2,
          height: radius * 2,
        );
      case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
        return bboxFromPoints([(x: x1, y: y1), (x: x2, y: y2)]);
      default:
        return bboxFromPoints(sampleObjectBoundaryPoints(obj, label));
    }
  }

  Point2D getPointAtObject(ResolvedObject obj, double t, String label) {
    final clamped = math.min(math.max(t, 0.0), 1.0);
    switch (obj) {
      case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
        return geom.lerpPoint((x: x1, y: y1), (x: x2, y: y2), clamped);
      case ResolvedCircle(:final cx, :final cy, :final radius):
        final angle = clamped * math.pi * 2.0;
        return (
          x: cx + radius * math.cos(angle),
          y: cy + radius * math.sin(angle),
        );
      case ResolvedEllipse(
        :final cx,
        :final cy,
        :final rx,
        :final ry,
        :final rotation,
      ):
        final angle = clamped * math.pi * 2.0;
        final localX = rx * math.cos(angle);
        final localY = ry * math.sin(angle);
        return (
          x: cx + (localX * math.cos(rotation) - localY * math.sin(rotation)),
          y: cy + (localX * math.sin(rotation) + localY * math.cos(rotation)),
        );
      case ResolvedRect(:final x, :final y, :final width, :final height):
        final p = clamped * (2 * (width + height));
        if (p <= width) return (x: x + p, y: y);
        if (p <= width + height) return (x: x + width, y: y + (p - width));
        if (p <= 2 * width + height)
          return (x: x + width - (p - (width + height)), y: y + height);
        return (x: x, y: y + height - (p - (2 * width + height)));
      case ResolvedArc(
        :final cx,
        :final cy,
        :final radius,
        :final startAngle,
        :final endAngle,
      ):
        final angle = startAngle + (endAngle - startAngle) * clamped;
        return (
          x: cx + radius * math.cos(angle),
          y: cy + radius * math.sin(angle),
        );
      case ResolvedQuadratic(
        :final x1,
        :final y1,
        :final cpx,
        :final cpy,
        :final x2,
        :final y2,
      ):
        return geom.pointOnQuadratic((x: x1, y: y1), (x: cpx, y: cpy), (
          x: x2,
          y: y2,
        ), clamped);
      case ResolvedCubic(
        :final x1,
        :final y1,
        :final cp1x,
        :final cp1y,
        :final cp2x,
        :final cp2y,
        :final x2,
        :final y2,
      ):
        return geom.pointOnCubic(
          (x: x1, y: y1),
          (x: cp1x, y: cp1y),
          (x: cp2x, y: cp2y),
          (x: x2, y: y2),
          clamped,
        );
      case ResolvedPath(:final segments, :final points, :final closed):
        if (segments.isNotEmpty) {
          return pointAtSegments(segments, clamped, label);
        }
        return pointAtPolyline(points, clamped, label, closed);
      case ResolvedPolygon(:final segments, :final points):
        if (segments.isNotEmpty) {
          return pointAtSegments(segments, clamped, label);
        }
        return pointAtPolyline(points, clamped, label, true);
      default:
        throw Exception('pointAt not supported on object: $label');
    }
  }

  Point2D pointAtPolyline(
    List<Point2D> points,
    double t,
    String label,
    bool closed,
  ) {
    final total = geom.polylineLength(points, closed);
    if (total <= 0) throw Exception('Path "$label" has zero length');
    double remaining = total * t;

    final segmentCount = closed ? points.length : points.length - 1;
    for (int i = 0; i < segmentCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final segmentLength = _hypot(b.x - a.x, b.y - a.y);
      if (remaining <= segmentLength || i == segmentCount - 1) {
        final localT = segmentLength == 0 ? 0.0 : remaining / segmentLength;
        return geom.lerpPoint(a, b, localT);
      }
      remaining -= segmentLength;
    }
    return closed ? points[0] : points[points.length - 1];
  }

  Point2D pointAtSegments(
    List<PathResolvedSegment> segments,
    double t,
    String label,
  ) {
    final lengths = segments
        .map((s) => getLengthFromSegment(s, label))
        .toList();
    final total = lengths.reduce((a, b) => a + b);
    if (total <= 0) throw Exception('Path "$label" has zero length');

    double remaining = total * t;
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final segmentLength = lengths[i];
      if (remaining <= segmentLength || i == segments.length - 1) {
        final localT = segmentLength == 0 ? 0.0 : remaining / segmentLength;
        switch (segment) {
          case LineSegment(:final x1, :final y1, :final x2, :final y2):
            return geom.lerpPoint((x: x1, y: y1), (x: x2, y: y2), localT);
          case ArcSegment(
            :final cx,
            :final cy,
            :final radius,
            :final x1,
            :final y1,
            :final x2,
            :final y2,
            :final sweep,
          ):
            final startAngle = math.atan2(y1 - cy, x1 - cx);
            double endAngle = math.atan2(y2 - cy, x2 - cx);
            if (sweep == 1 && endAngle < startAngle) endAngle += math.pi * 2;
            if (sweep == 0 && endAngle > startAngle) endAngle -= math.pi * 2;
            final angle = startAngle + (endAngle - startAngle) * localT;
            return (
              x: cx + radius * math.cos(angle),
              y: cy + radius * math.sin(angle),
            );
          case QuadraticSegment(
            :final x1,
            :final y1,
            :final cpx,
            :final cpy,
            :final x2,
            :final y2,
          ):
            return geom.pointOnQuadratic((x: x1, y: y1), (x: cpx, y: cpy), (
              x: x2,
              y: y2,
            ), localT);
          case CubicSegment(
            :final x1,
            :final y1,
            :final cp1x,
            :final cp1y,
            :final cp2x,
            :final cp2y,
            :final x2,
            :final y2,
          ):
            return geom.pointOnCubic(
              (x: x1, y: y1),
              (x: cp1x, y: cp1y),
              (x: cp2x, y: cp2y),
              (x: x2, y: y2),
              localT,
            );
        }
      }
      remaining -= segmentLength;
    }
    final last = segments.last;
    switch (last) {
      case LineSegment(:final x2, :final y2):
        return (x: x2, y: y2);
      case ArcSegment(:final x2, :final y2):
        return (x: x2, y: y2);
      case QuadraticSegment(:final x2, :final y2):
        return (x: x2, y: y2);
      case CubicSegment(:final x2, :final y2):
        return (x: x2, y: y2);
    }
  }

  Point2D getTangentAtObject(ResolvedObject obj, double t, String label) {
    final clamped = math.min(math.max(t, 0.0), 1.0);
    const eps = 1e-6;

    if (obj is ResolvedLine) {
      final dx = obj.x2 - obj.x1;
      final dy = obj.y2 - obj.y1;
      final len = _hypot(dx, dy);
      return len == 0 ? (x: 1.0, y: 0.0) : (x: dx / len, y: dy / len);
    }
    if (obj is ResolvedArc) {
      final angle = obj.startAngle + (obj.endAngle - obj.startAngle) * clamped;
      var tangent = (x: -math.sin(angle), y: math.cos(angle));
      if (obj.endAngle < obj.startAngle) {
        tangent = (x: -tangent.x, y: -tangent.y);
      }
      return tangent;
    }

    final t0 = math.max(0.0, clamped - eps);
    final t1 = math.min(1.0, clamped + eps);
    final p0 = getPointAtObject(obj, t0, label);
    final p1 = getPointAtObject(obj, t1, label);
    final dx = p1.x - p0.x;
    final dy = p1.y - p0.y;
    final len = _hypot(dx, dy);
    return len == 0 ? (x: 1.0, y: 0.0) : (x: dx / len, y: dy / len);
  }

  Point2D getNormalAtObject(ResolvedObject obj, double t, String label) {
    final tangent = getTangentAtObject(obj, t, label);
    // Putar 90° CCW: (dx, dy) -> (-dy, dx)
    return (x: -tangent.y, y: tangent.x);
  }

  Point2D getClosestPoint(Point2D ref, ResolvedObject obj, String label) {
    switch (obj) {
      case ResolvedPoint(:final x, :final y):
        return (x: x, y: y);
      case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
        return geom.closestPointOnSegment(ref, (x: x1, y: y1), (x: x2, y: y2));
      case ResolvedCircle(:final cx, :final cy, :final radius):
        final dx = ref.x - cx;
        final dy = ref.y - cy;
        final len = _hypot(dx, dy);
        if (len == 0) return (x: cx + radius, y: cy);
        return (x: cx + (dx / len) * radius, y: cy + (dy / len) * radius);
      case ResolvedEllipse(
        :final cx,
        :final cy,
        :final rx,
        :final ry,
        :final rotation,
      ):
        return geom.closestPointOnEllipse(
          ref,
          cx: cx,
          cy: cy,
          rx: rx,
          ry: ry,
          rotation: rotation,
        );
      case ResolvedArc(
        :final cx,
        :final cy,
        :final radius,
        :final startAngle,
        :final endAngle,
      ):
        final rawAngle = math.atan2(ref.y - cy, ref.x - cx);
        final angle = geom.clampAngleToArc(rawAngle, startAngle, endAngle);
        final projected = (
          x: cx + radius * math.cos(angle),
          y: cy + radius * math.sin(angle),
        );
        final start = (
          x: cx + radius * math.cos(startAngle),
          y: cy + radius * math.sin(startAngle),
        );
        final end = (
          x: cx + radius * math.cos(endAngle),
          y: cy + radius * math.sin(endAngle),
        );
        return geom.pickNearestPoint(ref, [projected, start, end]);
      case ResolvedQuadratic(
        :final x1,
        :final y1,
        :final cpx,
        :final cpy,
        :final x2,
        :final y2,
      ):
        return geom.closestPointOnQuadratic(
          ref,
          (x: x1, y: y1),
          (x: cpx, y: cpy),
          (x: x2, y: y2),
        );
      case ResolvedCubic(
        :final x1,
        :final y1,
        :final cp1x,
        :final cp1y,
        :final cp2x,
        :final cp2y,
        :final x2,
        :final y2,
      ):
        return geom.closestPointOnCubic(
          ref,
          (x: x1, y: y1),
          (x: cp1x, y: cp1y),
          (x: cp2x, y: cp2y),
          (x: x2, y: y2),
        );
      case ResolvedPath(:final points, :final closed):
        return geom.closestPointOnPointPath(ref, points, closed);
      case ResolvedPolygon(:final points):
        return geom.closestPointOnPointPath(ref, points, true);
      default:
        throw Exception('closestPoint not supported on object: $label');
    }
  }

  Point2D projectPointToLine(Point2D point, ResolvedObject obj, String label) {
    switch (obj) {
      case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
        final dx = x2 - x1;
        final dy = y2 - y1;
        final len2 = dx * dx + dy * dy;
        if (len2 == 0) return (x: x1, y: y1);
        final t = ((point.x - x1) * dx + (point.y - y1) * dy) / len2;
        return (x: x1 + t * dx, y: y1 + t * dy);
      default:
        throw Exception('project() requires a line target, got $label');
    }
  }

  Point2D reflectPointAgainstTarget(Point2D point, ResolvedObject obj, String label) {
    switch (obj) {
      case ResolvedPoint(:final x, :final y):
        return (x: x * 2 - point.x, y: y * 2 - point.y);
      case ResolvedLine():
        final projected = projectPointToLine(point, obj, label);
        return (
          x: projected.x * 2 - point.x,
          y: projected.y * 2 - point.y,
        );
      default:
        throw Exception('reflect() requires a point or line target, got $label');
    }
  }

  double getTAtLengthFromObject(
    ResolvedObject obj,
    double targetLen,
    String label,
  ) {
    final totalLen = getLengthFromObject(obj, label);
    if (totalLen == 0.0)
      throw Exception('Path length is zero or unavailable for object "$label"');
    if (targetLen < 0.0 || targetLen > totalLen) {
      throw Exception(
        'INVALID_T_AT_LENGTH: targetLength must be between 0 and total length ($totalLen), got $targetLen',
      );
    }
    if (targetLen == 0.0) return 0.0;
    if (targetLen == totalLen) return 1.0;

    double low = 0.0;
    double high = 1.0;
    for (int iter = 0; iter < 16; iter++) {
      final mid = (low + high) / 2.0;
      final subLen = getSubLengthFromObject(obj, mid, label);
      if (subLen < targetLen) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2.0;
  }

  double getSubLengthFromObject(ResolvedObject obj, double t, String label) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return getLengthFromObject(obj, label);

    switch (obj) {
      case ResolvedLine():
        return t * getLengthFromObject(obj, label);
      case ResolvedArc():
        return t * getLengthFromObject(obj, label);
      case ResolvedCircle():
      case ResolvedEllipse():
        return t * getLengthFromObject(obj, label);
      case ResolvedQuadratic(
        :final x1,
        :final y1,
        :final cpx,
        :final cpy,
        :final x2,
        :final y2,
      ):
        return geom.approximateSubQuadraticLength(
          (x: x1, y: y1),
          (x: cpx, y: cpy),
          (x: x2, y: y2),
          t,
        );
      case ResolvedCubic(
        :final x1,
        :final y1,
        :final cp1x,
        :final cp1y,
        :final cp2x,
        :final cp2y,
        :final x2,
        :final y2,
      ):
        return geom.approximateSubCubicLength(
          (x: x1, y: y1),
          (x: cp1x, y: cp1y),
          (x: cp2x, y: cp2y),
          (x: x2, y: y2),
          t,
        );
      default:
        double total = 0.0;
        Point2D prev = getPointAtObject(obj, 0.0, label);
        const steps = 32;
        for (int i = 1; i <= steps; i++) {
          final currT = (i / steps) * t;
          final next = getPointAtObject(obj, currT, label);
          total += _hypot(next.x - prev.x, next.y - prev.y);
          prev = next;
        }
        return total;
    }
  }

  List<Point2D> sampleObjectBoundaryPoints(
    ResolvedObject obj,
    String label, [
    int steps = 64,
  ]) {
    switch (obj) {
      case ResolvedPoint(:final x, :final y):
        return [(x: x, y: y)];
      case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
        return [(x: x1, y: y1), (x: x2, y: y2)];
      case ResolvedPath(:final points):
        return points.isNotEmpty
            ? points
            : List.generate(steps + 1, (i) => getPointAtObject(obj, i / steps, label));
      case ResolvedPolygon(:final points):
        return points.isNotEmpty
            ? points
            : List.generate(steps + 1, (i) => getPointAtObject(obj, i / steps, label));
      default:
        return List.generate(
          steps + 1,
          (i) => getPointAtObject(obj, i / steps, label),
        );
    }
  }

  ({double x, double y, double width, double height}) bboxFromPoints(
    List<Point2D> points,
  ) {
    if (points.isEmpty) return (x: 0.0, y: 0.0, width: 0.0, height: 0.0);
    var minX = points.first.x;
    var maxX = points.first.x;
    var minY = points.first.y;
    var maxY = points.first.y;
    for (final p in points.skip(1)) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return (x: minX, y: minY, width: maxX - minX, height: maxY - minY);
  }
}
