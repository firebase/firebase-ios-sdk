// Copyright 2025 Google LLC
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

/// The GCIP endpoint for finalizePasskeyEnrollment rpc
private let finalizePasskeyEnrollmentEndPoint = "accounts/passkeyEnrollment:finalize"

@available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
class FinalizePasskeyEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = FinalizePasskeyEnrollmentResponse

  /// The raw user access token.
  let idToken: String
  /// The passkey name.
  let name: String
  /// The credential ID.
  let credentialID: String
  /// The CollectedClientData object from the authenticator.
  let clientDataJSON: String
  /// The attestation object from the authenticator.
  let attestationObject: String

  init(idToken: String,
       name: String,
       credentialID: String,
       clientDataJSON: String,
       attestationObject: String,
       requestConfiguration: AuthRequestConfiguration) {
    self.idToken = idToken
    self.name = name
    self.credentialID = credentialID
    self.clientDataJSON = clientDataJSON
    self.attestationObject = attestationObject
    super.init(
      endpoint: finalizePasskeyEnrollmentEndPoint,
      requestConfiguration: requestConfiguration,
      useIdentityPlatform: true
    )
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    var postBody: [String: AnyHashable] = [
      "idToken": idToken,
      "name": name,
    ]
    let authAttestationResponse: [String: AnyHashable] = [
      "clientDataJSON": clientDataJSON,
      "attestationObject": attestationObject,
    ]
    let authRegistrationResponse: [String: AnyHashable] = [
      "id": credentialID,
      "response": authAttestationResponse,
    ]
    postBody["authenticatorRegistrationResponse"] = authRegistrationResponse
    if let tenantId = tenantID {
      postBody["tenantId"] = tenantId
    }
    return postBody
  }
}
