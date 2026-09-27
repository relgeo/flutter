import 'package:flutter/widgets.dart';

enum WorkbenchLayoutMode { desktop, compact }

/// Host-neutral window configuration passed to native runners.
@immutable
class WorkbenchWindowConfiguration {
  const WorkbenchWindowConfiguration({
    required this.defaultSize,
    required this.minimumSize,
  });

  final Size defaultSize;
  final Size minimumSize;
}

/// Platform-independent window and layout contract for the desktop workbench.
///
/// Native runners may apply [defaultWindowSize] and [minimumWindowSize] through
/// their host integration. Flutter layout code can use [layoutModeForWidth]
/// without importing platform-specific window APIs.
class WorkbenchWindowPolicy {
  const WorkbenchWindowPolicy._();

  static const Size defaultWindowSize = Size(1440, 900);
  static const Size minimumWindowSize = Size(1024, 640);
  static const double compactWidthBreakpoint = 1180;
  static const WorkbenchWindowConfiguration defaultConfiguration =
      WorkbenchWindowConfiguration(
        defaultSize: defaultWindowSize,
        minimumSize: minimumWindowSize,
      );

  static WorkbenchLayoutMode layoutModeForWidth(double width) {
    return width < compactWidthBreakpoint
        ? WorkbenchLayoutMode.compact
        : WorkbenchLayoutMode.desktop;
  }

  static bool supportsThreePanelLayout(Size size) {
    return size.width >= minimumWindowSize.width &&
        size.height >= minimumWindowSize.height;
  }
}
