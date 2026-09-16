import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Loads canonical workspace fixtures without embedding an operator-specific
/// absolute path in the Flutter repository.
///
/// The integration gate should set [RELGEO_FIXTURE_ROOT] to a directory that
/// contains the `reference/` directory. The relative fallback is intentionally
/// limited to the normal `relgeo-workspace/flutter` checkout layout.
Map<dynamic, dynamic> loadSharedFixture(String name) {
  final file = sharedFixtureFile('reference', name);
  if (!file.existsSync()) {
    throw StateError(
      'Shared RelGeo fixture not found: ${file.path}. '
      'Set RELGEO_FIXTURE_ROOT to a directory containing reference/.',
    );
  }
  return loadYaml(file.readAsStringSync()) as Map<dynamic, dynamic>;
}

String loadSharedFixtureText(String name) {
  final file = sharedFixtureFile('reference', name);
  if (!file.existsSync()) {
    throw StateError(
      'Shared RelGeo fixture not found: ${file.path}. '
      'Set RELGEO_FIXTURE_ROOT to a directory containing reference/.',
    );
  }
  return file.readAsStringSync();
}

dynamic loadSharedExpectedJson(String name) {
  final file = sharedFixtureFile('expected', name);
  if (!file.existsSync()) {
    throw StateError(
      'Shared RelGeo expected snapshot not found: ${file.path}. '
      'Set RELGEO_FIXTURE_ROOT to a directory containing expected/.',
    );
  }
  return jsonDecode(file.readAsStringSync());
}

String loadSharedExpectedText(String name) {
  final file = sharedFixtureFile('expected', name);
  if (!file.existsSync()) {
    throw StateError(
      'Shared RelGeo expected snapshot not found: ${file.path}. '
      'Set RELGEO_FIXTURE_ROOT to a directory containing expected/.',
    );
  }
  return file.readAsStringSync();
}

File sharedFixtureFile(String directory, String name) {
  return File('${sharedFixtureRoot().path}/$directory/$name');
}

Directory sharedFixtureRoot() {
  final candidates = _sharedFixtureCandidates();

  for (final candidate in candidates) {
    if (candidate.existsSync()) return candidate;
  }

  final searched = candidates.map((candidate) => candidate.path).join(', ');
  throw StateError(
    'Canonical RelGeo fixtures are unavailable. Searched: $searched. '
    'Set RELGEO_FIXTURE_ROOT for shared-fixture tests.',
  );
}

bool hasSharedFixtures() {
  return _sharedFixtureCandidates().any((candidate) => candidate.existsSync());
}

List<Directory> _sharedFixtureCandidates() {
  final configuredRoot = Platform.environment['RELGEO_FIXTURE_ROOT'];
  final candidates = <Directory>[];

  if (configuredRoot != null && configuredRoot.trim().isNotEmpty) {
    candidates.add(Directory(configuredRoot.trim()));
  }

  // Workspace fallback for local development only. No absolute path is stored
  // in source or required by the test suite.
  candidates.add(Directory('../fixtures'));
  return candidates;
}
