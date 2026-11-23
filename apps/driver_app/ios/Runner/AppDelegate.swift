import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// A value from Info.plist, or nil when missing, empty, or an unfilled
  /// `$(VARIABLE)` placeholder from Secrets.xcconfig.
  private static func configValue(_ key: String) -> String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty || trimmed.hasPrefix("$(") { return nil }
    return trimmed
  }

  static let mapsApiKey = configValue("GMSApiKey")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = AppDelegate.mapsApiKey {
      GMSServices.provideAPIKey(key)
    }
    GeneratedPluginRegistrant.register(with: self)

    // Lets the Dart side hide the map when no key is configured.
    if let registrar = self.registrar(forPlugin: "RentARideConfig") {
      let channel = FlutterMethodChannel(name: "ng.rentaride/config", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "googleConfig" {
          result(["mapsConfigured": AppDelegate.mapsApiKey != nil])
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
