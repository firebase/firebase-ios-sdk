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

// TODO: Investigate making this class support generics for the `request`.
/** @class FakeBackendRPCIssuer
    @brief An implementation of @c AuthBackendRPCIssuer which is used to test backend request,
        response, and glue logic.
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class FakeBackendRPCIssuer: AuthBackendRPCIssuer {
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
  var request: (any AuthRPCRequest)?

  /** @property completeRequest
      @brief The last request to be processed by the backend.
   */
  var completeRequest: Task<URLRequest, Never>!

  /** @var _handler
      @brief A block we must invoke when @c respondWithError or @c respondWithJSON are called.
   */
  private var handler: ((Data?, Error?) -> Void)?

  /** @var verifyRequester
      @brief Optional function to run tests on the request.
   */
  var verifyRequester: ((SendVerificationCodeRequest) -> Void)?
  var verifyClientRequester: ((VerifyClientRequest) -> Void)?
  var projectConfigRequester: ((GetProjectConfigRequest) -> Void)?
  var verifyPasswordRequester: ((VerifyPasswordRequest) -> Void)?
  var verifyPhoneNumberRequester: ((VerifyPhoneNumberRequest) -> Void)?

  var respondBlock: (() throws -> Void)?
  var nextRespondBlock: (() throws -> Void)?

  var fakeGetAccountProviderJSON: [[String: AnyHashable]]?
  var fakeSecureTokenServiceJSON: [String: AnyHashable]?
  var secureTokenNetworkError: NSError?
  var secureTokenErrorString: String?
  var recaptchaSiteKey = "unset recaptcha siteKey"

  override func asyncCallToURL<T>(with request: T, body: Data?,
                                  contentType: String) async -> (Data?, Error?)
    where T: FirebaseAuth.AuthRPCRequest {
    return await withCheckedContinuation { continuation in
      self.asyncCallToURL(with: request, body: body, contentType: contentType) { data, error in
        continuation.resume(returning: (data, error))
      }
    }
  }

  func asyncCallToURL<T: AuthRPCRequest>(with request: T,
                                         body: Data?,
                                         contentType: String,
                                         completionHandler: @escaping ((Data?, Error?) -> Void)) {
    self.contentType = contentType
    handler = completionHandler
    self.request = request
    requestURL = request.requestURL()

    // TODO: See if we can use the above generics to avoid all this.
    if let verifyRequester,
       let verifyRequest = request as? SendVerificationCodeRequest {
      verifyRequester(verifyRequest)
    } else if let verifyClientRequester,
              let verifyClientRequest = request as? VerifyClientRequest {
      verifyClientRequester(verifyClientRequest)
    } else if let projectConfigRequester,
              let projectConfigRequest = request as? GetProjectConfigRequest {
      projectConfigRequester(projectConfigRequest)
    } else if let verifyPasswordRequester,
              let verifyPasswordRequest = request as? VerifyPasswordRequest {
      verifyPasswordRequester(verifyPasswordRequest)
    } else if let verifyPhoneNumberRequester,
              let verifyPhoneNumberRequest = request as? VerifyPhoneNumberRequest {
      verifyPhoneNumberRequester(verifyPhoneNumberRequest)
    }

    if let _ = request as? GetAccountInfoRequest,
       let json = fakeGetAccountProviderJSON {
      guard let _ = try? respond(withJSON: ["users": json]) else {
        fatalError("fakeGetAccountProviderJSON respond failed")
      }
      return
    } else if let _ = request as? GetRecaptchaConfigRequest {
      guard let _ = try? respond(withJSON: ["recaptchaKey": recaptchaSiteKey])
      else {
        fatalError("GetRecaptchaConfigRequest respond failed")
      }
      return
    } else if let _ = request as? SecureTokenRequest {
      if let secureTokenNetworkError {
        guard let _ = try? respond(withData: nil,
                                   error: secureTokenNetworkError) else {
          fatalError("Failed to generate secureTokenNetworkError")
        }
      } else if let secureTokenErrorString {
        guard let _ = try? respond(serverErrorMessage: secureTokenErrorString) else {
          fatalError("Failed to generate secureTokenErrorString")
        }
        return
      } else if let json = fakeSecureTokenServiceJSON {
        guard let _ = try? respond(withJSON: json) else {
          fatalError("fakeGetAccountProviderJSON respond failed")
        }
        return
      }
    }
    if let body = body {
      requestData = body
      // Use the real implementation so that the complete request can
      // be verified during testing.
      completeRequest = Task {
        await AuthBackend.request(withURL: requestURL!,
                                  contentType: contentType,
                                  requestConfiguration: request.requestConfiguration())
      }
      decodedRequest = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }
    if let respondBlock {
      do {
        try respondBlock()
      } catch {
        XCTFail("Unexpected exception in respondBlock")
      }
      self.respondBlock = nextRespondBlock
      nextRespondBlock = nil
    }
  }

  func respond(serverErrorMessage errorMessage: String) throws {
    let error = NSError(domain: NSCocoaErrorDomain, code: 0)
    try respond(serverErrorMessage: errorMessage, error: error)
  }

  func respond(serverErrorMessage errorMessage: String, error: NSError) throws {
    let _ = try respond(withJSON: ["error": ["message": errorMessage]], error: error)
  }

  @discardableResult func respond(underlyingErrorMessage errorMessage: String,
                                  message: String = "See the reason") throws -> Data {
    let error = NSError(domain: NSCocoaErrorDomain, code: 0)
    return try respond(
      withJSON: ["error": ["message": message,
                           "errors": [["reason": errorMessage]]] as [String: Any]],
      error: error
    )
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
