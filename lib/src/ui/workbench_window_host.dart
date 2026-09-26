import 'workbench_window_policy.dart';

/// Native window integration boundary.
///
/// macOS, Linux, and Windows runners can implement this interface without
/// making the Flutter composition layer import platform-specific APIs.
abstract interface class WorkbenchWindowHost {
  Future<void> configure(WorkbenchWindowConfiguration configuration);
}
