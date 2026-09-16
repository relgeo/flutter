import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';
import 'package:yaml/yaml.dart';

import 'support/shared_fixture.dart';

void main() {
  if (!hasSharedFixtures()) {
    test(
      'shared invalid fixtures require workspace fixture staging',
      () {},
      skip: 'Set RELGEO_FIXTURE_ROOT to run canonical workspace fixtures.',
    );
    return;
  }

  test('invalid YAML fixture is rejected at the parsing boundary', () {
    expect(
      () => loadYaml(loadSharedFixtureText('12-v05-invalid-yaml-syntax.yaml')),
      throwsA(isA<YamlException>()),
    );
  });

  test('missing object type is rejected instead of silently resolving', () {
    expect(
      () => resolveGeometry(
        loadSharedFixture('11-v05-invalid-missing-type.yaml'),
      ),
      throwsA(
        predicate(
          (error) =>
              error is Exception &&
              error.toString().contains('Unknown object type'),
        ),
      ),
    );
  });

  test('unknown object reference is surfaced as a resolver error', () {
    expect(
      () => resolveGeometry(
        loadSharedFixture('13-v05-invalid-unknown-reference.yaml'),
      ),
      throwsA(
        predicate(
          (error) =>
              error is Exception &&
              error.toString().contains('Unknown identifier'),
        ),
      ),
    );
  });
}
