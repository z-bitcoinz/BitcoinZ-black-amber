import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // MethodChannel for dock badge updates
    let badgeChannel = FlutterMethodChannel(name: "com.bitcoinz/app_badge",
                                            binaryMessenger: flutterViewController.engine.binaryMessenger)

    badgeChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setBadge":
        if let args = call.arguments as? [String: Any], let count = args["count"] as? Int {
          DispatchQueue.main.async {
            if count > 0 {
              NSApp.dockTile.badgeLabel = String(count)
            } else {
              NSApp.dockTile.badgeLabel = nil
            }
            NSApp.dockTile.display()
            result(nil)
          }
        } else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing 'count'", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
