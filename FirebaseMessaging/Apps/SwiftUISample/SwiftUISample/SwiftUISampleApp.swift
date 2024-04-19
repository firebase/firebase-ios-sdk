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
import FirebaseCore
import FirebaseInstallations
import FirebaseMessaging
import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate,
  MessagingDelegate {
  let identity = Identity()
  var cancellables = Set<AnyCancellable>()

  // Must implement the method to make swizzling work in SwiftUI lifecycle.
  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {}

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication
                     .LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()

    // Request permissions for push notifications
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if error != nil {
        print("Failed requesting notification permission: ", error ?? "")
      }
    }
    application.registerForRemoteNotifications()

    // Observe token refresh - two ways
    // First way: use MessagingDelegate
    let settings = UserSettings()
    if settings.shouldUseDelegateThanNotification {
      Messaging.messaging().delegate = self
    } else {
      // Second way: use notification to subscribe to token refresh
      NotificationCenter.default
        .publisher(for: Notification.Name.MessagingRegistrationTokenRefreshed)
        .map { $0.object as? String }
        .receive(on: RunLoop.main)
        .assign(to: \Identity.token, on: identity)
        .store(in: &cancellables)
    }

    // Subscribe to fid changes
    // Somehow FID notification is not triggered during app start, will have to invest
    refreshInstallationsID()
    NotificationCenter.default
      .publisher(for: Notification.Name.InstallationIDDidChange)
      .receive(on: RunLoop.main)
      .sink(receiveValue: { _ in
        self.refreshInstallationsID()
      })
      .store(in: &cancellables)
    return true
  }

  func refreshInstallationsID() {
    Installations.installations().installationID(completion: { fid, error in
      if let error = error as NSError? {
        print("Failed to get FID: ", error)
        return
      }
      self.identity.installationsID = fid
    })
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    identity.token = fcmToken
    print("=============================\n")
    print("Did refresh token:\n", identity.token ?? "")
    print("\n=============================\n")
  }
}

@main
struct SwiftUISampleApp: App {
  // Add the adapter to access notifications APIs in AppDelegate
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      ContentView().environmentObject(appDelegate.identity).environmentObject(UserSettings())
    }
  }
}
