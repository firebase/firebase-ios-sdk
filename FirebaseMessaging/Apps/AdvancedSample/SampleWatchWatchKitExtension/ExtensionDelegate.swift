// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import WatchKit

import FirebaseCore
import FirebaseMessaging

class ExtensionDelegate: NSObject, WKExtensionDelegate, MessagingDelegate {
  func applicationDidFinishLaunching() {
    FirebaseApp.configure()
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if granted {
        WKExtension.shared().registerForRemoteNotifications()
      }
    }
    Messaging.messaging().delegate = self
  }

  /// MessagingDelegate
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("token:\n" + fcmToken!)
    Messaging.messaging().subscribe(toTopic: "watch") { error in
      if error != nil {
        print("error:" + error.debugDescription)
      } else {
        print("Successfully subscribed to topic")
      }
    }
  }

  /// WKExtensionDelegate
  func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
    /// Swizzling should be disabled in Messaging for watchOS, set APNS token manually.
    print("Set APNS Token\n")
    Messaging.messaging().apnsToken = deviceToken
  }
}
