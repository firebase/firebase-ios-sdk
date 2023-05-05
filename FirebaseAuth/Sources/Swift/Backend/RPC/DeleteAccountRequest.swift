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

/** @var kCreateAuthURIEndpoint
    @brief The "deleteAccount" endpoint.
 */
private let kDeleteAccountEndpoint = "deleteAccount"

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
private let kIDTokenKey = "idToken"

/** @var kLocalIDKey
    @brief The key for the "localID" value in the request.
 */
private let kLocalIDKey = "localId"

public class DeleteAccountRequest: IdentityToolkitRequest, AuthRPCRequest_NEW_ {
  /** @var _accessToken
      @brief The STS Access Token of the authenticated user.
   */
  public let accessToken: String

  /** @var _localID
      @brief The localID of the user.
   */
  public let localID: String

  /** @var response
      @brief The corresponding response for this request
   */
  public var response: DeleteAccountResponse = DeleteAccountResponse()

  @objc(initWithLocalID:accessToken:requestConfiguration:) public init(localID: String,
                                                                       accessToken: String,
                                                                       requestConfiguration: AuthRequestConfiguration) {
    self.localID = localID
    self.accessToken = accessToken
    super.init(endpoint: kDeleteAccountEndpoint, requestConfiguration: requestConfiguration)
  }

  public func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    [
      kIDTokenKey: accessToken,
      kLocalIDKey: localID,
    ]
  }
}
