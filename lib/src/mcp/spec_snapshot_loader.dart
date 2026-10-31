import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:relgeo_mcp/relgeo_mcp.dart';

/// The asset root produced by `pnpm run spec:snapshot:sync`.
const relGeoBundledSpecAssetRoot = 'assets/relgeo_spec/v0.5';

/// An immutable corpus loaded from Flutter's asset bundle.
class RelGeoBundledSpecSnapshot {
  const RelGeoBundledSpecSnapshot({
    required this.snapshot,
    required this.documents,
  });

  final SpecSnapshotMetadata snapshot;
  final List<SpecMarkdownDocument> documents;

  SpecSectionIndex createIndex() =>
      SpecSectionIndex.fromDocuments(snapshot: snapshot, documents: documents);
}

/// Loads the pinned Markdown snapshot through [AssetBundle] only.
///
/// The desktop host therefore has no repository-path or network dependency at
/// runtime. Supplying an [AssetBundle] is also the test seam for offline
/// verification; production uses Flutter's [rootBundle].
class RelGeoSpecSnapshotLoader {
  const RelGeoSpecSnapshotLoader({
    this.bundle,
    this.assetRoot = relGeoBundledSpecAssetRoot,
  });

  final AssetBundle? bundle;
  final String assetRoot;

  Future<RelGeoBundledSpecSnapshot> load() async {
    final root = _normaliseRoot(assetRoot);
    final manifestKey = '$root/manifest.json';
    final manifest = await _loadJson(rootBundleOr(bundle), manifestKey);
    _require(
      manifest['schemaVersion'] == 1,
      'Unsupported spec manifest schema',
    );
    _require(
      manifest['sourceDirectory'] == 'spec/id',
      'Spec manifest sourceDirectory must be spec/id',
    );
    _require(
      manifest['assetDirectory'] == root,
      'Spec manifest assetDirectory does not match asset root',
    );

    final rawFiles = manifest['files'];
    if (rawFiles is! List) {
      throw const FormatException('Spec manifest files must be a list');
    }
    final fileEntries = rawFiles;
    final rawFileCount = manifest['fileCount'];
    if (rawFileCount is! int || rawFileCount != fileEntries.length) {
      throw const FormatException(
        'Spec manifest fileCount does not match files',
      );
    }

    final paths = <String>{};
    final documents = <SpecMarkdownDocument>[];
    for (final rawFile in fileEntries) {
      if (rawFile is! Map) {
        throw const FormatException(
          'Spec manifest file entry must be an object',
        );
      }
      final path = rawFile['path'];
      final validatedPath = _validateRelativeMarkdownPath(path);
      _require(
        paths.add(validatedPath),
        'Duplicate spec manifest path: $validatedPath',
      );
      final content = await rootBundleOr(
        bundle,
      ).loadString('$root/$validatedPath');
      documents.add(
        SpecMarkdownDocument(relativePath: validatedPath, content: content),
      );
    }
    documents.sort((a, b) => a.relativePath.compareTo(b.relativePath));

    final specVersion = manifest['specVersion'];
    final revision = manifest['revision'];
    final digest = manifest['digest'];
    final sourceUrl = manifest['sourceUrl'];
    final digestAlgorithm = manifest['digestAlgorithm'];
    if (specVersion is! String || specVersion.isEmpty) {
      throw const FormatException('Missing specVersion');
    }
    if (revision is! String || revision.isEmpty) {
      throw const FormatException('Missing revision');
    }
    if (digest is! String || digest.isEmpty) {
      throw const FormatException('Missing digest');
    }
    if (sourceUrl is! String || sourceUrl.isEmpty) {
      throw const FormatException('Missing sourceUrl');
    }
    if (digestAlgorithm is! String || digestAlgorithm.isEmpty) {
      throw const FormatException('Missing digestAlgorithm');
    }

    return RelGeoBundledSpecSnapshot(
      snapshot: SpecSnapshotMetadata(
        specVersion: specVersion,
        revision: revision,
        digest: digest,
        digestAlgorithm: digestAlgorithm,
        sourceUrl: sourceUrl,
        fileCount: rawFileCount,
      ),
      documents: List<SpecMarkdownDocument>.unmodifiable(documents),
    );
  }

  AssetBundle rootBundleOr(AssetBundle? value) => value ?? rootBundle;

  static Future<Map<String, Object?>> _loadJson(
    AssetBundle bundle,
    String key,
  ) async {
    final decoded = jsonDecode(await bundle.loadString(key));
    _require(decoded is Map, 'Spec manifest must be a JSON object');
    return Map<String, Object?>.from(decoded.cast<String, Object?>());
  }

  static String _normaliseRoot(String value) {
    final root = value.endsWith('/')
        ? value.substring(0, value.length - 1)
        : value;
    _require(
      root.startsWith('assets/relgeo_spec/') &&
          !root.contains('..') &&
          !root.contains('\\'),
      'Invalid bundled spec asset root',
    );
    return root;
  }

  static String _validateRelativeMarkdownPath(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Invalid spec manifest path');
    }
    final path = value;
    final parts = path.split('/');
    if (!path.endsWith('.md') ||
        path.startsWith('/') ||
        path.contains('\\') ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('Invalid spec manifest path: $path');
    }
    return path;
  }

  static void _require(bool condition, String message) {
    if (!condition) throw FormatException(message);
  }
}
