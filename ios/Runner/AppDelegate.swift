import Flutter
import UIKit
import UserNotifications
import native_geofence

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // A geofence that fires while the app is closed wakes a background engine
    // of its own, and that engine starts with no plugins registered. Without
    // this the plugin refuses to register at all and the app dies on launch.
    // It has to be set before the implicit engine registers anything below.
    NativeGeofencePlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // Required for the notification to be delivered to the plugin while the
    // app is in the foreground, and for the Done / Snooze buttons to reach the
    // action handler at all.
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
