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

import UIKit
import SwiftUI
import FirebaseCore
import FirebaseMessaging

@main

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
          FirebaseApp.configure()
          application.delegate = self

          let center = UNUserNotificationCenter.current()
          center.delegate = self

          center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if error != nil {
              print("Failed requesting notification permission: ", error ?? "")
            }
          }
          application.registerForRemoteNotifications()
        return true
    }
}

struct SwiftUISampleApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
   
  var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
