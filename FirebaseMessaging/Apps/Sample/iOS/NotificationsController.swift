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
import UserNotifications

import FirebaseMessaging

enum NotificationsControllerAllowedNotificationType: String {
  case none = "None"
  case silent = "Silent Updates"
  case alert = "Alerts"
  case badge = "Badges"
  case sound = "Sounds"
}

let APNSTokenReceivedNotification: Notification.Name
  = Notification.Name(rawValue: "APNSTokenReceivedNotification")
let UserNotificationsChangedNotification: Notification.Name
  = Notification.Name(rawValue: "UserNotificationsChangedNotification")

class NotificationsController: NSObject {
  static let shared: NotificationsController = {
    let instance = NotificationsController()
    return instance
  }()

  class func configure() {
    let sharedController = NotificationsController.shared
    // Always become the delegate of UNUserNotificationCenter, even before we've requested user
    // permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = sharedController
    }
  }

  func registerForUserFacingNotificationsFor(_ application: UIApplication) {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .badge, .sound],
                              completionHandler: { granted, error in
                                NotificationCenter.default
                                  .post(name: UserNotificationsChangedNotification, object: nil)
                              })
    } else if #available(iOS 8.0, *) {
      let userNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound],
                                                                categories: [])
      application.registerUserNotificationSettings(userNotificationSettings)

    } else {
      application.registerForRemoteNotifications(matching: [.alert, .badge, .sound])
    }
  }

  func getAllowedNotificationTypes(_ completion:
    @escaping (_ allowedTypes: [NotificationsControllerAllowedNotificationType]) -> Void) {
    guard Messaging.messaging().apnsToken != nil else {
      completion([.none])
      return
    }

    var types: [NotificationsControllerAllowedNotificationType] = [.silent]
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
        if settings.alertSetting == .enabled {
          types.append(.alert)
        }
        if settings.badgeSetting == .enabled {
          types.append(.badge)
        }
        if settings.soundSetting == .enabled {
          types.append(.sound)
        }
        DispatchQueue.main.async {
          completion(types)
        }
      })
    } else if #available(iOS 8.0, *) {
      if let userNotificationSettings = UIApplication.shared.currentUserNotificationSettings {
        if userNotificationSettings.types.contains(.alert) {
          types.append(.alert)
        }
        if userNotificationSettings.types.contains(.badge) {
          types.append(.badge)
        }
        if userNotificationSettings.types.contains(.sound) {
          types.append(.sound)
        }
      }
      completion(types)
    } else {
      let enabledTypes = UIApplication.shared.enabledRemoteNotificationTypes()
      if enabledTypes.contains(.alert) {
        types.append(.alert)
      }
      if enabledTypes.contains(.badge) {
        types.append(.badge)
      }
      if enabledTypes.contains(.sound) {
        types.append(.sound)
      }
      completion(types)
    }
  }
}

// MARK: - UNUserNotificationCenterDelegate

@available(iOS 10.0, *)
extension NotificationsController: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler:
                              @escaping (UNNotificationPresentationOptions) -> Void) {
    // Always show the incoming notification, even if the app is in foreground
    print("Received notification in foreground:")
    let jsonString = notification.request.content.userInfo.jsonString ?? "{}"
    print("\(jsonString)")
    completionHandler([.alert, .badge, .sound])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    print("Received notification response")
    let jsonString = response.notification.request.content.userInfo.jsonString ?? "{}"
    print("\(jsonString)")
    completionHandler()
  }
}
