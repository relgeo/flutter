import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/mcp/spec_snapshot_loader.dart';
import 'package:relgeo_mcp/relgeo_mcp.dart';

class _MapAssetBundle extends CachingAssetBundle {
  _MapAssetBundle(this.values);

  final Map<String, String> values;

  @override
  Future<ByteData> load(String key) async {
    final value = values[key];
    if (value == null) throw StateError('Missing test asset: $key');
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default loader reads the checked-in desktop asset snapshot', () async {
    final loaded = await const RelGeoSpecSnapshotLoader().load();
    final index = loaded.createIndex();

    expect(loaded.snapshot.specVersion, '0.5');
    expect(loaded.snapshot.fileCount, 35);
    expect(loaded.documents, hasLength(35));
    expect(
      index
          .search(const SearchSpecInput(query: 'parameters constants'))
          .matches,
      isNotEmpty,
    );
    final profileSpec = loaded.documents.singleWhere(
      (document) => document.relativePath == 'syntax/11-profiles.md',
    );
    expect(profileSpec.content, contains('UNKNOWN_FIELD'));
    final closureSpec = loaded.documents.singleWhere(
      (document) => document.relativePath == 'core/07-closure-contracts.md',
    );
    expect(closureSpec.content, contains('SVGSemanticError'));
  });

  test(
    'covers Indonesian and English intent across the main spec areas',
    () async {
      final index = (await const RelGeoSpecSnapshotLoader().load())
          .createIndex();

      for (final fixture in relGeoSpecSearchFixtures) {
        final result = index.search(
          SearchSpecInput(query: fixture.query, maxResults: 16),
        );
        expect(result.noResults, fixture.expectsNoResults, reason: fixture.id);
        for (final expectedSectionId in fixture.expectedSectionIds) {
          expect(
            result.matches.map((match) => match.sectionId.value),
            contains(expectedSectionId),
            reason: fixture.id,
          );
        }
      }

      final box = index.search(
        const SearchSpecInput(query: 'kotak rect rectangle'),
      );
      expect(
        box.matches.any(
          (match) =>
              match.sectionId.relativePath == 'geometry/14-geometry-objects.md',
        ),
        isTrue,
      );

      final parameters = index.search(
        const SearchSpecInput(query: 'parameters constants', maxResults: 16),
      );
      final parameterPaths = parameters.matches
          .map((match) => match.sectionId.relativePath)
          .toSet();
      expect(parameterPaths, contains('syntax/08-parameters.md'));
      expect(parameterPaths, contains('syntax/09-constants.md'));

      final placement = index.search(
        const SearchSpecInput(query: 'point path placement', maxResults: 16),
      );
      expect(
        placement.matches.any(
          (match) => match.sectionId.relativePath == 'geometry/17-placement.md',
        ),
        isTrue,
      );
      expect(
        placement.matches.any(
          (match) =>
              match.sectionId.relativePath == 'geometry/14-geometry-objects.md',
        ),
        isTrue,
      );

      final presentation = index.search(
        const SearchSpecInput(
          query: 'dimension annotation views sheets',
          maxResults: 16,
        ),
      );
      final presentationPaths = presentation.matches
          .map((match) => match.sectionId.relativePath)
          .toSet();
      expect(presentationPaths, contains('presentation/22-dimension.md'));
      expect(presentationPaths, contains('presentation/23-annotation.md'));
      expect(presentationPaths, contains('presentation/25-views-sheets.md'));
    },
  );

  test(
    'verifies ambiguity, no-result behavior, provenance, and full sections',
    () async {
      final index = (await const RelGeoSpecSnapshotLoader().load())
          .createIndex();

      final ambiguous = index.search(
        const SearchSpecInput(query: 'placement', maxResults: 16),
      );
      expect(ambiguous.matches.length, greaterThan(1));
      expect(
        ambiguous.matches.every(
          (match) =>
              match.provenance.revision == index.snapshot.revision &&
              match.provenance.digest == index.snapshot.digest &&
              match.provenance.sourceUrl.contains(match.sectionId.relativePath),
        ),
        isTrue,
      );

      final noResult = index.search(
        const SearchSpecInput(query: 'zzzz-no-relgeo-section-999'),
      );
      expect(noResult.noResults, isTrue);
      expect(noResult.matches, isEmpty);
      expect(noResult.snapshot.digest, index.snapshot.digest);

      final rect = index.getSection(
        const GetSpecSectionInput(
          sectionId: SpecSectionId(
            relativePath: 'geometry/14-geometry-objects.md',
            anchor: '143-rect',
          ),
        ),
      );
      expect(rect.section.content, contains('## 14.3 Rect'));
      expect(rect.section.content, contains('### Placement'));
      expect(rect.section.content, isNot(contains('## 14.4 Circle')));
      expect(rect.section.provenance.isNormative, isTrue);
      expect(rect.snapshot.revision, index.snapshot.revision);

      final informative = index.sections.firstWhere(
        (section) => section.id.relativePath == 'README.md',
      );
      expect(informative.provenance.isNormative, isFalse);
      expect(informative.provenance.status, SpecDocumentStatus.informative);
    },
  );

  test('loads the pinned corpus through AssetBundle and builds an index', () async {
    const root = 'assets/relgeo_spec/v0.5';
    final manifest = jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'specVersion': '0.5',
      'sourceDirectory': 'spec/id',
      'assetDirectory': root,
      'revision': 'fixture-revision',
      'sourceUrl': 'https://example.test/spec/fixture-revision/id',
      'digestAlgorithm': 'sha256',
      'digest':
          'sha256:c5273e02c094043ec6392ec0b52e45c2933c6fd7f512cd18c1764df42b0b5ddf',
      'fileCount': 2,
      'files': <Map<String, Object>>[
        <String, Object>{
          'path': 'core/README.md',
          'bytes': 36,
          'sha256':
              '78fd0853fbb9f71b4efe607c4d8b2ccfc5ad97fab233c6ebd0a6cb4d74de429c',
        },
        <String, Object>{
          'path': 'syntax/08-parameters.md',
          'bytes': 56,
          'sha256':
              '6a975b710ddb51ca1fef479f00ad17b0326c5f1f438492d0de84bc56ae388512',
        },
      ],
    });
    final bundle = _MapAssetBundle(<String, String>{
      '$root/manifest.json': manifest,
      '$root/core/README.md': '# Core\n\nStatus dokumen: `Normative`\n',
      '$root/syntax/08-parameters.md':
          '# Parameters\n\nStatus dokumen: `Normative`\n\nNamed inputs.',
    });

    final loaded = await RelGeoSpecSnapshotLoader(bundle: bundle).load();
    expect(loaded.snapshot.revision, 'fixture-revision');
    expect(loaded.documents, hasLength(2));
    final index = loaded.createIndex();
    final result = index.search(const SearchSpecInput(query: 'named inputs'));
    expect(result.matches, hasLength(1));
    expect(result.matches.single.provenance.isNormative, isTrue);
    expect(result.snapshot.digest, startsWith('sha256:'));
  });

  test('rejects bundled content that no longer matches its manifest hash', () async {
    const root = 'assets/relgeo_spec/v0.5';
    final bundle = _MapAssetBundle(<String, String>{
      '$root/manifest.json': jsonEncode(<String, Object>{
        'schemaVersion': 1,
        'specVersion': '0.5',
        'sourceDirectory': 'spec/id',
        'assetDirectory': root,
        'revision': 'fixture-revision',
        'sourceUrl': 'https://example.test/spec/fixture-revision/id',
        'digestAlgorithm': 'sha256',
        'digest':
            'sha256:c5273e02c094043ec6392ec0b52e45c2933c6fd7f512cd18c1764df42b0b5ddf',
        'fileCount': 2,
        'files': <Map<String, Object>>[
          <String, Object>{
            'path': 'core/README.md',
            'bytes': 36,
            'sha256':
                '78fd0853fbb9f71b4efe607c4d8b2ccfc5ad97fab233c6ebd0a6cb4d74de429c',
          },
          <String, Object>{
            'path': 'syntax/08-parameters.md',
            'bytes': 56,
            'sha256':
                '6a975b710ddb51ca1fef479f00ad17b0326c5f1f438492d0de84bc56ae388512',
          },
        ],
      }),
      '$root/core/README.md': '# Core\n\nStatus dokumen: `Normative`\n',
      '$root/syntax/08-parameters.md':
          '# Parameters\n\nStatus dokumen: `Normative`\n\nTampered.....',
    });

    await expectLater(
      RelGeoSpecSnapshotLoader(bundle: bundle).load(),
      throwsA(
        predicate<FormatException>(
          (error) => error.message.contains('hash differs from manifest'),
        ),
      ),
    );
  });

  test('rejects a manifest whose corpus digest is stale', () async {
    const root = 'assets/relgeo_spec/v0.5';
    final bundle = _MapAssetBundle(<String, String>{
      '$root/manifest.json': jsonEncode(<String, Object>{
        'schemaVersion': 1,
        'specVersion': '0.5',
        'sourceDirectory': 'spec/id',
        'assetDirectory': root,
        'revision': 'fixture-revision',
        'sourceUrl': 'https://example.test/spec/fixture-revision/id',
        'digestAlgorithm': 'sha256',
        'digest': 'sha256:stale',
        'fileCount': 0,
        'files': <Map<String, Object>>[],
      }),
    });

    await expectLater(
      RelGeoSpecSnapshotLoader(bundle: bundle).load(),
      throwsA(
        predicate<FormatException>(
          (error) => error.message.contains('digest differs from manifest'),
        ),
      ),
    );
  });

  test('rejects a manifest that escapes the bundled Markdown root', () async {
    const root = 'assets/relgeo_spec/v0.5';
    final bundle = _MapAssetBundle(<String, String>{
      '$root/manifest.json': jsonEncode(<String, Object>{
        'schemaVersion': 1,
        'specVersion': '0.5',
        'sourceDirectory': 'spec/id',
        'assetDirectory': root,
        'revision': 'fixture-revision',
        'sourceUrl': 'https://example.test/spec/fixture-revision/id',
        'digestAlgorithm': 'sha256',
        'digest': 'sha256:fixture',
        'fileCount': 1,
        'files': <Map<String, Object>>[
          <String, Object>{'path': '../outside.md'},
        ],
      }),
    });

    await expectLater(
      RelGeoSpecSnapshotLoader(bundle: bundle).load(),
      throwsA(isA<FormatException>()),
    );
  });
}
