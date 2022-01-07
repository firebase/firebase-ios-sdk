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

import Combine
import UIKit
import SwiftUI
import FirebaseCore
import FirebaseInstallations
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  let identity = Identity()
  let settings = UserSettings()
  var cancellables = Set<AnyCancellable>()

  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication
                     .LaunchOptionsKey: Any]? = nil) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    application.delegate = self

    // Request permissions for push notifications
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if error != nil {
        print("Failed requesting notification permission: ", error ?? "")
      }
    }
    application.registerForRemoteNotifications()
    // Subscribe to token refresh
    NotificationCenter.default
      .publisher(for: Notification.Name.MessagingRegistrationTokenRefreshed)
      .map { $0.object as? String }
      .receive(on: RunLoop.main)
      .assign(to: \Identity.token, on: identity)
      .store(in: &cancellables)

    // Subscribe to fid changes
    NotificationCenter.default
      .publisher(for: Notification.Name.InstallationIDDidChange)
      .receive(on: RunLoop.main)
      .sink(receiveValue: { _ in
        Installations.installations().installationID(completion: { fid, error in
          if let error = error as NSError? {
            print("Failed to get FID: ", error)
            return
          }
          self.identity.installationsID = fid
        })
      })
      .store(in: &cancellables)
    return true
  }
}

@main
struct SwiftUISampleApp: App {
  // Add the adapter to access notifications APIs in AppDelegate
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      ContentView().environmentObject(appDelegate.identity).environmentObject(appDelegate.settings)
    }
  }
}
