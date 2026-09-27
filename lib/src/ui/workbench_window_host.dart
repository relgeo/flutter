import 'workbench_window_policy.dart';

/// Native window integration boundary.
///
/// macOS, Linux, and Windows runners can implement this interface without
/// making the Flutter composition layer import platform-specific APIs.
abstract interface class WorkbenchWindowHost {
  Future<void> configure(WorkbenchWindowConfiguration configuration);
}

/// Optional lifecycle operations supported by a native desktop window host.
///
/// This is a separate interface so existing hosts that only implement window
/// sizing remain source-compatible. The workbench can expose application quit
/// only when the host explicitly supports closing its native window.
abstract interface class WorkbenchWindowLifecycleHost
    implements WorkbenchWindowHost {
  Future<void> close();
}
