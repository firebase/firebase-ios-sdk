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
import FirebaseCoreExtension

#if COCOAPODS || SWIFT_PACKAGE
  // Heartbeats are not supported in the internal build system.
  import FirebaseCoreInternal
#endif

private let kFakeAPIKey = "kTestAPIKey"
private let kFakeAppID = "kTestFirebaseAppID"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthBackendTests: RPCBaseTests {
  let kFakeErrorDomain = "fakeDomain"
  let kFakeErrorCode = -1

  /** @fn testRequestEncodingError
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          request passed returns an error during it's unencodedHTTPRequestBodyWithError: method.
          The error returned should be delivered to the caller without any change.
   */
  func testRequestEncodingError() async throws {
    let encodingError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    let request = FakeRequest(withEncodingError: encodingError)

    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.RPCRequestEncodingError.rawValue)

      let underlyingUnderlying = try XCTUnwrap(underlyingError
        .userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
      XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testBodyDataSerializationError
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          request returns an object which isn't serializable by @c NSJSONSerialization.
          The error from @c NSJSONSerialization should be returned as the underlyingError for an
          @c NSError with the code @c FIRAuthErrorCodeJSONSerializationError.
   */
  func testBodyDataSerializationError() async throws {
    let request = FakeRequest(withRequestBody: ["unencodable": self])
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.JSONSerializationError.rawValue)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)

      XCTAssertNil(underlyingError.userInfo[NSUnderlyingErrorKey])
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testNetworkError
      @brief This test checks to make sure a network error is properly wrapped and forwarded with the
          correct code (FIRAuthErrorCodeNetworkError).
   */
  func testNetworkError() async throws {
    let request = FakeRequest(withRequestBody: [:])
    rpcIssuer.respondBlock = {
      let responseError = NSError(domain: self.kFakeErrorDomain, code: self.kFakeErrorCode)
      try self.rpcIssuer.respond(withData: nil, error: responseError)
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.networkError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, kFakeErrorDomain)
      XCTAssertEqual(underlyingError.code, kFakeErrorCode)

      XCTAssertNil(underlyingError.userInfo[NSUnderlyingErrorKey])
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testUnparsableErrorResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response isn't deserializable by @c NSJSONSerialization and an error
          condition (with an associated error response message) was expected. We are expecting to
          receive the original network error wrapped in an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedHTTPResponse.
   */
  func testUnparsableErrorResponse() async throws {
    let data = "<html><body>An error occurred.</body></html>".data(using: .utf8)
    let request = FakeRequest(withRequestBody: [:])
    rpcIssuer.respondBlock = {
      let responseError = NSError(domain: self.kFakeErrorDomain, code: self.kFakeErrorCode)
      try self.rpcIssuer.respond(withData: data, error: responseError)
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)

      let underlyingUnderlying = try XCTUnwrap(underlyingError
        .userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
      XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
      XCTAssertEqual(data,
                     try XCTUnwrap(underlyingError
                       .userInfo[AuthErrorUtils.userInfoDataKey] as? Data))
    }
  }

  /** @fn testUnparsableSuccessResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response isn't deserializable by @c NSJSONSerialization and no error
          condition was indicated. We are expecting to
          receive the @c NSJSONSerialization error wrapped in an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse.
   */
  func testUnparsableSuccessResponse() async throws {
    let data = "<xml>Some non-JSON value.</xml>".data(using: .utf8)
    let request = FakeRequest(withRequestBody: [:])
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(withData: data, error: nil)
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedResponse.rawValue)

      let underlyingUnderlying = try XCTUnwrap(underlyingError
        .userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingUnderlying.domain, NSCocoaErrorDomain)

      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
      XCTAssertEqual(data,
                     try XCTUnwrap(underlyingError
                       .userInfo[AuthErrorUtils.userInfoDataKey] as? Data))
    }
  }

  /** @fn testNonDictionaryErrorResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response deserialized by @c NSJSONSerialization is not a dictionary, and an error was
          expected. We are expecting to receive the original network error wrapped in an @c NSError
          with the code @c FIRAuthInternalErrorCodeUnexpectedErrorResponse with the decoded response
          in the @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDeserializedResponseKey.
   */
  func testNonDictionaryErrorResponse() async throws {
    // We are responding with a JSON-encoded string value representing an array - which is
    // unexpected. It should normally be a dictionary, and we need to check for this sort
    // of thing. Because we can successfully decode this value, however, we do return it
    // in the error results. We check for this array later in the test.
    let data = "[]".data(using: .utf8)
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    let request = FakeRequest(withRequestBody: [:])
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(withData: data, error: responseError)
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)

      let underlyingUnderlying = try XCTUnwrap(underlyingError
        .userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
      XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

      XCTAssertNotNil(try XCTUnwrap(
        underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey]
      ) as? [Int])
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testNonDictionarySuccessResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response deserialized by @c NSJSONSerialization is not a dictionary, and no error was
          expected. We are expecting to receive an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded response in the
          @c NSError.userInfo dictionary associated with the key
          `userInfoDeserializedResponseKey`.
   */
  func testNonDictionarySuccessResponse() async throws {
    // We are responding with a JSON-encoded string value representing an array - which is
    // unexpected. It should normally be a dictionary, and we need to check for this sort
    // of thing. Because we can successfully decode this value, however, we do return it
    // in the error results. We check for this array later in the test.
    let data = "[]".data(using: .utf8)
    let request = FakeRequest(withRequestBody: [:])
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(withData: data, error: nil)
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedResponse.rawValue)
      XCTAssertNil(underlyingError.userInfo[NSUnderlyingErrorKey])
      XCTAssertNotNil(try XCTUnwrap(
        underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey]
      ) as? [Int])
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testCaptchaRequiredResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          we get an error message indicating captcha is required. The backend should not be returning
          this error to mobile clients. If it does, we should wrap it in an @c NSError with the code
          @c FIRAuthInternalErrorCodeUnexpectedErrorResponse with the decoded error message in the
          @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDeserializedResponseKey.
   */
  func testCaptchaRequiredResponse() async throws {
    let kErrorMessageCaptchaRequired = "CAPTCHA_REQUIRED"
    let request = FakeRequest(withRequestBody: [:])
    rpcIssuer.respondBlock = {
      let responseError = NSError(domain: self.kFakeErrorDomain, code: self.kFakeErrorCode)
      try self.rpcIssuer.respond(serverErrorMessage: kErrorMessageCaptchaRequired,
                                 error: responseError)
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)

      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)
      let underlyingUnderlying = try XCTUnwrap(underlyingError
        .userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
      XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

      let dictionary = try XCTUnwrap(underlyingError
        .userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
      XCTAssertEqual(dictionary["message"], kErrorMessageCaptchaRequired)
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testCaptchaCheckFailedResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          we get an error message indicating captcha check failed. The backend should not be returning
          this error to mobile clients. If it does, we should wrap it in an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded error message in the
          @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDecodedErrorResponseKey.
   */
  func testCaptchaCheckFailedResponse() async throws {
    let kErrorMessageCaptchaCheckFailed = "CAPTCHA_CHECK_FAILED"
    let request = FakeRequest(withRequestBody: [:])
    rpcIssuer.respondBlock = {
      let responseError = NSError(domain: self.kFakeErrorDomain, code: self.kFakeErrorCode)
      try self.rpcIssuer.respond(
        serverErrorMessage: kErrorMessageCaptchaCheckFailed,
        error: responseError
      )
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.captchaCheckFailed.rawValue)
    }
  }

  /** @fn testCaptchaRequiredInvalidPasswordResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          we get an error message indicating captcha is required and an invalid password was entered.
          The backend should not be returning this error to mobile clients. If it does, we should wrap
          it in an @c NSError with the code
          @c FIRAuthInternalErrorCodeUnexpectedErrorResponse with the decoded error message in the
          @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDeserializedResponseKey.
   */
  func testCaptchaRequiredInvalidPasswordResponse() async throws {
    let kErrorMessageCaptchaRequiredInvalidPassword = "CAPTCHA_REQUIRED_INVALID_PASSWORD"
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    let request = FakeRequest(withRequestBody: [:])
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(serverErrorMessage: kErrorMessageCaptchaRequiredInvalidPassword,
                                 error: responseError)
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)
      let underlyingUnderlying = try XCTUnwrap(underlyingError
        .userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
      XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

      let dictionary = try XCTUnwrap(underlyingError
        .userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
      XCTAssertEqual(dictionary["message"], kErrorMessageCaptchaRequiredInvalidPassword)
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testDecodableErrorResponseWithUnknownMessage
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response deserialized by @c NSJSONSerialization represents a valid error response (and an
          error was indicated) but we didn't receive an error message we know about. We are expecting
          to receive the original network error wrapped in an @c NSError with the code
          @c FIRAuthInternalErrorCodeUnexpectedErrorResponse with the decoded
          error message in the @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDeserializedResponseKey.
   */
  func testDecodableErrorResponseWithUnknownMessage() async throws {
    // We need to return a valid "error" response here, but we are going to intentionally use a
    // bogus error message.
    let kUnknownServerErrorMessage = "UNKNOWN_MESSAGE"
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    let request = FakeRequest(withRequestBody: [:])
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(serverErrorMessage: kUnknownServerErrorMessage,
                                 error: responseError)
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)
      let underlyingUnderlying = try XCTUnwrap(underlyingError
        .userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
      XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

      let dictionary = try XCTUnwrap(underlyingError
        .userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
      XCTAssertEqual(dictionary["message"], kUnknownServerErrorMessage)
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testErrorResponseWithNoErrorMessage
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response deserialized by @c NSJSONSerialization is a dictionary, and an error was indicated,
          but no error information was present in the decoded response. We are expecting to receive
          the original network error wrapped in an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded
          response message in the @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDeserializedResponseKey.
   */
  func testErrorResponseWithNoErrorMessage() async throws {
    let request = FakeRequest(withRequestBody: [:])
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    rpcIssuer.respondBlock = {
      let _ = try self.rpcIssuer.respond(withJSON: [:], error: responseError)
    }
    do {
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)
      let underlyingUnderlying = try XCTUnwrap(underlyingError
        .userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
      XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

      let dictionary = try XCTUnwrap(underlyingError
        .userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
      XCTAssertEqual(dictionary, [:])
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testClientErrorResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response contains a client error specified by an error message sent from the backend.
   */
  func testClientErrorResponse() async throws {
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    let kUserDisabledErrorMessage = "USER_DISABLED"
    let kServerErrorDetailMarker = " : "
    let kFakeUserDisabledCustomErrorMessage = "The user has been disabled."
    let customErrorMessage = "\(kUserDisabledErrorMessage)" +
      "\(kServerErrorDetailMarker)\(kFakeUserDisabledCustomErrorMessage)"
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(serverErrorMessage: customErrorMessage, error: responseError)
    }
    do {
      let _ = try await AuthBackend.call(with: FakeRequest(withRequestBody: [:]))
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError
      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.userDisabled.rawValue)
      let customMessage = try XCTUnwrap(rpcError.userInfo[NSLocalizedDescriptionKey] as? String)
      XCTAssertEqual(customMessage, kFakeUserDisabledCustomErrorMessage)
    }
  }

  /** @fn testUndecodableSuccessResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response isn't decodable by the response class but no error condition was expected. We are
          expecting to receive an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse and the error from @c setWithDictionary:error:
          as the value of the underlyingError.
   */
  func testUndecodableSuccessResponse() async throws {
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(withJSON: [:])
    }
    do {
      let request = FakeDecodingErrorRequest(withRequestBody: [:])
      let _ = try await AuthBackend.call(with: request)
      XCTFail("Expected to throw")
    } catch {
      let rpcError = error as NSError

      XCTAssertEqual(rpcError.domain, AuthErrors.domain)
      XCTAssertEqual(rpcError.code, AuthErrorCode.internalError.rawValue)

      let underlyingError = try XCTUnwrap(rpcError.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
      XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.RPCResponseDecodingError.rawValue)

      let dictionary = try XCTUnwrap(underlyingError
        .userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
      XCTAssertEqual(dictionary, [:])
      XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
    }
  }

  /** @fn testSuccessfulResponse
      @brief Tests that a decoded dictionary is handed to the response instance.
   */
  func testSuccessfulResponse() async throws {
    let kTestKey = "TestKey"
    let kTestValue = "TestValue"
    rpcIssuer.respondBlock = {
      // It doesn't matter what we respond with here, as long as it's not an error response. The
      // fake response will deterministically simulate a decoding error regardless of the response
      // value it was given.
      try self.rpcIssuer.respond(withJSON: [kTestKey: kTestValue])
    }
    let rpcResponse = try await AuthBackend.call(with: FakeRequest(withRequestBody: [:]))
    XCTAssertEqual(try XCTUnwrap(rpcResponse.receivedValue), kTestValue)
  }

  #if COCOAPODS || SWIFT_PACKAGE
    private class FakeHeartbeatLogger: NSObject, FIRHeartbeatLoggerProtocol {
      func headerValue() -> String? {
        // `asyncHeaderValue` should be used instead.
        fatalError("FakeHeartbeatLogger headerValue should not be used in tests.")
      }

      func asyncHeaderValue() async -> String? {
        let payload = flushHeartbeatsIntoPayload()
        guard !payload.isEmpty else {
          return nil
        }
        return payload.headerValue()
      }

      var onFlushHeartbeatsIntoPayloadHandler: (() -> _ObjC_HeartbeatsPayload)?

      func log() {
        // This API should not be used by the below tests because the Auth
        // SDK does not log heartbeats in its networking context.
        fatalError("FakeHeartbeatLogger log should not be used in tests.")
      }

      func flushHeartbeatsIntoPayload() -> FirebaseCoreInternal._ObjC_HeartbeatsPayload {
        guard let handler = onFlushHeartbeatsIntoPayloadHandler else {
          fatalError("Missing Handler")
        }
        return handler()
      }

      func heartbeatCodeForToday() -> FIRDailyHeartbeatCode {
        // This API should not be used by the below tests because the Auth
        // SDK uses only the V2 heartbeat API (`flushHeartbeatsIntoPayload`) for
        // getting heartbeats.
        return FIRDailyHeartbeatCode.none
      }
    }

    /** @fn testRequest_IncludesHeartbeatPayload_WhenHeartbeatsNeedSending
        @brief This test checks the behavior of @c postWithRequest:response:callback:
            to verify that a heartbeats payload is attached as a header to an
            outgoing request when there are stored heartbeats that need sending.
     */
    func testRequest_IncludesHeartbeatPayload_WhenHeartbeatsNeedSending() async throws {
      // Given
      let fakeHeartbeatLogger = FakeHeartbeatLogger()
      let requestConfiguration = AuthRequestConfiguration(apiKey: kFakeAPIKey,
                                                          appID: kFakeAppID,
                                                          heartbeatLogger: fakeHeartbeatLogger)

      let request = FakeRequest(withRequestBody: [:], requestConfiguration: requestConfiguration)

      // When
      let nonEmptyHeartbeatsPayload = HeartbeatLoggingTestUtils.nonEmptyHeartbeatsPayload
      fakeHeartbeatLogger.onFlushHeartbeatsIntoPayloadHandler = {
        nonEmptyHeartbeatsPayload
      }
      rpcIssuer.respondBlock = {
        // Force return from async post
        try self.rpcIssuer.respond(withJSON: [:])
      }
      _ = try? await AuthBackend.call(with: request)

      // Then
      let expectedHeader = HeartbeatLoggingTestUtils.nonEmptyHeartbeatsPayload.headerValue()
      let completeRequest = await rpcIssuer.completeRequest.value
      let headerValue = completeRequest.value(forHTTPHeaderField: "X-Firebase-Client")
      XCTAssertEqual(headerValue, expectedHeader)
    }

    /** @fn testRequest_IncludesAppCheckHeader
        @brief This test checks the behavior of @c postWithRequest:response:callback:
            to verify that a appCheck token is attached as a header to an
            outgoing request.
     */
    func testRequest_IncludesAppCheckHeader() async throws {
      // Given
      let fakeAppCheck = FakeAppCheck()
      let requestConfiguration = AuthRequestConfiguration(apiKey: kFakeAPIKey,
                                                          appID: kFakeAppID,
                                                          appCheck: fakeAppCheck)

      let request = FakeRequest(withRequestBody: [:], requestConfiguration: requestConfiguration)

      rpcIssuer.respondBlock = {
        // Just force return from async call.
        try self.rpcIssuer.respond(withJSON: [:])
      }
      _ = try? await AuthBackend.call(with: request)

      let completeRequest = await rpcIssuer.completeRequest.value
      let headerValue = completeRequest.value(forHTTPHeaderField: "X-Firebase-AppCheck")
      XCTAssertEqual(headerValue, fakeAppCheck.fakeAppCheckToken)
    }

    /** @fn testRequest_DoesNotIncludeAHeartbeatPayload_WhenNoHeartbeatsNeedSending
        @brief This test checks the behavior of @c postWithRequest:response:callback:
            to verify that a request header does not contain heartbeat data in the
            case that there are no stored heartbeats that need sending.
     */
    func testRequest_DoesNotIncludeAHeartbeatPayload_WhenNoHeartbeatsNeedSending() async throws {
      // Given
      let fakeHeartbeatLogger = FakeHeartbeatLogger()
      let requestConfiguration = AuthRequestConfiguration(apiKey: kFakeAPIKey,
                                                          appID: kFakeAppID,
                                                          heartbeatLogger: fakeHeartbeatLogger)

      let request = FakeRequest(withRequestBody: [:], requestConfiguration: requestConfiguration)

      // When
      let emptyHeartbeatsPayload = HeartbeatLoggingTestUtils.emptyHeartbeatsPayload
      fakeHeartbeatLogger.onFlushHeartbeatsIntoPayloadHandler = {
        emptyHeartbeatsPayload
      }
      rpcIssuer.respondBlock = {
        // Force return from async post
        try self.rpcIssuer.respond(withJSON: [:])
      }
      _ = try? await AuthBackend.call(with: request)

      // Then
      let completeRequest = await rpcIssuer.completeRequest.value
      XCTAssertNil(completeRequest.value(forHTTPHeaderField: "X-Firebase-Client"))
    }
  #endif // COCOAPODS || SWIFT_PACKAGE

  private class FakeRequest: AuthRPCRequest {
    typealias Response = FakeResponse

    func requestConfiguration() -> AuthRequestConfiguration {
      return configuration
    }

    let kFakeRequestURL = "https://www.google.com/"
    func requestURL() -> URL {
      return try! XCTUnwrap(URL(string: kFakeRequestURL))
    }

    func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
      if let encodingError {
        throw encodingError
      }
      return requestBody
    }

    static func makeRequestConfiguration() -> AuthRequestConfiguration {
      return AuthRequestConfiguration(
        apiKey: kFakeAPIKey,
        appID: kFakeAppID
      )
    }

    var containsPostBody: Bool { return true }

    private let configuration: AuthRequestConfiguration

    let encodingError: NSError?
    let requestBody: [String: AnyHashable]

    init(withEncodingError error: NSError) {
      encodingError = error
      requestBody = [:]
      configuration = FakeRequest.makeRequestConfiguration()
    }

    init(withDecodingError error: NSError) {
      encodingError = nil
      requestBody = [:]
      configuration = FakeRequest.makeRequestConfiguration()
    }

    init(withRequestBody body: [String: AnyHashable],
         requestConfiguration: AuthRequestConfiguration = FakeRequest.makeRequestConfiguration()) {
      encodingError = nil
      requestBody = body
      configuration = requestConfiguration
    }
  }

  private struct FakeResponse: AuthRPCResponse {
    var receivedValue: String?
    mutating func setFields(dictionary: [String: AnyHashable]) throws {
      receivedValue = dictionary["TestKey"] as? String
    }
  }

  private class FakeDecodingErrorRequest: AuthRPCRequest {
    typealias Response = FakeDecodingErrorResponse
    func requestURL() -> URL {
      return fakeRequest.requestURL()
    }

    func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
      return try fakeRequest.unencodedHTTPRequestBody()
    }

    func requestConfiguration() -> FirebaseAuth.AuthRequestConfiguration {
      return fakeRequest.requestConfiguration()
    }

    let fakeRequest: FakeRequest
    init(withRequestBody body: [String: AnyHashable]) {
      fakeRequest = FakeRequest(withRequestBody: body)
    }
  }

  private struct FakeDecodingErrorResponse: AuthRPCResponse {
    mutating func setFields(dictionary: [String: AnyHashable]) throws {
      throw NSError(domain: "dummy", code: -1)
    }
  }
}
