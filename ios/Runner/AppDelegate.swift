import Flutter
import UIKit
import GoogleMaps


@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Inicializa aquí tu API Key (idéntica a la del Info.plist)
    GMSServices.provideAPIKey("AIzaSyAddHsD3cuLiMrdG7CyfdktWpitgdheePQ")

    // Luego registra Flutter y demás plugins
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

