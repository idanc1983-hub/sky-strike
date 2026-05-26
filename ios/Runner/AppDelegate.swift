import Flutter
import UIKit
import AppTrackingTransparency
import AdSupport

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SkystrikeATT") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "skystrike/ads_att",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "requestATT":
        if #available(iOS 14, *) {
          ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async { result(Int(status.rawValue)) }
          }
        } else {
          result(3)
        }
      case "currentATTStatus":
        if #available(iOS 14, *) {
          result(Int(ATTrackingManager.trackingAuthorizationStatus.rawValue))
        } else {
          result(3)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
