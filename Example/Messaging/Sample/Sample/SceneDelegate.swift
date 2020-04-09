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

import UIKit
import SwiftUI
import FirebaseInstanceID
import FirebaseMessaging
import FirebaseInstallations

class SceneDelegate: UIResponder, UIWindowSceneDelegate, MessagingDelegate {
  var window: UIWindow?
  let identity = Identity()

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    let contentView = ContentView()
    // Use a UIHostingController as window root view controller.
    Messaging.messaging().delegate = self
    if let windowScene = scene as? UIWindowScene {
      let window = UIWindow(windowScene: windowScene)
      window
        .rootViewController = UIHostingController(rootView: contentView.environmentObject(identity))

      self.window = window
      window.makeKeyAndVisible()
    }
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
    identity.token = fcmToken
    InstanceID.instanceID().instanceID { result, error in
      self.identity.instanceID = result?.instanceID ?? ""
    }
  }
}
