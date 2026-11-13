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
    final files = <_ManifestFile>[];
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
      final bytes = await _loadBytes(
        rootBundleOr(bundle),
        '$root/$validatedPath',
      );
      final expectedBytes = rawFile['bytes'];
      final expectedSha256 = rawFile['sha256'];
      _require(
        expectedBytes is int && expectedBytes >= 0,
        'Spec manifest bytes must be a non-negative integer: $validatedPath',
      );
      _require(
        expectedSha256 is String && _isSha256Hex(expectedSha256),
        'Spec manifest sha256 is invalid: $validatedPath',
      );
      final actualSha256 = _Sha256.hex(bytes);
      _require(
        bytes.length == expectedBytes,
        'Spec snapshot byte length differs from manifest: $validatedPath',
      );
      _require(
        actualSha256 == expectedSha256,
        'Spec snapshot hash differs from manifest: $validatedPath',
      );
      files.add(
        _ManifestFile(
          path: validatedPath,
          bytes: bytes.length,
          sha256: actualSha256,
        ),
      );
      documents.add(
        SpecMarkdownDocument(
          relativePath: validatedPath,
          content: utf8.decode(bytes),
        ),
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
    _require(
      digestAlgorithm == 'sha256',
      'Unsupported spec digestAlgorithm: $digestAlgorithm',
    );
    final computedDigest = _corpusDigest(files);
    _require(
      digest == computedDigest,
      'Spec snapshot digest differs from manifest',
    );

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

  static Future<Uint8List> _loadBytes(AssetBundle bundle, String key) async {
    final data = await bundle.load(key);
    return Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  static String _corpusDigest(List<_ManifestFile> files) {
    final sorted = List<_ManifestFile>.of(files)
      ..sort((a, b) => a.path.compareTo(b.path));
    final canonical = sorted
        .map((file) => '${file.path}\u0000${file.sha256}\u0000${file.bytes}\n')
        .join();
    return 'sha256:${_Sha256.hex(utf8.encode(canonical))}';
  }

  static bool _isSha256Hex(String value) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

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

class _ManifestFile {
  const _ManifestFile({
    required this.path,
    required this.bytes,
    required this.sha256,
  });

  final String path;
  final int bytes;
  final String sha256;
}

/// Small dependency-free SHA-256 implementation for validating bundled bytes.
/// The snapshot loader is used by the Flutter host and must remain offline.
class _Sha256 {
  static const _initial = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];

  static const _round = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  static String hex(List<int> input) {
    final bytes = List<int>.of(input);
    final bitLength = bytes.length * 8;
    bytes.add(0x80);
    while (bytes.length % 64 != 56) {
      bytes.add(0);
    }
    for (var shift = 56; shift >= 0; shift -= 8) {
      bytes.add((bitLength >> shift) & 0xff);
    }

    final hash = List<int>.of(_initial);
    for (var offset = 0; offset < bytes.length; offset += 64) {
      final words = List<int>.filled(64, 0);
      for (var index = 0; index < 16; index++) {
        final base = offset + index * 4;
        words[index] =
            ((bytes[base] << 24) |
                (bytes[base + 1] << 16) |
                (bytes[base + 2] << 8) |
                bytes[base + 3]) &
            0xffffffff;
      }
      for (var index = 16; index < 64; index++) {
        final s0 =
            _rotateRight(words[index - 15], 7) ^
            _rotateRight(words[index - 15], 18) ^
            (words[index - 15] >> 3);
        final s1 =
            _rotateRight(words[index - 2], 17) ^
            _rotateRight(words[index - 2], 19) ^
            (words[index - 2] >> 10);
        words[index] =
            (words[index - 16] + s0 + words[index - 7] + s1) & 0xffffffff;
      }

      var a = hash[0];
      var b = hash[1];
      var c = hash[2];
      var d = hash[3];
      var e = hash[4];
      var f = hash[5];
      var g = hash[6];
      var h = hash[7];
      for (var index = 0; index < 64; index++) {
        final s1 =
            _rotateRight(e, 6) ^ _rotateRight(e, 11) ^ _rotateRight(e, 25);
        final choose = (e & f) ^ ((~e) & g);
        final temp1 =
            (h + s1 + choose + _round[index] + words[index]) & 0xffffffff;
        final s0 =
            _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
        final majority = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + majority) & 0xffffffff;
        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }
      hash[0] = (hash[0] + a) & 0xffffffff;
      hash[1] = (hash[1] + b) & 0xffffffff;
      hash[2] = (hash[2] + c) & 0xffffffff;
      hash[3] = (hash[3] + d) & 0xffffffff;
      hash[4] = (hash[4] + e) & 0xffffffff;
      hash[5] = (hash[5] + f) & 0xffffffff;
      hash[6] = (hash[6] + g) & 0xffffffff;
      hash[7] = (hash[7] + h) & 0xffffffff;
    }
    return hash.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
  }

  static int _rotateRight(int value, int count) =>
      ((value >> count) | (value << (32 - count))) & 0xffffffff;
}
