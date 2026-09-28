import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A filesystem document remembered by the desktop workbench.
class WorkbenchRecentDocument {
  const WorkbenchRecentDocument({required this.path, required this.name});

  final String path;
  final String name;

  Map<String, String> toJson() => <String, String>{'path': path, 'name': name};

  static WorkbenchRecentDocument? fromJson(Object? value) {
    if (value is! Map) return null;
    final path = value['path'];
    final name = value['name'];
    if (path is! String || path.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    return WorkbenchRecentDocument(path: path, name: name);
  }
}

/// Persists a small, best-effort list of recently opened or saved documents.
class WorkbenchRecentDocumentsStore {
  const WorkbenchRecentDocumentsStore({this.maxItems = 10});

  static const storageKey = 'relgeo.workbench.recentDocuments.v1';

  final int maxItems;

  Future<List<WorkbenchRecentDocument>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(storageKey) ?? const <String>[];
      return raw
          .map((item) {
            try {
              return WorkbenchRecentDocument.fromJson(jsonDecode(item));
            } catch (_) {
              return null;
            }
          })
          .whereType<WorkbenchRecentDocument>()
          .toList(growable: false);
    } catch (_) {
      return const <WorkbenchRecentDocument>[];
    }
  }

  Future<void> record(WorkbenchRecentDocument document) async {
    final current = await load();
    final next = <WorkbenchRecentDocument>[
      document,
      ...current.where((item) => item.path != document.path),
    ];
    if (next.length > maxItems) {
      next.removeRange(maxItems, next.length);
    }
    await _save(next);
  }

  Future<void> remove(String path) async {
    final current = await load();
    await _save(current.where((item) => item.path != path).toList());
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // Persistence is a convenience and must not block document editing.
    }
  }

  Future<void> _save(List<WorkbenchRecentDocument> documents) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        storageKey,
        documents.map((document) => jsonEncode(document.toJson())).toList(),
      );
    } catch (_) {
      // Persistence is a convenience and must not block document editing.
    }
  }
}
