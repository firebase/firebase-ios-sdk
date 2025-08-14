/*
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/// The GCIP endpoint for finalizePasskeySignIn rpc
private let finalizePasskeySignInEndPoint = "accounts/passkeySignIn:finalize"

@available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
class FinalizePasskeySignInRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = FinalizePasskeySignInResponse
  /// The credential ID
  let credentialID: String
  /// The CollectedClientData object from the authenticator.
  let clientDataJSON: String
  /// The AuthenticatorData from the authenticator.
  let authenticatorData: String
  ///  The signature from the authenticator.
  let signature: String
  /// The user handle
  let userId: String

  init(credentialID: String,
       clientDataJSON: String,
       authenticatorData: String,
       signature: String,
       userId: String,
       requestConfiguration: AuthRequestConfiguration) {
    self.credentialID = credentialID
    self.clientDataJSON = clientDataJSON
    self.authenticatorData = authenticatorData
    self.signature = signature
    self.userId = userId
    super.init(
      endpoint: finalizePasskeySignInEndPoint,
      requestConfiguration: requestConfiguration,
      useIdentityPlatform: true
    )
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    var postBody: [String: AnyHashable] = [
      "authenticatorAssertionResponse": [
        "credentialId": credentialID,
        "authenticatorAssertionResponse": [
          "clientDataJSON": clientDataJSON,
          "authenticatorData": authenticatorData,
          "signature": signature,
          "userHandle": userId,
        ],
      ] as [String: AnyHashable],
    ]
    if let tenantID = tenantID {
      postBody["tenantId"] = tenantID
    }
    return postBody
  }
}
