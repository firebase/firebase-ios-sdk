/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit
import FirebaseDev
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    Messaging.messaging().delegate = self

    // Always register for user-facing notifications, for now.
    // TODO: Make this a separate action, that the user can initiate, to highlight the difference
    // between registering for remote notifications and user notifications.
    registerForUserFacingNotificationsFor(application)

    if #available(iOS 8.0, *) {
      // Always register for remote notifications. This will not show a prompt to the user, as by
      // default it will provision silent notifications. We can use UNUserNotificationCenter to
      // request authorization for user-facing notifications.
      application.registerForRemoteNotifications()
    }

    printFCMToken()
    return true
  }

  func registerForUserFacingNotificationsFor(_ application: UIApplication) {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .badge, .sound],
                              completionHandler: { (granted, error) in

        })
      UNUserNotificationCenter.current().delegate = self
    } else if #available(iOS 8.0, *) {
      let userNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound],
                                                                categories: [])
      application.registerUserNotificationSettings(userNotificationSettings)

    } else {
      application.registerForRemoteNotifications(matching: [.alert, .badge, .sound])
    }
  }

  func printFCMToken() {
    if let token = Messaging.messaging().fcmToken {
      print("FCM Token: \(token)")
    } else {
      print("FCM Token: nil")
    }
  }

  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Print APNS token as a string of bytes in hex
    // See: http://stackoverflow.com/a/40031342/9849
    let apnsTokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("APNS Token: \(apnsTokenString)")
  }
}

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
    printFCMToken()
  }
}

@available(iOS 10.0, *)
extension AppDelegate: UNUserNotificationCenterDelegate {

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler:
    @escaping (UNNotificationPresentationOptions) -> Void) {
    // Always show the incoming notification, even if the app is in foreground
    completionHandler([.alert, .badge, .sound])
  }
}

