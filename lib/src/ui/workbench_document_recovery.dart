import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A single last-safe draft retained after an interrupted authoring session.
class WorkbenchRecoveryDraft {
  const WorkbenchRecoveryDraft({
    required this.documentId,
    required this.source,
    this.path,
    this.name,
  });

  final String documentId;
  final String source;
  final String? path;
  final String? name;
}

/// Storage seam for recovery tests and restricted hosts.
abstract interface class WorkbenchRecoveryStorage {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> remove();
}

/// SharedPreferences-backed recovery storage.
class SharedPreferencesWorkbenchRecoveryStorage
    implements WorkbenchRecoveryStorage {
  const SharedPreferencesWorkbenchRecoveryStorage();

  static const storageKey = 'relgeo.workbench.recovery.v2';
  static const _legacyDocumentIdKey = 'relgeo.workbench.recovery.documentId';
  static const _legacySourceKey = 'relgeo.workbench.recovery.source';
  static const _legacyPathKey = 'relgeo.workbench.recovery.path';
  static const _legacyNameKey = 'relgeo.workbench.recovery.name';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(storageKey);
    if (current != null) return current;

    // Read the pre-v2 keys once so an upgrade does not silently lose a draft.
    final legacySource = prefs.getString(_legacySourceKey);
    final legacyDocumentId = prefs.getString(_legacyDocumentIdKey);
    if (legacySource == null || legacyDocumentId == null) return null;
    return jsonEncode(<String, Object?>{
      'documentId': legacyDocumentId,
      'source': legacySource,
      'path': prefs.getString(_legacyPathKey),
      'name': prefs.getString(_legacyNameKey),
    });
  }

  @override
  Future<void> write(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
    await prefs.remove(_legacyDocumentIdKey);
    await prefs.remove(_legacySourceKey);
    await prefs.remove(_legacyPathKey);
    await prefs.remove(_legacyNameKey);
  }

  @override
  Future<void> remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    await prefs.remove(_legacyDocumentIdKey);
    await prefs.remove(_legacySourceKey);
    await prefs.remove(_legacyPathKey);
    await prefs.remove(_legacyNameKey);
  }
}

/// Best-effort persistence boundary for unsaved source recovery.
class WorkbenchDocumentRecoveryStore {
  const WorkbenchDocumentRecoveryStore({WorkbenchRecoveryStorage? storage})
    : _storage = storage ?? const SharedPreferencesWorkbenchRecoveryStorage();

  final WorkbenchRecoveryStorage _storage;

  Future<WorkbenchRecoveryDraft?> load() async {
    try {
      final raw = await _storage.read();
      if (raw == null || raw.isEmpty) return null;
      final value = jsonDecode(raw);
      if (value is! Map) throw const FormatException('invalid recovery payload');
      final source = value['source'];
      final documentId = value['documentId'];
      final path = value['path'];
      final name = value['name'];
      if (source is! String || source.isEmpty || documentId is! String || documentId.isEmpty) {
        throw const FormatException('incomplete recovery payload');
      }
      if (path != null && path is! String) {
        throw const FormatException('invalid recovery path');
      }
      if (name != null && name is! String) {
        throw const FormatException('invalid recovery name');
      }
      return WorkbenchRecoveryDraft(
        documentId: documentId,
        source: source,
        path: path as String?,
        name: name as String?,
      );
    } catch (_) {
      // Corrupt drafts must not trap the next launch in a recovery loop. A
      // blocked store may also reject the cleanup; both remain best-effort.
      try {
        await _storage.remove();
      } catch (_) {}
      return null;
    }
  }

  Future<void> save(WorkbenchRecoveryDraft draft) async {
    if (draft.source.isEmpty || draft.documentId.isEmpty) {
      await clear();
      return;
    }
    try {
      await _storage.write(
        jsonEncode(<String, Object?>{
          'documentId': draft.documentId,
          'source': draft.source,
          'path': draft.path,
          'name': draft.name,
        }),
      );
    } catch (_) {
      // Recovery is best-effort in unsupported or restricted hosts.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.remove();
    } catch (_) {
      // Ignore persistence failures; source remains in the live session.
    }
  }
}
