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

/// Best-effort persistence boundary for unsaved source recovery.
class WorkbenchDocumentRecoveryStore {
  const WorkbenchDocumentRecoveryStore();

  static const _documentIdKey = 'relgeo.workbench.recovery.documentId';
  static const _sourceKey = 'relgeo.workbench.recovery.source';
  static const _pathKey = 'relgeo.workbench.recovery.path';
  static const _nameKey = 'relgeo.workbench.recovery.name';

  Future<WorkbenchRecoveryDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final source = prefs.getString(_sourceKey);
      final documentId = prefs.getString(_documentIdKey);
      if (source == null || documentId == null || source.isEmpty) return null;
      return WorkbenchRecoveryDraft(
        documentId: documentId,
        source: source,
        path: prefs.getString(_pathKey),
        name: prefs.getString(_nameKey),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(WorkbenchRecoveryDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_documentIdKey, draft.documentId);
      await prefs.setString(_sourceKey, draft.source);
      if (draft.path == null) {
        await prefs.remove(_pathKey);
      } else {
        await prefs.setString(_pathKey, draft.path!);
      }
      if (draft.name == null) {
        await prefs.remove(_nameKey);
      } else {
        await prefs.setString(_nameKey, draft.name!);
      }
    } catch (_) {
      // Recovery is best-effort in unsupported or restricted hosts.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_documentIdKey);
      await prefs.remove(_sourceKey);
      await prefs.remove(_pathKey);
      await prefs.remove(_nameKey);
    } catch (_) {
      // Ignore persistence failures; source remains in the live session.
    }
  }
}
