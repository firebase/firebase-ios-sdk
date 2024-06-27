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

class CustomAuthViewController: OtherAuthViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    configureUI(for: .Custom)
  }

  override func buttonTapped() {
    guard let token = textField.text, !token.isEmpty else { return }
    customAuthLogin(token: token)
  }

  // MARK: - Firebase 🔥

  private func customAuthLogin(token: String) {
    AppManager.shared.auth().signIn(withCustomToken: token) { result, error in
      guard error == nil else { return self.displayError(error) }
      self.navigationController?.dismiss(animated: true, completion: {
        self.delegate?.loginDidOccur()
      })
    }
  }
}
