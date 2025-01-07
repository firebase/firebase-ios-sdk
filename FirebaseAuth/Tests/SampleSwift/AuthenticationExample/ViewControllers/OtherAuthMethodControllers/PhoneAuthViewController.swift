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

class PhoneAuthViewController: OtherAuthViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    configureUI(for: .PhoneNumber)
  }

  override func buttonTapped() {
    guard let phoneNumber = textField.text, !phoneNumber.isEmpty else { return }
    phoneAuthLogin(phoneNumber)
  }

  // MARK: - Firebase 🔥

  private func phoneAuthLogin(_ phoneNumber: String) {
    let phoneNumber = String(format: "+%@", phoneNumber)
    Task {
      do {
        let phoneAuthProvider = PhoneAuthProvider.provider()
        let verificationID = try await phoneAuthProvider.verifyPhoneNumber(phoneNumber)
        let verificationCode = try await getVerificationCode()
        let credential = phoneAuthProvider.credential(withVerificationID: verificationID,
                                                      verificationCode: verificationCode)
        self.signin(with: credential)
      } catch {
        self.displayError(error)
      }
    }
  }

  private func signin(with credential: PhoneAuthCredential) {
    AppManager.shared.auth().signIn(with: credential) { result, error in
      guard error == nil else { return self.displayError(error) }
      self.navigationController?.dismiss(animated: true, completion: {
        self.delegate?.loginDidOccur(resolver: nil)
      })
    }
  }

  private func presentPhoneAuthController(saveHandler: @escaping (String) -> Void) {
    let phoneAuthController = UIAlertController(
      title: "Sign in with Phone Auth",
      message: nil,
      preferredStyle: .alert
    )
    phoneAuthController.addTextField { textfield in
      textfield.placeholder = "Enter verification code."
      textfield.textContentType = .oneTimeCode
    }

    let onContinue: (UIAlertAction) -> Void = { _ in
      let text = phoneAuthController.textFields!.first!.text!
      saveHandler(text)
    }

    phoneAuthController
      .addAction(UIAlertAction(title: "Continue", style: .default, handler: onContinue))
    phoneAuthController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    present(phoneAuthController, animated: true, completion: nil)
  }

  private func getVerificationCode() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      self.presentPhoneAuthController { code in
        if code != "" {
          continuation.resume(returning: code)
        } else {
          // Cancelled
          continuation.resume(throwing: NSError())
        }
      }
    }
  }
}
