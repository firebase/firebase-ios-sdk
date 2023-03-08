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

// TODO: Once this type doesn't need to be @objc, perhaps it would make sense to make the response an
// associated type of the request protocol and perform all encoding of requests and decoding of responses
// using Codable.

/** @protocol FIRAuthRPCRequest
    @brief The generic interface for an RPC request needed by @c FIRAuthBackend.
 */
@objc(FIRAuthRPCRequest) public protocol AuthRPCRequest: NSObjectProtocol {
  /** @fn requestURL
      @brief Gets the request's full URL.
   */

  func requestURL() -> URL

  /** @fn containsPostBody
      @brief Returns whether the request contains a post body or not. Requests without a post body
          are get requests.
      @remarks The default implementation returns true.
   */
  @objc optional func containsPostBody() -> Bool

  /** @fn UnencodedHTTPRequestBodyWithError:
      @brief Creates unencoded HTTP body representing the request.
      @param error An out field for an error which occurred constructing the request.
      @return The HTTP body data representing the request before any encoding, or nil for error.
   */
  @objc(unencodedHTTPRequestBodyWithError:)
  func unencodedHTTPRequestBody() throws -> [String: AnyHashable]

  /** @fn requestConfiguration
      @brief Obtains the request configurations if available.
      @return Returns the request configurations.
   */
  func requestConfiguration() -> AuthRequestConfiguration

  /** @var response
      @brief The corresponding response for this request
   */
  var response: AuthRPCResponse { get }
}
