// Copyright 2022 Google LLC
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

import Foundation

/**
 @brief Utility class for constructing Google Sign In credentials.
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRGoogleAuthProvider) open class GoogleAuthProvider: NSObject {
  @objc public static let id = "google.com"

  /**
      @brief Creates an `AuthCredential` for a Google sign in.

      @param IDToken The ID Token from Google.
      @param accessToken The Access Token from Google.
      @return An AuthCredential containing the Google credentials.
   */
  @objc public class func credential(withIDToken IDToken: String,
                                     accessToken: String) -> AuthCredential {
    return GoogleAuthCredential(withIDToken: IDToken, accessToken: accessToken)
  }

  @available(*, unavailable)
  @objc override public init() {
    fatalError("This class is not meant to be initialized.")
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRGoogleAuthCredential) class GoogleAuthCredential: AuthCredential, NSSecureCoding {
  let idToken: String
  let accessToken: String

  init(withIDToken idToken: String, accessToken: String) {
    self.idToken = idToken
    self.accessToken = accessToken
    super.init(provider: GoogleAuthProvider.id)
  }

  override func prepare(_ request: VerifyAssertionRequest) {
    request.providerIDToken = idToken
    request.providerAccessToken = accessToken
  }

  static var supportsSecureCoding = true

  func encode(with coder: NSCoder) {
    coder.encode(idToken, forKey: "idToken")
    coder.encode(accessToken, forKey: "accessToken")
  }

  required init?(coder: NSCoder) {
    guard let idToken = coder.decodeObject(of: NSString.self, forKey: "idToken") as? String,
          let accessToken = coder.decodeObject(of: NSString.self, forKey: "accessToken") as? String
    else {
      return nil
    }
    self.idToken = idToken
    self.accessToken = accessToken
    super.init(provider: GoogleAuthProvider.id)
  }
}
