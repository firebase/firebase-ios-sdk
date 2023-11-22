// Copyright 2017 Google
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

protocol EmailLoginDelegate {
  func emailLogin(_ controller: EmailLoginViewController, signedInAs user: User)
  func emailLogin(_ controller: EmailLoginViewController, failedWithError error: Error)
}

class EmailLoginViewController: UIViewController {
  // MARK: - Public Properties

  var delegate: EmailLoginDelegate?

  // MARK: - User Interface

  @IBOutlet private var emailAddress: UITextField!
  @IBOutlet private var password: UITextField!

  // MARK: - User Actions

  @IBAction func logInButtonHit(_ sender: UIButton) {
    guard let (email, password) = validatedInputs() else { return }

    Auth.auth().signIn(withEmail: email, password: password) { [unowned self] result, error in
      guard let result = result else {
        print("Error signing in: \(error!)")
        self.delegate?.emailLogin(self, failedWithError: error!)
        return
      }

      print("Signed in as user: \(result.user.uid)")
      self.delegate?.emailLogin(self, signedInAs: result.user)
    }
  }

  @IBAction func signUpButtonHit(_ sender: UIButton) {
    guard let (email, password) = validatedInputs() else { return }

    Auth.auth().createUser(withEmail: email, password: password) { [unowned self] result, error in
      guard let result = result else {
        print("Error signing up: \(error!)")
        self.delegate?.emailLogin(self, failedWithError: error!)
        return
      }

      print("Created new user: \(result.user.uid)!")
      self.delegate?.emailLogin(self, signedInAs: result.user)
    }
  }

  // MARK: - View Controller Lifecycle

  override func viewDidLoad() {}

  // MARK: - Helper Methods

  /// Validate the inputs for user email and password, returning the username and password if valid,
  /// otherwise nil.
  private func validatedInputs() -> (email: String, password: String)? {
    guard let userEmail = emailAddress.text, userEmail.count >= 6 else {
      presentError(with: "Email address isn't long enough.")
      return nil
    }

    guard let userPassword = password.text, userPassword.count >= 6 else {
      presentError(with: "Password is not long enough!")
      return nil
    }

    return (userEmail, userPassword)
  }

  func presentError(with text: String) {
    let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Okay", style: .default))
    present(alert, animated: true)
  }
}
