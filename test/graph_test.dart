import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

void main() {
  group('RelGeo Topological Graph Resolver Port Test Suite', () {
    test('Penyortiran Topologis Geometri Dasar (sortObjects)', () {
      // a bergantung pada b, b bergantung pada c
      final objects = {
        'a': {
          'type': 'point',
          'from': 'b',
        },
        'b': {
          'type': 'line',
          'from': 'c',
          'to': 'd',
        },
        'c': {
          'type': 'rect',
          'size': [120, 80],
        },
        'd': {
          'type': 'point',
          'at': '10px, 20px',
        }
      };

      final order = sortObjects(objects);

      // d dan c harus dievaluasi sebelum b, dan b sebelum a
      expect(order.indexOf('d'), lessThan(order.indexOf('b')));
      expect(order.indexOf('c'), lessThan(order.indexOf('b')));
      expect(order.indexOf('b'), lessThan(order.indexOf('a')));
    });

    test('Pendeteksian Siklus Dependensi (Circular Dependency)', () {
      // a bergantung pada b, b bergantung pada c, c bergantung pada a
      final objects = {
        'a': {
          'type': 'point',
          'from': 'b',
        },
        'b': {
          'type': 'line',
          'from': 'c',
        },
        'c': {
          'type': 'rect',
          'place': {
            'centerX': 'a.centerX',
          }
        }
      };

      expect(
        () => sortObjects(objects),
        throwsA(isA<CircularDependencyException>()),
      );

      try {
        sortObjects(objects);
      } on CircularDependencyException catch (e) {
        expect(e.message, contains('Circular dependency detected'));
        expect(e.chain, contains('a -> b -> c -> a'));
      }
    });

    test('Penyortiran Terpadu Variabel Derived & Geometri (sortUnified)', () {
      final objects = {
        'tanah': {
          'type': 'rect',
          'size': ['lebar_tanah', 'tinggi_tanah'],
        },
        'rumah': {
          'type': 'rect',
          'size': ['lebar_rumah', 'tinggi_rumah'],
          'place': {
            'centerX': 'tanah.centerX',
          }
        }
      };

      final derived = {
        'lebar_tanah': '150mm',
        'tinggi_tanah': '100mm',
        // lebar_rumah bergantung pada derived lebar_tanah
        'lebar_rumah': 'lebar_tanah * 0.6',
        'tinggi_rumah': '40mm',
      };

      final order = sortUnified(objects, derived);

      final orderStrs = order.map((n) => '${n.kind}:${n.id}').toList();

      // derived lebar_tanah harus mendahului derived lebar_rumah
      expect(orderStrs.indexOf('derived:lebar_tanah'), lessThan(orderStrs.indexOf('derived:lebar_rumah')));
      // derived lebar_tanah harus mendahului objek tanah karena tanah memakainya di size
      expect(orderStrs.indexOf('derived:lebar_tanah'), lessThan(orderStrs.indexOf('object:tanah')));
      // objek tanah harus mendahului objek rumah karena rumah ditempatkan relatif terhadap tanah (centerX)
      expect(orderStrs.indexOf('object:tanah'), lessThan(orderStrs.indexOf('object:rumah')));
      // derived lebar_rumah harus mendahului objek rumah karena rumah memakainya di size
      expect(orderStrs.indexOf('derived:lebar_rumah'), lessThan(orderStrs.indexOf('object:rumah')));
    });
  });
}
