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

import Combine
import FirebaseInstallations
import FirebaseMessaging
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate, MessagingDelegate {
  var window: UIWindow?
  let identity = Identity()
  let settings = UserSettings()
  var cancellables = Set<AnyCancellable>()

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    let contentView = ContentView()
    // Choose using delegate for token refresh.
    if settings.shouldUseDelegateThanNotification {
      Messaging.messaging().delegate = self
    }
    // Use a UIHostingController as window root view controller.
    if let windowScene = scene as? UIWindowScene {
      let window = UIWindow(windowScene: windowScene)
      window
        .rootViewController = UIHostingController(rootView: contentView
          .environmentObject(identity)
          .environmentObject(settings))

      self.window = window
      window.makeKeyAndVisible()
    }

    // Choose using notification for token refresh.
    if !settings.shouldUseDelegateThanNotification {
      // Subscribe to token refresh
      NotificationCenter.default
        .publisher(for: Notification.Name.MessagingRegistrationTokenRefreshed)
        .map { $0.object as? String }
        .receive(on: RunLoop.main)
        .assign(to: \Identity.token, on: identity)
        .store(in: &cancellables)
    }

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
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    identity.token = fcmToken
    print("=============================\n")
    print("Did refresh token:\n", identity.token ?? "")
    print("\n=============================\n")
  }
}
