import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// A value from Info.plist, or nil when it is missing, empty, or an
  /// unfilled `$(VARIABLE)` placeholder from Secrets.xcconfig.
  private static func configValue(_ key: String) -> String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
    else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty || trimmed.hasPrefix("$(") { return nil }
    return trimmed
  }

  static let mapsApiKey = configValue("GMSApiKey")
  static let googleClientId = configValue("GIDClientID")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = AppDelegate.mapsApiKey {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Tells the Dart side which Google features have keys, so it can show
    // "not set up yet" instead of crashing when a key is missing.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RentARideConfig") {
      let channel = FlutterMethodChannel(
        name: "ng.rentaride/config", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "googleConfig":
          result([
            "mapsConfigured": AppDelegate.mapsApiKey != nil,
            "googleSignInConfigured": AppDelegate.googleClientId != nil,
            // Used for Places search; the key is restricted to this app's
            // bundle ID in Google Cloud, which the requests identify.
            "mapsApiKey": AppDelegate.mapsApiKey ?? "",
          ])
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
