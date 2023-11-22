// Copyright 2022 Google LLC
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

import FirebaseCore
import FirebaseMessaging
import SwiftUI

@main
struct SampleStandaloneWatchApp_Watch_AppApp: App {
  @WKApplicationDelegateAdaptor(FCMWatchAppDelegate.self) var appDelegate
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

// MARK: - WKApplicationDelegate

class FCMWatchAppDelegate: NSObject, WKApplicationDelegate, MessagingDelegate {
  func applicationDidFinishLaunching() {
    FirebaseApp.configure()
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if granted {
        WKApplication.shared().registerForRemoteNotifications()
      }
    }
    Messaging.messaging().delegate = self
  }

  func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
    // Method swizzling should be disabled in Firebase Messaging on watchOS.
    // Set the APNS token manually as is done here.
    // More information on how to disable -
    // https://firebase.google.com/docs/cloud-messaging/ios/client#method_swizzling_in

    print("APNS didRegisterForRemoteNotifications. Got device token \(deviceToken)")
    Messaging.messaging().apnsToken = deviceToken
  }
}

// MARK: - FCM MessagingDelegate

extension FCMWatchAppDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // Use this FCM token to test sending a push using API or Firebase Console
    print("FCM - didReceiveRegistrationToken \(String(describing: fcmToken))")
  }
}
