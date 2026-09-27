import 'package:flutter/services.dart';

import 'workbench_window_host.dart';
import 'workbench_window_policy.dart';

/// Sends window configuration to a native desktop runner when one is present.
///
/// The missing-plugin case is intentionally a no-op so the same application
/// composition remains safe on web and on runners that have not implemented
/// the native bridge yet.
class MethodChannelWorkbenchWindowHost implements WorkbenchWindowLifecycleHost {
  const MethodChannelWorkbenchWindowHost({
    this.channel = const MethodChannel('relgeo/window'),
  });

  final MethodChannel channel;

  @override
  Future<void> configure(WorkbenchWindowConfiguration configuration) async {
    try {
      await channel.invokeMethod<void>('configure', <String, Object>{
        'defaultWidth': configuration.defaultSize.width,
        'defaultHeight': configuration.defaultSize.height,
        'minimumWidth': configuration.minimumSize.width,
        'minimumHeight': configuration.minimumSize.height,
      });
    } on MissingPluginException {
      // Web and runners without the optional native bridge keep their
      // platform-default window behavior.
    }
  }

  @override
  Future<void> close() async {
    try {
      await channel.invokeMethod<void>('close');
    } on MissingPluginException {
      // Web and runners without the optional native bridge keep their
      // platform-default lifecycle behavior.
    }
  }
}
