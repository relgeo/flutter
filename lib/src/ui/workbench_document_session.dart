import 'package:flutter/foundation.dart';

/// Tracks editable source and the last successfully saved/opened source.
///
/// The session does not decide how a host confirms destructive lifecycle
/// actions. It exposes a stable dirty-state boundary for that host decision.
class WorkbenchDocumentSession extends ChangeNotifier {
  WorkbenchDocumentSession({required String initialSource})
    : _source = initialSource,
      _savedSource = initialSource;

  String _source;
  String _savedSource;
  String? _path;
  String? _name;

  String get source => _source;
  String? get path => _path;
  String? get name => _name;
  bool get isDirty => _source != _savedSource;

  void updateSource(String source) {
    if (_source == source) return;
    _source = source;
    notifyListeners();
  }

  void markLoaded({required String source, String? path, String? name}) {
    _source = source;
    _savedSource = source;
    _path = path;
    _name = name;
    notifyListeners();
  }

  void markSaved({required String source, String? path, String? name}) {
    _source = source;
    _savedSource = source;
    _path = path;
    _name = name;
    notifyListeners();
  }

  void reset({String source = ''}) {
    markLoaded(source: source);
  }
}
