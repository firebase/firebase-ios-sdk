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
import FirebaseDynamicLinks
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  lazy var authNavController: UINavigationController = {
    let navController = UINavigationController(rootViewController: AuthViewController())
    navController.view.backgroundColor = .systemBackground
    return navController
  }()

  lazy var userNavController: UINavigationController = {
    let navController = UINavigationController(rootViewController: UserViewController())
    navController.view.backgroundColor = .systemBackground
    return navController
  }()

  lazy var tabBarController: UITabBarController = {
    let tabBarController = UITabBarController()
    tabBarController.delegate = tabBarController
    tabBarController.view.backgroundColor = .systemBackground
    return tabBarController
  }()

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }

    configureControllers()

    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = tabBarController
    window?.makeKeyAndVisible()
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let incomingURL = userActivity.webpageURL {
      handleIncomingDynamicLink(incomingURL)
    }
  }

  // MARK: - Firebase 🔥

  private func handleIncomingDynamicLink(_ incomingURL: URL) {
    DynamicLinks.dynamicLinks().handleUniversalLink(incomingURL) { dynamicLink, error in
      guard error == nil else {
        return print("ⓧ Error in \(#function): \(error!.localizedDescription)")
      }

      guard let link = dynamicLink?.url?.absoluteString else { return }

      if Auth.auth().isSignIn(withEmailLink: link) {
        // Save the link as it will be used in the next step to complete login
        UserDefaults.standard.set(link, forKey: "Link")

        // Post a notification to the PasswordlessViewController to resume authentication
        NotificationCenter.default
          .post(Notification(name: Notification.Name("PasswordlessEmailNotificationSuccess")))
      }
    }
  }

  // MARK: - Private Helpers

  private func configureControllers() {
    authNavController.configureTabBar(
      title: "Authentication",
      systemImageName: "person.crop.circle.fill.badge.plus"
    )
    userNavController.configureTabBar(title: "Current User", systemImageName: "person.fill")
    tabBarController.viewControllers = [authNavController, userNavController]
  }
}
