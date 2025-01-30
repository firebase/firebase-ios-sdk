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

// TODO(ncooke3): Investigate making this class support generics for the `request`.
// TODO(ncooke3): Refactor to make checked Sendable.
/// An implementation of `AuthBackendRPCIssuerProtocol` which is used to test
/// backend request, response, and glue logic.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
final class FakeBackendRPCIssuer: AuthBackendRPCIssuerProtocol, @unchecked Sendable {
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
  var verifyRequester: ((SendVerificationCodeRequest) -> (Data?, Error?))?
  var verifyClientRequester: ((VerifyClientRequest) -> (Data?, Error?))?
  var projectConfigRequester: ((GetProjectConfigRequest) -> (Data?, Error?))?
  var verifyPasswordRequester: ((VerifyPasswordRequest) -> (Data?, Error?))?
  var verifyPhoneNumberRequester: ((VerifyPhoneNumberRequest) -> Void)?

  var respondBlock: (() throws -> (Data?, Error?))?
  var nextRespondBlock: (() throws -> (Data?, Error?))?

  var fakeGetAccountProviderJSON: [[String: AnyHashable]]?
  var fakeSecureTokenServiceJSON: [String: AnyHashable]?
  var secureTokenNetworkError: NSError?
  var secureTokenErrorString: String?
  var recaptchaSiteKey = "projects/fakeProjectId/keys/mockSiteKey"
  var rceMode: String = "OFF"

  func asyncCallToURL<T>(with request: T, body: Data?,
                         contentType: String) async -> (Data?, Error?)
    where T: FirebaseAuth.AuthRPCRequest {
    self.contentType = contentType
    self.request = request
    requestURL = request.requestURL()

    // TODO: See if we can use the above generics to avoid all this.
    if let verifyRequester,
       let verifyRequest = request as? SendVerificationCodeRequest {
      return verifyRequester(verifyRequest)
    } else if let verifyClientRequester,
              let verifyClientRequest = request as? VerifyClientRequest {
      return verifyClientRequester(verifyClientRequest)
    } else if let projectConfigRequester,
              let projectConfigRequest = request as? GetProjectConfigRequest {
      return projectConfigRequester(projectConfigRequest)
    } else if let verifyPasswordRequester,
              let verifyPasswordRequest = request as? VerifyPasswordRequest {
      return verifyPasswordRequester(verifyPasswordRequest)
    } else if let verifyPhoneNumberRequester,
              let verifyPhoneNumberRequest = request as? VerifyPhoneNumberRequest {
      verifyPhoneNumberRequester(verifyPhoneNumberRequest)
    }

    if let _ = request as? GetAccountInfoRequest,
       let json = fakeGetAccountProviderJSON {
      guard let (data, error) = try? respond(withJSON: ["users": json]) else {
        fatalError("fakeGetAccountProviderJSON respond failed")
      }
      return (data, error)
    } else if let _ = request as? GetRecaptchaConfigRequest {
      if rceMode != "OFF" { // Check if reCAPTCHA is enabled
        let recaptchaKey = recaptchaSiteKey // iOS key from your config
        let enforcementState = [
          ["provider": "EMAIL_PASSWORD_PROVIDER", "enforcementState": rceMode],
          ["provider": "PHONE_PROVIDER", "enforcementState": rceMode],
        ]
        guard let (data, error) = try? respond(withJSON: [
          "recaptchaKey": recaptchaKey,
          "recaptchaEnforcementState": enforcementState,
        ]) else {
          fatalError("GetRecaptchaConfigRequest respond failed")
        }
        return (data, error)
      } else { // reCAPTCHA OFF
        let enforcementState = [
          ["provider": "EMAIL_PASSWORD_PROVIDER", "enforcementState": "OFF"],
          ["provider": "PHONE_PROVIDER", "enforcementState": "OFF"],
        ]
        guard let (data, error) = try? respond(withJSON: [
          "recaptchaEnforcementState": enforcementState,
        ]) else {
          fatalError("GetRecaptchaConfigRequest respond failed")
        }
        return (data, error)
      }
    } else if let _ = request as? SecureTokenRequest {
      if let secureTokenNetworkError {
        return (nil, secureTokenNetworkError)
      } else if let secureTokenErrorString {
        guard let (data, error) = try? respond(serverErrorMessage: secureTokenErrorString) else {
          fatalError("Failed to generate secureTokenErrorString")
        }
        return (data, error)
      } else if let json = fakeSecureTokenServiceJSON {
        guard let (data, error) = try? respond(withJSON: json) else {
          fatalError("fakeGetAccountProviderJSON respond failed")
        }
        return (data, error)
      }
    }
    if let body = body {
      requestData = body
      // Use the real implementation so that the complete request can
      // be verified during testing.
      completeRequest = Task {
        await AuthBackend
          .request(
            for: request.requestURL(),
            httpMethod: requestData == nil ? "GET" : "POST",
            contentType: contentType,
            requestConfiguration: request.requestConfiguration()
          )
      }
      decodedRequest = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }
    if let respondBlock {
      do {
        let (data, error) = try respondBlock()
        self.respondBlock = nextRespondBlock
        nextRespondBlock = nil
        return (data, error)
      } catch {
        return (nil, error)
      }
    }
    fatalError("Should never get here")
  }

  func respond(serverErrorMessage errorMessage: String) throws -> (Data, Error?) {
    let error = NSError(domain: NSCocoaErrorDomain, code: 0)
    return try respond(serverErrorMessage: errorMessage, error: error)
  }

  func respond(serverErrorMessage errorMessage: String, error: NSError) throws -> (Data, Error?) {
    return try respond(withJSON: ["error": ["message": errorMessage]], error: error)
  }

  func respond(underlyingErrorMessage errorMessage: String,
               message: String = "See the reason") throws -> (Data, Error?) {
    let error = NSError(domain: NSCocoaErrorDomain, code: 0)
    return try respond(
      withJSON: ["error": ["message": message,
                           "errors": [["reason": errorMessage]]] as [String: Any]],
      error: error
    )
  }

  func respond(withJSON json: [String: Any], error: NSError? = nil) throws -> (Data, Error?) {
    return try (JSONSerialization.data(withJSONObject: json,
                                       options: JSONSerialization.WritingOptions.prettyPrinted),
                error)
  }
}
