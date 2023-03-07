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
import XCTest

@testable import FirebaseAuth

/** @class FIRFakeBackendRPCIssuer
    @brief An implementation of @c FIRAuthBackendRPCIssuer which is used to test backend request,
        response, and glue logic.
 */
class FakeBackendRPCIssuer: NSObject, AuthBackendRPCIssuer {
  /** @property requestURL
      @brief The URL which was requested.
   */
  var requestURL: URL?

  /** @property requestData
      @brief The raw data in the POST body.
   */
  var requestData: Data?

  /** @property decodedRequest
      @brief The raw data in the POST body decoded as JSON.
   */
  var decodedRequest: [String: Any]?

  /** @property contentType
      @brief The value of the content type HTTP header in the request.
   */
  var contentType: String?

  /** @property request
      @brief Save the request for validation.
   */
  var request: AuthRPCRequest?

  /** @property completeRequest
      @brief The last request to be processed by the backend.
   */
  var completeRequest: URLRequest?

  /** @var _handler
      @brief A block we must invoke when @c respondWithError or @c respondWithJSON are called.
   */
  private var handler: ((Data?, Error?) -> Void)?

  /** @var group
      @brief Block on handler initialization
   */
  var group: DispatchGroup?

  func asyncPostToURLWithRequestConfiguration(request: AuthRPCRequest,
                                              body: Data?,
                                              contentType: String,
                                              completionHandler: @escaping (
                                                (Data?, Error?) -> Void
                                              )) {
    self.request = request
    requestURL = request.requestURL()
    if let body = body {
      requestData = body
      // Use the real implementation so that the complete request can
      // be verified during testing.
      completeRequest = AuthBackend.request(withURL: requestURL!,
                                            contentType: contentType,
                                            requestConfiguration: request.requestConfiguration())
      decodedRequest = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }
    self.contentType = contentType
    handler = completionHandler
    if let group {
      group.leave()
    }
  }

  @discardableResult func respond(serverErrorMessage errorMessage: String) throws -> Data {
    let error = NSError(domain: NSCocoaErrorDomain, code: 0)
    return try respond(serverErrorMessage: errorMessage, error: error)
  }

  @discardableResult
  func respond(serverErrorMessage errorMessage: String, error: NSError) throws -> Data {
    return try respond(withJSON: ["error": ["message": errorMessage]], error: error)
  }

  @discardableResult func respond(underlyingErrorMessage errorMessage: String,
                                  message: String = "See the reason") throws -> Data {
    let error = NSError(domain: NSCocoaErrorDomain, code: 0)
    return try respond(withJSON: ["error": ["message": message,
                                            "errors": [["reason": errorMessage]]]], error: error)
  }

  @discardableResult func respond(withJSON json: [String: Any],
                                  error: NSError? = nil) throws -> Data {
    let data = try JSONSerialization.data(withJSONObject: json,
                                          options: JSONSerialization.WritingOptions.prettyPrinted)
    try respond(withData: data, error: error)
    return data
  }

  func respond(withData data: Data?, error: NSError?) throws {
    let handler = try XCTUnwrap(handler, "There is no pending RPC request.")
    XCTAssertTrue(
      (data != nil) || (error != nil),
      "At least one of: data or error should be been non-nil."
    )
    self.handler = nil
    handler(data, error)
  }
}
