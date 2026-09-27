import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/main.dart';
import 'package:relgeo_flutter/src/ui/workbench_window_host.dart';
import 'package:relgeo_flutter/src/ui/workbench_window_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingWindowHost implements WorkbenchWindowHost {
  WorkbenchWindowConfiguration? configuration;

  @override
  Future<void> configure(WorkbenchWindowConfiguration configuration) async {
    this.configuration = configuration;
  }
}

class _LifecycleWindowHost extends _RecordingWindowHost
    implements WorkbenchWindowLifecycleHost {
  int closeCount = 0;

  @override
  Future<void> close() async {
    closeCount++;
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('application delegates default sizing to the window host', (
    WidgetTester tester,
  ) async {
    final host = _RecordingWindowHost();

    await tester.pumpWidget(RelGeoCADApp(windowHost: host));
    await tester.pumpAndSettle();

    expect(
      host.configuration?.defaultSize,
      WorkbenchWindowPolicy.defaultWindowSize,
    );
    expect(
      host.configuration?.minimumSize,
      WorkbenchWindowPolicy.minimumWindowSize,
    );
  });

  testWidgets('application exposes quit when the host supports lifecycle', (
    WidgetTester tester,
  ) async {
    final host = _LifecycleWindowHost();

    await tester.pumpWidget(RelGeoCADApp(windowHost: host));
    await tester.pumpAndSettle();

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quit RelGeo'));
    await tester.pump();

    expect(host.closeCount, 1);
  });
}
