// Copyright 2024 Google LLC
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

class MFALoginViewController: OtherAuthViewController {
  var resolver: MultiFactorResolver

  init(resolver: MultiFactorResolver) {
    self.resolver = resolver
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureUI(for: .MfaLogin)
    configureMfaSelections()
  }

  override func buttonTapped() {
    guard let selectedFactorIndex = textField.text, !selectedFactorIndex.isEmpty else { return }
    phoneMfaAuthLogin(selectedFactorIndex: selectedFactorIndex)
  }

  // MARK: - Firebase 🔥

  // Display available factors
  // TODO: optimize and beautify this.
  private func configureMfaSelections() {
    var msg = "available factors: \n"
    for (index, mfaInfo) in resolver.hints.enumerated() {
      msg += "[" + String(index) + "] " + mfaInfo.displayName!
      msg += "\n"
    }
    textFieldInputLabel?.text = msg
  }

  private func phoneMfaAuthLogin(selectedFactorIndex: String) {
    let multifactorInfo = resolver.hints[Int(selectedFactorIndex)!]
    // TODO: support TOTP in sample app
    if multifactorInfo.factorID == TOTPMultiFactorID {
      let error = NSError(
        domain: "SignInError",
        code: -1,
        userInfo: [
          NSLocalizedDescriptionKey: "TOTP MFA factor is not supported",
        ]
      )
      displayError(error)
      return
    }

    signIn(hint: multifactorInfo as! PhoneMultiFactorInfo)
  }

  /// Start the 2nd factor signIn
  private func signIn(hint: PhoneMultiFactorInfo) {
    Task {
      do {
        let verificationId = try await PhoneAuthProvider.provider().verifyPhoneNumber(
          with: hint,
          uiDelegate: nil,
          multiFactorSession: resolver.session
        )
        let verificationCodeFromUser = try await getVerificationCode()
        let credential = PhoneAuthProvider.provider().credential(
          withVerificationID: verificationId,
          verificationCode: verificationCodeFromUser
        )
        let assertion = PhoneMultiFactorGenerator.assertion(with: credential)
        resolver.resolveSignIn(with: assertion) { authResult, error in
          guard error == nil else { return self.displayError(error) }
          self.navigationController?.dismiss(animated: true, completion: {
            self.delegate?.loginDidOccur()
          })
        }
      }
    }
  }

  /// Display the pop up window for end user to enter the one-time code
  private func presentVerificationCodeController(saveHandler: @escaping (String) -> Void) {
    let verificationCodeController = UIAlertController(
      title: "Verification Code",
      message: nil,
      preferredStyle: .alert
    )
    verificationCodeController.addTextField { textfield in
      textfield.placeholder = "Enter the code you received"
      textfield.textContentType = .oneTimeCode
    }

    let onContinue: (UIAlertAction) -> Void = { _ in
      let text = verificationCodeController.textFields!.first!.text!
      saveHandler(text)
    }

    verificationCodeController
      .addAction(UIAlertAction(title: "Continue", style: .default, handler: onContinue))
    verificationCodeController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    present(verificationCodeController, animated: true, completion: nil)
  }

  private func getVerificationCode() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      self.presentVerificationCodeController { code in
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
