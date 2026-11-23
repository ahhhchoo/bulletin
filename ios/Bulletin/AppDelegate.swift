import UIKit
import FirebaseAuth
import FirebaseCore

/// SwiftUI hides the app delegate, so Firebase can't find it on its own. Registering this one lets phone sign-in
/// receive the silent push Firebase uses to check the app is real, and the link back from the reCAPTCHA check.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Here, not in App.init: Firebase creates Auth the moment it is configured, and Auth looks for the running app,
        // which doesn't exist yet that early (phone sign-in then fails with "notification not forwarded").
        FirebaseApp.configure()
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // a push meant for phone sign-in is Firebase's; nothing else is sent yet
        _ = Auth.auth().canHandleNotification(userInfo)
        completionHandler(.noData)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Auth.auth().canHandle(url)
    }
}
