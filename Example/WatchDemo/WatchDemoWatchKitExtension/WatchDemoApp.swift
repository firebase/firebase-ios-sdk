// Copyright 2021 Google LLC
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

import SwiftUI
import FirebaseMessaging
import FirebaseCore
//import FirebaseRemoteConfig

@main
struct WatchDemoApp: App {
  @WKExtensionDelegateAdaptor var extensionDelegate: MyExtensionDelegate

  @SceneBuilder var body: some Scene {
    WindowGroup {
      NavigationView {
        ContentView()
      }
    }
    
    WKNotificationScene(controller: NotificationController.self, category: "myCategory")
  }
}

class MyExtensionDelegate: NSObject, WKExtensionDelegate, MessagingDelegate {
    func applicationDidFinishLaunching() {
        FirebaseApp.configure()
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
              if granted {
                WKExtension.shared().registerForRemoteNotifications()
              }
            }
            Messaging.messaging().delegate = self
//            let remoteConfig = RemoteConfig.remoteConfig()
//            remoteConfig.fetchAndActivate { _, error in
//              guard error == nil else {
//                print("error:" + error.debugDescription)
//                return
//              }
//              let defaultOutput = "You have not set up a 'test' key in Remote Config console."
//              let configValue: String =
//                remoteConfig["test"].stringValue ?? defaultOutput
//              print("value:\n" + configValue)
//            }
    }
    
    /// MessagingDelegate
    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
      print("token:\n" + fcmToken!)
      Messaging.messaging().subscribe(toTopic: "watch") { error in
        guard error == nil else {
          print("error:" + error.debugDescription)
          return
        }
        print("Successfully subscribed to topic")
      }
    }

    /// WKExtensionDelegate
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
      /// Swizzling should be disabled in Messaging for watchOS, set APNS token manually.
      print("Set APNS Token\n")
      Messaging.messaging().apnsToken = deviceToken
    }
}
