import 'package:flutter/foundation.dart';
import 'package:relgeo_mcp/relgeo_mcp.dart';

/// Tracks editable source and the last successfully saved/opened source.
///
/// The session does not decide how a host confirms destructive lifecycle
/// actions. It exposes a stable dirty-state boundary for that host decision.
class WorkbenchDocumentSession extends ChangeNotifier {
  WorkbenchDocumentSession({required String initialSource, String? documentId})
    : _documentId = documentId ?? _nextUntitledDocumentId(),
      _source = initialSource,
      _savedSource = initialSource;

  static int _untitledDocumentSequence = 0;

  static String _nextUntitledDocumentId() {
    _untitledDocumentSequence += 1;
    return 'untitled-${_untitledDocumentSequence.toString()}';
  }

  String _documentId;
  String _source;
  String _savedSource;
  String? _path;
  String? _name;
  int _revision = 0;
  bool _isOpen = true;

  String get documentId => _documentId;
  String get source => _source;
  String? get path => _path;
  String? get name => _name;
  int get revision => _revision;
  bool get isOpen => _isOpen;
  bool get isDirty => _source != _savedSource;

  ActiveDocumentSnapshot snapshot({
    List<DocumentDiagnostic> diagnostics = const <DocumentDiagnostic>[],
  }) {
    return ActiveDocumentSnapshot(
      documentId: _documentId,
      name: _name ?? _path ?? 'Untitled RelGeo document',
      path: _path,
      source: _source,
      revision: _revision,
      dirty: isDirty,
      diagnostics: diagnostics,
    );
  }

  void updateSource(String source) {
    if (!_isOpen) return;
    if (_source == source) return;
    _source = source;
    _revision += 1;
    notifyListeners();
  }

  void markLoaded({
    required String source,
    String? path,
    String? name,
    String? documentId,
  }) {
    _isOpen = true;
    _documentId =
        documentId ??
        (path != null && path.isNotEmpty ? path : _nextUntitledDocumentId());
    _source = source;
    _savedSource = source;
    _path = path;
    _name = name;
    _revision = 0;
    notifyListeners();
  }

  void markSaved({required String source, String? path, String? name}) {
    if (!_isOpen) return;
    _source = source;
    _savedSource = source;
    _path = path;
    _name = name;
    notifyListeners();
  }

  /// Applies a source update only if the read snapshot is still current.
  ///
  /// This is the session-side revision guard. The editor adapter performs the
  /// actual source replacement once so the editor records one undo entry.
  bool applySourceIfCurrent({
    required String documentId,
    required int baseRevision,
    required String source,
  }) {
    if (!_isOpen || documentId != _documentId || baseRevision != _revision) {
      return false;
    }
    updateSource(source);
    return true;
  }

  /// Closes the active document without leaving a usable blank MCP target.
  ///
  /// The next [markLoaded] call creates the next active session. Clearing the
  /// identity and revision here ensures an edit captured before close cannot
  /// be replayed against a later document.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    _documentId = _nextUntitledDocumentId();
    _source = '';
    _savedSource = '';
    _path = null;
    _name = null;
    _revision = 0;
    notifyListeners();
  }

  /// Reloads the same document identity from its owner and invalidates edits
  /// based on the previous source by advancing the monotonic revision.
  void reload({required String source}) {
    if (!_isOpen) {
      markLoaded(source: source);
      return;
    }
    _source = source;
    _savedSource = source;
    _revision += 1;
    notifyListeners();
  }

  /// Backwards-compatible blank-document reset used by older host callers.
  /// New lifecycle code should call [close] followed by [markLoaded].
  void reset({String source = ''}) {
    markLoaded(source: source);
  }
}
