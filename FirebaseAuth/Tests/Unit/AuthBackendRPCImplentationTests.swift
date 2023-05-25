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
import FirebaseCoreInternal
import HeartbeatLoggingTestUtils

private let kFakeAPIKey = "kTestAPIKey"
private let kFakeAppID = "kTestFirebaseAppID"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthBackendRPCImplementationTests: RPCBaseTests {
  let kFakeErrorDomain = "fakeDomain"
  let kFakeErrorCode = -1

  /** @fn testRequestEncodingError
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          request passed returns an error during it's unencodedHTTPRequestBodyWithError: method.
          The error returned should be delivered to the caller without any change.
   */
  func testRequestEncodingError() throws {
    let encodingError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    let request = FakeRequest(withEncodingError: encodingError)

    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.RPCRequestEncodingError.rawValue)

    let underlyingUnderlying = try XCTUnwrap(underlyingError
      .userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
    XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
  }

  /** @fn testBodyDataSerializationError
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          request returns an object which isn't serializable by @c NSJSONSerialization.
          The error from @c NSJSONSerialization should be returned as the underlyingError for an
          @c NSError with the code @c FIRAuthErrorCodeJSONSerializationError.
   */
  func testBodyDataSerializationError() throws {
    let request = FakeRequest(withRequestBody: ["unencodable": self])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.JSONSerializationError.rawValue)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)

    XCTAssertNil(underlyingError.userInfo[NSUnderlyingErrorKey])
    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
  }

  /** @fn testNetworkError
      @brief This test checks to make sure a network error is properly wrapped and forwarded with the
          correct code (FIRAuthErrorCodeNetworkError).
   */
  func testNetworkError() throws {
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try rpcIssuer?.respond(withData: nil, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.networkError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, kFakeErrorDomain)
    XCTAssertEqual(underlyingError.code, kFakeErrorCode)

    XCTAssertNil(underlyingError.userInfo[NSUnderlyingErrorKey])
    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
  }

  /** @fn testUnparsableErrorResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response isn't deserializable by @c NSJSONSerialization and an error
          condition (with an associated error response message) was expected. We are expecting to
          receive the original network error wrapped in an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedHTTPResponse.
   */
  func testUnparsableErrorResponse() throws {
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    let data = "<html><body>An error occurred.</body></html>".data(using: .utf8)
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try rpcIssuer?.respond(withData: data, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)

    let underlyingUnderlying = try XCTUnwrap(underlyingError
      .userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
    XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
    XCTAssertEqual(data,
                   try XCTUnwrap(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey] as? Data))
  }

  /** @fn testUnparsableSuccessResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response isn't deserializable by @c NSJSONSerialization and no error
          condition was indicated. We are expecting to
          receive the @c NSJSONSerialization error wrapped in an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse.
   */
  func testUnparsableSuccessResponse() throws {
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    let data = "<xml>Some non-JSON value.</xml>".data(using: .utf8)
    try rpcIssuer?.respond(withData: data, error: nil)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedResponse.rawValue)

    let underlyingUnderlying = try XCTUnwrap(underlyingError
      .userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingUnderlying.domain, NSCocoaErrorDomain)

    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
    XCTAssertEqual(data,
                   try XCTUnwrap(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey] as? Data))
  }

  /** @fn testNonDictionaryErrorResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response deserialized by @c NSJSONSerialization is not a dictionary, and an error was
          expected. We are expecting to receive the original network error wrapped in an @c NSError
          with the code @c FIRAuthInternalErrorCodeUnexpectedErrorResponse with the decoded response
          in the @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDeserializedResponseKey.
   */
  func testNonDictionaryErrorResponse() throws {
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    // We are responding with a JSON-encoded string value representing an array - which is unexpected.
    // It should normally be a dictionary, and we need to check for this sort of thing. Because we can
    // successfully decode this value, however, we do return it in the error results. We check for
    // this array later in the test.
    let data = "[]".data(using: .utf8)
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try rpcIssuer?.respond(withData: data, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
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

  /** @fn testNonDictionarySuccessResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response deserialized by @c NSJSONSerialization is not a dictionary, and no error was
          expected. We are expecting to receive an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded response in the
          @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDecodedResponseKey.
   */
  func testNonDictionarySuccessResponse() throws {
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    // We are responding with a JSON-encoded string value representing an array - which is unexpected.
    // It should normally be a dictionary, and we need to check for this sort of thing. Because we can
    // successfully decode this value, however, we do return it in the error results. We check for
    // this array later in the test.
    let data = "[]".data(using: .utf8)
    try rpcIssuer?.respond(withData: data, error: nil)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedResponse.rawValue)
    XCTAssertNil(underlyingError.userInfo[NSUnderlyingErrorKey])

    XCTAssertNotNil(try XCTUnwrap(
      underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey]
    ) as? [Int])
    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
  }

  /** @fn testCaptchaRequiredResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          we get an error message indicating captcha is required. The backend should not be returning
          this error to mobile clients. If it does, we should wrap it in an @c NSError with the code
          @c FIRAuthInternalErrorCodeUnexpectedErrorResponse with the decoded error message in the
          @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDeserializedResponseKey.
   */
  func testCaptchaRequiredResponse() throws {
    let kErrorMessageCaptchaRequired = "CAPTCHA_REQUIRED"
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try rpcIssuer?.respond(serverErrorMessage: kErrorMessageCaptchaRequired, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
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

  /** @fn testCaptchaCheckFailedResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          we get an error message indicating captcha check failed. The backend should not be returning
          this error to mobile clients. If it does, we should wrap it in an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded error message in the
          @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDecodedErrorResponseKey.
   */
  func testCaptchaCheckFailedResponse() throws {
    let kErrorMessageCaptchaCheckFailed = "CAPTCHA_CHECK_FAILED"
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try rpcIssuer?.respond(
      serverErrorMessage: kErrorMessageCaptchaCheckFailed,
      error: responseError
    )

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.captchaCheckFailed.rawValue)
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
  func testCaptchaRequiredInvalidPasswordResponse() throws {
    let kErrorMessageCaptchaRequiredInvalidPassword = "CAPTCHA_REQUIRED_INVALID_PASSWORD"
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try rpcIssuer?.respond(serverErrorMessage: kErrorMessageCaptchaRequiredInvalidPassword,
                           error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
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

  /** @fn testDecodableErrorResponseWithUnknownMessage
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response deserialized by @c NSJSONSerialization represents a valid error response (and an
          error was indicated) but we didn't receive an error message we know about. We are expecting
          to receive the original network error wrapped in an @c NSError with the code
          @c FIRAuthInternalErrorCodeUnexpectedErrorResponse with the decoded
          error message in the @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDeserializedResponseKey.
   */
  func testDecodableErrorResponseWithUnknownMessage() throws {
    let kUnknownServerErrorMessage = "UNKNOWN_MESSAGE"
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    // We need to return a valid "error" response here, but we are going to intentionally use a bogus
    // error message.
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try rpcIssuer?.respond(serverErrorMessage: kUnknownServerErrorMessage, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
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

  /** @fn testErrorResponseWithNoErrorMessage
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response deserialized by @c NSJSONSerialization is a dictionary, and an error was indicated,
          but no error information was present in the decoded response. We are expecting to receive
          the original network error wrapped in an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded
          response message in the @c NSError.userInfo dictionary associated with the key
          @c FIRAuthErrorUserInfoDeserializedResponseKey.
   */
  func testErrorResponseWithNoErrorMessage() throws {
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try rpcIssuer?.respond(withJSON: [:], error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
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

  /** @fn testClientErrorResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response contains a client error specified by an error messsage sent from the backend.
   */
  func testClientErrorResponse() throws {
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    let kUserDisabledErrorMessage = "USER_DISABLED"
    let kServerErrorDetailMarker = " : "
    let kFakeUserDisabledCustomErrorMessage = "The user has been disabled."
    let customErrorMessage = "\(kUserDisabledErrorMessage)" +
      "\(kServerErrorDetailMarker)\(kFakeUserDisabledCustomErrorMessage)"
    try rpcIssuer?.respond(serverErrorMessage: customErrorMessage, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.userDisabled.rawValue)

    let customMessage = try XCTUnwrap(rpcError?.userInfo[NSLocalizedDescriptionKey] as? String)
    XCTAssertEqual(customMessage, kFakeUserDisabledCustomErrorMessage)
  }

  /** @fn testUndecodableSuccessResponse
      @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
          response isn't decodable by the response class but no error condition was expected. We are
          expecting to receive an @c NSError with the code
          @c FIRAuthErrorCodeUnexpectedServerResponse and the error from @c setWithDictionary:error:
          as the value of the underlyingError.
   */
  func testUndecodableSuccessResponse() throws {
    let request =
      FakeRequest(withDecodingError: NSError(domain: kFakeErrorDomain, code: kFakeErrorCode))
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    try rpcIssuer?.respond(withJSON: [:])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)

    XCTAssertEqual(rpcError?.domain, AuthErrors.domain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.RPCResponseDecodingError.rawValue)

    let dictionary = try XCTUnwrap(underlyingError
      .userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
    XCTAssertEqual(dictionary, [:])
    XCTAssertNil(underlyingError.userInfo[AuthErrorUtils.userInfoDataKey])
  }

  /** @fn testSuccessfulResponse
      @brief Tests that a decoded dictionary is handed to the response instance.
   */
  func testSuccessfulResponse() throws {
    let request = FakeRequest(withRequestBody: [:])
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?
    let kTestKey = "TestKey"
    let kTestValue = "TestValue"

    rpcImplementation?.post(with: request) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }
    // It doesn't matter what we respond with here, as long as it's not an error response. The fake
    // response will deterministicly simulate a decoding error regardless of the response value it was
    // given.
    try rpcIssuer?.respond(withJSON: [kTestKey: kTestValue])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    XCTAssertEqual(try XCTUnwrap(rpcResponse?.receivedDictionary[kTestKey] as? String), kTestValue)
  }

  // TODO: enable heartbeat logger tests for SPM
  #if COCOAPODS
    private class FakeHeartbeatLogger: NSObject, FIRHeartbeatLoggerProtocol {
      var onFlushHeartbeatsIntoPayloadHandler: (() -> _ObjC_HeartbeatsPayload)?

      func log() {
        // This API should not be used by the below tests because the Auth
        // SDK does not log heartbeats in it's networking context.
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
    func testRequest_IncludesHeartbeatPayload_WhenHeartbeatsNeedSending() throws {
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
      rpcImplementation?.post(with: request) { response, error in
        // The callback never happens and it's fine since we only need to verify the request.
        XCTFail("Should not be a callback")
      }

      // Then
      let expectedHeader = FIRHeaderValueFromHeartbeatsPayload(
        HeartbeatLoggingTestUtils.nonEmptyHeartbeatsPayload
      )
      let completeRequest = try XCTUnwrap(rpcIssuer?.completeRequest)
      let headerValue = completeRequest.value(forHTTPHeaderField: "X-Firebase-Client")
      XCTAssertEqual(headerValue, expectedHeader)
    }
  #endif

  /** @fn testRequest_IncludesAppCheckHeader
      @brief This test checks the behavior of @c postWithRequest:response:callback:
          to verify that a appCheck token is attached as a header to an
          outgoing request.
   */
  func testRequest_IncludesAppCheckHeader() throws {
    // Given
    let fakeAppCheck = FakeAppCheck()
    let requestConfiguration = AuthRequestConfiguration(apiKey: kFakeAPIKey,
                                                        appID: kFakeAppID,
                                                        appCheck: fakeAppCheck)

    let request = FakeRequest(withRequestBody: [:], requestConfiguration: requestConfiguration)

    rpcImplementation?.post(with: request) { response, error in
      // The callback never happens and it's fine since we only need to verify the request.
      XCTFail("Should not be a callback")
    }
    let completeRequest = try XCTUnwrap(rpcIssuer?.completeRequest)
    let headerValue = completeRequest.value(forHTTPHeaderField: "X-Firebase-AppCheck")
    XCTAssertEqual(headerValue, fakeAppCheck.fakeAppCheckToken)
  }

  // TODO: enable for SPM
  #if COCOAPODS
    /** @fn testRequest_DoesNotIncludeAHeartbeatPayload_WhenNoHeartbeatsNeedSending
        @brief This test checks the behavior of @c postWithRequest:response:callback:
            to verify that a request header does not contain heartbeat data in the
            case that there are no stored heartbeats that need sending.
     */
    func testRequest_DoesNotIncludeAHeartbeatPayload_WhenNoHeartbeatsNeedSending() throws {
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
      rpcImplementation?.post(with: request) { response, error in
        // The callback never happens and it's fine since we only need to verify the request.
      }

      // Then
      let completeRequest = try XCTUnwrap(rpcIssuer?.completeRequest)
      XCTAssertNil(completeRequest.value(forHTTPHeaderField: "X-Firebase-Client"))
    }
  #endif

  private class FakeRequest: AuthRPCRequest {
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

    func containsPostBody() -> Bool {
      return true
    }

    var response: FakeResponse
    private let configuration: AuthRequestConfiguration

    let encodingError: NSError?
    let requestBody: [String: AnyHashable]

    init(withEncodingError error: NSError) {
      encodingError = error
      requestBody = [:]
      response = FakeResponse()
      configuration = FakeRequest.makeRequestConfiguration()
    }

    init(withDecodingError error: NSError) {
      encodingError = nil
      requestBody = [:]
      response = FakeResponse(withDecodingError: error)
      configuration = FakeRequest.makeRequestConfiguration()
    }

    init(withRequestBody body: [String: AnyHashable],
         requestConfiguration: AuthRequestConfiguration = FakeRequest.makeRequestConfiguration()) {
      encodingError = nil
      requestBody = body
      response = FakeResponse()
      configuration = requestConfiguration
    }
  }

  private class FakeResponse: AuthRPCResponse {
    let decodingError: NSError?
    var receivedDictionary: [String: AnyHashable] = [:]
    init(withDecodingError error: NSError? = nil) {
      decodingError = error
    }

    func setFields(dictionary: [String: AnyHashable]) throws {
      if let decodingError {
        throw decodingError
      }
      receivedDictionary = dictionary
    }
  }
}
