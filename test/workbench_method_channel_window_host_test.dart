import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_method_channel_window_host.dart';
import 'package:relgeo_flutter/src/ui/workbench_window_policy.dart';

void main() {
  test('method channel window host sends the policy dimensions', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('relgeo/test-window');
    MethodCall? receivedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return null;
        });

    try {
      await const MethodChannelWorkbenchWindowHost(channel: channel).configure(
        WorkbenchWindowPolicy.defaultConfiguration,
      );
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }

    expect(receivedCall?.method, 'configure');
    expect(receivedCall?.arguments, <String, Object>{
      'defaultWidth': 1440.0,
      'defaultHeight': 900.0,
      'minimumWidth': 1024.0,
      'minimumHeight': 640.0,
    });
  });
}
