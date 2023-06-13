// Copyright 2023 Google LLC
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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIROAuthCredential) public class OAuthCredential: AuthCredential, NSSecureCoding {
  /** @property IDToken
      @brief The ID Token associated with this credential.
   */
  @objc(IDToken) public let idToken: String?

  /** @property accessToken
      @brief The access token associated with this credential.
   */
  @objc public let accessToken: String?

  /** @property secret
      @brief The secret associated with this credential. This will be nil for OAuth 2.0 providers.
      @detail OAuthCredential already exposes a providerId getter. This will help the developer
          determine whether an access token/secret pair is needed.
   */
  @objc public let secret: String?

  // TODO: delete objc's and public's below
  // internal
  @objc public let OAuthResponseURLString: String?
  @objc public let sessionID: String?
  @objc public let pendingToken: String?
  let fullName: PersonNameComponents?
  // private
  @objc public let rawNonce: String?

  // TODO: Remove public objc
  @objc public init(withProviderID providerID: String,
                    idToken: String? = nil,
                    rawNonce: String? = nil,
                    accessToken: String? = nil,
                    secret: String? = nil,
                    fullName: PersonNameComponents? = nil,
                    pendingToken: String? = nil) {
    self.idToken = idToken
    self.rawNonce = rawNonce
    self.accessToken = accessToken
    self.pendingToken = pendingToken
    self.secret = secret
    self.fullName = fullName
    OAuthResponseURLString = nil
    sessionID = nil
    super.init(provider: providerID)
  }

  @objc public init(withProviderID providerID: String,
                    sessionID: String,
                    OAuthResponseURLString: String) {
    self.sessionID = sessionID
    self.OAuthResponseURLString = OAuthResponseURLString
    accessToken = nil
    pendingToken = nil
    secret = nil
    idToken = nil
    rawNonce = nil
    fullName = nil
    super.init(provider: providerID)
  }

  @objc public convenience init?(withVerifyAssertionResponse response: VerifyAssertionResponse) {
    guard Self.nonEmptyString(response.oauthIDToken) ||
      Self.nonEmptyString(response.oauthAccessToken) ||
      Self.nonEmptyString(response.oauthSecretToken) else {
      return nil
    }
    self.init(withProviderID: response.providerID ?? OAuthProvider.id,
              idToken: response.oauthIDToken,
              rawNonce: nil,
              accessToken: response.oauthAccessToken,
              secret: response.oauthSecretToken,
              pendingToken: response.pendingToken)
  }

  @objc override public func prepare(_ request: VerifyAssertionRequest) {
    request.providerIDToken = idToken
    request.providerRawNonce = rawNonce
    request.providerAccessToken = accessToken
    request.requestURI = OAuthResponseURLString
    request.sessionID = sessionID
    request.providerOAuthTokenSecret = secret
    request.fullName = fullName
    request.pendingToken = pendingToken
  }

  // MARK: Secure Coding

  public static var supportsSecureCoding: Bool = true

  public func encode(with coder: NSCoder) {
    coder.encode(idToken, forKey: "IDToken")
    coder.encode(rawNonce, forKey: "rawNonce")
    coder.encode(accessToken, forKey: "accessToken")
    coder.encode(pendingToken, forKey: "pendingToken")
    coder.encode(secret, forKey: "secret")
    coder.encode(fullName, forKey: "fullName")
  }

  public required init?(coder: NSCoder) {
    idToken = coder.decodeObject(forKey: "IDToken") as? String
    rawNonce = coder.decodeObject(forKey: "rawNonce") as? String
    accessToken = coder.decodeObject(forKey: "accessToken") as? String
    pendingToken = coder.decodeObject(forKey: "pendingToken") as? String
    secret = coder.decodeObject(forKey: "secret") as? String
    fullName = coder.decodeObject(forKey: "fullName") as? PersonNameComponents
    OAuthResponseURLString = nil
    sessionID = nil
    super.init(provider: OAuthProvider.id)
  }

  private static func nonEmptyString(_ string: String?) -> Bool {
    guard let string else {
      return false
    }
    return string.count > 0
  }
}
