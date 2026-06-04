import Flutter
import UIKit

final class AppIconPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "fiers_artisans/app_icon",
      binaryMessenger: registrar.messenger()
    )
    let instance = AppIconPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setThemeIcon" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard #available(iOS 10.3, *) else {
      result(nil)
      return
    }

    guard UIApplication.shared.supportsAlternateIcons else {
      result(nil)
      return
    }

    let args = call.arguments as? [String: Any]
    let isDark = (args?["isDark"] as? Bool) ?? false
    let targetName: String? = isDark ? "AppIconDark" : nil

    if UIApplication.shared.alternateIconName == targetName {
      result(nil)
      return
    }

    UIApplication.shared.setAlternateIconName(targetName) { error in
      if let error {
        result(
          FlutterError(
            code: "ICON_SWITCH_FAILED",
            message: error.localizedDescription,
            details: nil
          )
        )
      } else {
        result(nil)
      }
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppIconPlugin")
    AppIconPlugin.register(with: registrar)
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
