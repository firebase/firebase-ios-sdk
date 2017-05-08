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

  static let isWithinUnitTest: Bool = {
    if let testClass = NSClassFromString("XCTestCase") {
      return true
    } else {
      return false
    }
  }()

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    guard !AppDelegate.isWithinUnitTest else {
      // During unit tests, we don't want to initialize Firebase, since by default we want to able
      // to run unit tests without requiring a non-dummy GoogleService-Info.plist file
      return true
    }

    FirebaseApp.configure()
    Messaging.messaging().delegate = self

    NotificationsController.configure()

    if #available(iOS 8.0, *) {
      // Always register for remote notifications. This will not show a prompt to the user, as by
      // default it will provision silent notifications. We can use UNUserNotificationCenter to
      // request authorization for user-facing notifications.
      application.registerForRemoteNotifications()
    } else {
      // iOS 7 didn't differentiate between user-facing and other notifications, so we should just
      // register for remote notifications
      NotificationsController.shared.registerForUserFacingNotificationsFor(application)
    }

    printFCMToken()
    return true
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
    print("APNS Token: \(deviceToken.hexByteString)")
    NotificationCenter.default.post(name: APNSTokenReceivedNotification, object: nil)
    if #available(iOS 8.0, *) {
    } else {
      // On iOS 7, receiving a device token also means our user notifications were granted, so fire
      // the notification to update our user notifications UI
      NotificationCenter.default.post(name: UserNotificationsChangedNotification, object: nil)
    }
  }

  func application(_ application: UIApplication,
                   didRegister notificationSettings: UIUserNotificationSettings) {
    NotificationCenter.default.post(name: UserNotificationsChangedNotification, object: nil)
  }
}

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
    printFCMToken()
  }
}

