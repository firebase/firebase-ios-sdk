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

import FirebaseAuth
import UIKit

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

  // Implementing this delegate method is needed when swizzling is disabled.
  // Without it, reCAPTCHA's login view controller will not dismiss.
  // Without it, IdP Initiated SAML Sign In will not work.
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for urlContext in URLContexts {
      let url = urlContext.url
      _ = Auth.auth().canHandle(url)
      /// Handle IdP Initiated SAML deep link myapp://saml?resp=<samlResponse>
      if url.scheme?.lowercased() == "myapp", /// replace with your custom scheme
         url.host?.lowercased() == "saml" { /// replace with your host
        let spAcsUrl =
          "https://iostemp-8a944.web.app/googleidp-saml/acs" /// replace with your SP ACS URL
        if let rawQuery = url.query {
          var respValue: String?
          for pair in rawQuery.split(separator: "&", omittingEmptySubsequences: false) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2, parts[0] == "resp" {
              respValue = String(parts[1])
              break
            }
          }
          if let resp = respValue {
            let alert = UIAlertController(
              title: "SAML Sign In",
              message: "Enter Provider ID",
              preferredStyle: .alert
            )
            alert.addTextField { tf in
              tf.placeholder = "Provider ID"
              tf.text = "saml.provider"
              tf.autocapitalizationType = .none
              tf.autocorrectionType = .no
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
              let providerId = alert.textFields?.first?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
              let requestUri = alert.textFields?.last?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
              guard !providerId.isEmpty, !requestUri.isEmpty else { return }
              Task {
                do {
                  _ = try await AppManager.shared.auth().signInWithSamlIdp(
                    ProviderId: providerId,
                    SpAcsUrl: requestUri,
                    SamlResp: resp
                  )
                } catch {
                  print("IdP-initiated SAML sign-in failed with error:", error)
                }
              }
            })
            var top = window?.rootViewController
            while let presented = top?.presentedViewController {
              top = presented
            }
            top?.present(alert, animated: true)
          }
        }
      }
    }

    // URL not auth related; it should be handled separately.
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let incomingURL = userActivity.webpageURL {
      handleIncomingDynamicLink(incomingURL)
    }
  }

  // MARK: - Firebase 🔥

  private func handleIncomingDynamicLink(_ incomingURL: URL) {
    let link = incomingURL.absoluteString

    if AppManager.shared.auth().isSignIn(withEmailLink: link) {
      // Save the link as it will be used in the next step to complete login
      UserDefaults.standard.set(link, forKey: "Link")

      // Post a notification to the PasswordlessViewController to resume authentication
      NotificationCenter.default
        .post(Notification(name: Notification.Name("PasswordlessEmailNotificationSuccess")))
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
