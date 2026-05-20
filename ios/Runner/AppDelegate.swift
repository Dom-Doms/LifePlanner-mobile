import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let notificationChannel = FlutterMethodChannel(
        name: "lifeplanner_mobile/local_notifications",
        binaryMessenger: controller.binaryMessenger
      )
      notificationChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "requestPermission":
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            result(granted)
          }
        case "areNotificationsEnabled":
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            result(settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
          }
        case "show":
          let arguments = call.arguments as? [String: Any]
          let id = arguments?["id"] as? Int ?? 1
          let content = UNMutableNotificationContent()
          content.title = arguments?["title"] as? String ?? "LifePlanner"
          content.body = arguments?["body"] as? String ?? ""
          content.sound = .default
          let request = UNNotificationRequest(
            identifier: "lifeplanner-\(id)",
            content: content,
            trigger: nil
          )
          UNUserNotificationCenter.current().add(request) { _ in result(nil) }
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let storageChannel = FlutterMethodChannel(
        name: "lifeplanner_mobile/session_storage",
        binaryMessenger: controller.binaryMessenger
      )
      storageChannel.setMethodCallHandler { call, result in
        let defaults = UserDefaults.standard
        switch call.method {
        case "read":
          result(defaults.string(forKey: "lifeplanner_session"))
        case "write":
          let arguments = call.arguments as? [String: Any]
          defaults.set(arguments?["value"] as? String, forKey: "lifeplanner_session")
          result(nil)
        case "clear":
          defaults.removeObject(forKey: "lifeplanner_session")
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
