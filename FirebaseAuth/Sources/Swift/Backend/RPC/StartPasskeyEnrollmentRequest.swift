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

/// The GCIP endpoint for startPasskeyEnrollment rpc
private let startPasskeyEnrollmentEndPoint = "accounts/passkeyEnrollment:start"

@available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
class StartPasskeyEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = StartPasskeyEnrollmentResponse

  /// The raw user access token
  let idToken: String

  init(idToken: String,
       requestConfiguration: AuthRequestConfiguration) {
    self.idToken = idToken
    super.init(
      endpoint: startPasskeyEnrollmentEndPoint,
      requestConfiguration: requestConfiguration,
      useIdentityPlatform: true
    )
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    var body: [String: AnyHashable] = [
      "idToken": idToken,
    ]
    if let tenantID = tenantID {
      body["tenantId"] = tenantID
    }
    return body
  }
}
