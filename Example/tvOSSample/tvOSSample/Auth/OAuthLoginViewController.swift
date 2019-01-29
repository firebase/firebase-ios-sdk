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

import UIKit

import FirebaseAuth

protocol OAuthLoginDelegate {
  func oauthLogin(_ controller: OAuthLoginViewController, signedInAs user: User)
}

class OAuthLoginViewController: UIViewController {
  // MARK: - Public Properties

  /// The delegate for events related to OAuth login.
  var delegate: OAuthLoginDelegate?

  // MARK: - User Interface

  /// The stackview containing instructions and the site URL / code.
  @IBOutlet weak var instructionsStack: UIStackView!

  /// The URL for the user to navigate to.
  @IBOutlet weak var siteURL: UILabel!

  /// The user code to enter at the above siteURL.
  @IBOutlet weak var userCode: UILabel!

  // MARK: - View Controller Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
    Auth.auth().startSignInForTV(with: self)
  }
}

// MARK: - AuthTVDelegate Conformance

extension OAuthLoginViewController: AuthTVDelegate {
  func auth(_ auth: Auth,
            presentVerificationURL verificationURL: URL,
            withUserCode userCode: String) {
    DispatchQueue.main.async {
      self.siteURL.text = verificationURL.absoluteString
      self.userCode.text = userCode
    }
  }

  func auth(_ auth: Auth, failedToGetVerificationURL error: Error) {
    // TODO: Retry getting the verification URL.
    print("Error: \(error)")
  }

  func auth(_ auth: Auth, retrievedUser user: User) {
    delegate?.oauthLogin(self, signedInAs: user)
  }

  func authTimedOut(_ auth: Auth) {
    // TODO: Wait for user interaction to retry.
    print("Auth timed out! Sad.")
  }
}
