import Cocoa
import FlutterMacOS
import FirebaseAuth

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Method channel: 讓 Dart 端可以呼叫 useUserAccessGroup(nil)
    // 解決 macOS 上 Firebase Auth 的 keychain-error
    let channel = FlutterMethodChannel(
      name: "com.familyledger/auth_config",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      if call.method == "configureKeychainAccess" {
        do {
          try Auth.auth().useUserAccessGroup(nil)
          result(nil)
        } catch {
          result(FlutterError(
            code: "KEYCHAIN_CONFIG_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
