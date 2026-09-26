import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_window_policy.dart';

void main() {
  test('publishes stable desktop window dimensions', () {
    expect(WorkbenchWindowPolicy.defaultWindowSize, const Size(1440, 900));
    expect(WorkbenchWindowPolicy.minimumWindowSize, const Size(1024, 640));
  });

  test('selects compact mode below the desktop breakpoint', () {
    expect(
      WorkbenchWindowPolicy.layoutModeForWidth(1180),
      WorkbenchLayoutMode.desktop,
    );
    expect(
      WorkbenchWindowPolicy.layoutModeForWidth(1179.9),
      WorkbenchLayoutMode.compact,
    );
  });

  test('guards the minimum size for the three-panel shell', () {
    expect(
      WorkbenchWindowPolicy.supportsThreePanelLayout(const Size(1024, 640)),
      isTrue,
    );
    expect(
      WorkbenchWindowPolicy.supportsThreePanelLayout(const Size(1023, 640)),
      isFalse,
    );
    expect(
      WorkbenchWindowPolicy.supportsThreePanelLayout(const Size(1024, 639)),
      isFalse,
    );
  });
}
