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

class PasswordlessViewController: OtherAuthViewController {
  private var email: String!

  override func viewDidLoad() {
    super.viewDidLoad()
    configureUI(for: .Passwordless)
    registerForLoginNotifications()
  }

  override func buttonTapped() {
    guard let email = textField.text, !email.isEmpty else { return }
    sendSignInLink(to: email)
  }

  // MARK: - Firebase 🔥

  private let authorizedDomain: String = "ENTER AUTHORIZED DOMAIN"

  private func sendSignInLink(to email: String) {
    let actionCodeSettings = ActionCodeSettings()

    // Update "demo" to match the path defined in the dynamic link.
    let stringURL = "https://\(authorizedDomain)/demo"
    actionCodeSettings.url = URL(string: stringURL)
    // The sign-in operation must be completed in the app.
    actionCodeSettings.handleCodeInApp = true
    actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier!)

    AppManager.shared.auth()
      .sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings) { error in
        guard error == nil else { return self.displayError(error) }

        // Set `email` property as it will be used to complete sign in after opening email link
        self.email = email
        print("successfully sent email")
      }
  }

  @objc
  private func passwordlessSignIn() {
    // Retrieve link that we stored in user defaults in `SceneDelegate`.
    guard let link = UserDefaults.standard.value(forKey: "Link") as? String else { return }

    AppManager.shared.auth().signIn(withEmail: email, link: link) { result, error in
      guard error == nil else { return self.displayError(error) }

      guard let currentUser = AppManager.shared.auth().currentUser else { return }

      if currentUser.isEmailVerified {
        print("User verified with passwordless email.")

        self.navigationController?.dismiss(animated: true) {
          self.delegate?.loginDidOccur()
        }
      } else {
        print("User could not be verified by passwordless email")
      }
    }
  }

  // MARK: - Private Helpers

  private func registerForLoginNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(passwordlessSignIn),
      name: Notification.Name("PasswordlessEmailNotificationSuccess"),
      object: nil
    )
  }
}
