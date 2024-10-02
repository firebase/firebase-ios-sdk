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

/// The "deleteAccount" endpoint.

private let kDeleteAccountEndpoint = "deleteAccount"

/// The key for the "idToken" value in the request. This is actually the STS Access Token,
///    despite its confusing (backwards compatible) parameter name.
private let kIDTokenKey = "idToken"

/// The key for the "localID" value in the request.
private let kLocalIDKey = "localId"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class DeleteAccountRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = DeleteAccountResponse

  /// The STS Access Token of the authenticated user.
  let accessToken: String

  /// The localID of the user.
  let localID: String

  init(localID: String, accessToken: String, requestConfiguration: AuthRequestConfiguration) {
    self.localID = localID
    self.accessToken = accessToken
    super.init(endpoint: kDeleteAccountEndpoint, requestConfiguration: requestConfiguration)
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    [
      kIDTokenKey: accessToken,
      kLocalIDKey: localID,
    ]
  }
}
