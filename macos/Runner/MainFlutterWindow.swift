import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let channel = FlutterMethodChannel(
      name: "relgeo/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "close" {
        self?.performClose(nil)
        result(nil)
        return
      }
      guard call.method == "configure",
            let arguments = call.arguments as? [String: Any],
            let defaultWidth = arguments["defaultWidth"] as? Double,
            let defaultHeight = arguments["defaultHeight"] as? Double,
            let minimumWidth = arguments["minimumWidth"] as? Double,
            let minimumHeight = arguments["minimumHeight"] as? Double else {
        result(FlutterMethodNotImplemented)
        return
      }

      self?.minSize = NSSize(width: minimumWidth, height: minimumHeight)
      self?.setContentSize(NSSize(width: defaultWidth, height: defaultHeight))
      result(nil)
    }
    windowChannel = channel

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
