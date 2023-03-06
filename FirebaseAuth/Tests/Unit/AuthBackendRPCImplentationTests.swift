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

private class FakeRequest : NSObject, AuthRPCRequest {
  let kFakeRequestURL = "https://www.google.com/"
  func requestURL() -> URL {
    return try! XCTUnwrap(URL(string:kFakeRequestURL))
  }

  func unencodedHTTPRequestBody() throws -> Any {
    if let encodingError {
      throw encodingError
    }
    return requestBody
  }

  func requestConfiguration() -> FirebaseAuth.AuthRequestConfiguration {
    return AuthRequestConfiguration(
      APIKey: "kTestAPIKey",
      appID: "kTestFirebaseAppID"
    )
  }

  func containsPostBody() -> Bool {
    return true
  }

  var response: FirebaseAuth.AuthRPCResponse

  let encodingError:NSError?
  let requestBody: [String: AnyHashable]

  init(withEncodingError error: NSError) {
    encodingError = error
    requestBody = [:]
    response = FakeResponse()
  }

  init(withDecodingError error: NSError) {
    encodingError = nil
    requestBody = [:]
    response = FakeResponse(withDecodingError: error)
  }

  init(withRequestBody body: [String: AnyHashable]) {
    encodingError = nil
    requestBody = body
    response = FakeResponse()
  }
}

private class FakeResponse: NSObject, AuthRPCResponse {
  let decodingError: NSError?
  var receivedDictionary : [String : Any] = [:]
  init(withDecodingError error: NSError? = nil) {
    decodingError = error
  }
  func setFields(dictionary: [String : Any]) throws {
    if let decodingError {
      throw decodingError
    }
    receivedDictionary = dictionary
  }
}

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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.RPCRequestEncodingError.rawValue)

    let underlyingUnderlying = try XCTUnwrap(underlyingError.userInfo[NSUnderlyingErrorKey] as? NSError)
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try RPCIssuer?.respond(withData: nil, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    let data = "<html><body>An error occurred.</body></html>".data(using: .utf8)
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try RPCIssuer?.respond(withData: data, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)

    let underlyingUnderlying = try XCTUnwrap(underlyingError.userInfo[NSUnderlyingErrorKey] as? NSError)
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    let data = "<xml>Some non-JSON value.</xml>".data(using: .utf8)
    try RPCIssuer?.respond(withData: data, error: nil)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedResponse.rawValue)

    let underlyingUnderlying = try XCTUnwrap(underlyingError.userInfo[NSUnderlyingErrorKey] as? NSError)
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    // We are responding with a JSON-encoded string value representing an array - which is unexpected.
    // It should normally be a dictionary, and we need to check for this sort of thing. Because we can
    // successfully decode this value, however, we do return it in the error results. We check for
    // this array later in the test.
    let data = "[]".data(using: .utf8)
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try RPCIssuer?.respond(withData: data, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)

    let underlyingUnderlying = try XCTUnwrap(underlyingError.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
    XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

    XCTAssertNotNil(try XCTUnwrap(
      underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey]) as? [Int])
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    // We are responding with a JSON-encoded string value representing an array - which is unexpected.
    // It should normally be a dictionary, and we need to check for this sort of thing. Because we can
    // successfully decode this value, however, we do return it in the error results. We check for
    // this array later in the test.
    let data = "[]".data(using: .utf8)
    try RPCIssuer?.respond(withData: data, error: nil)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedResponse.rawValue)
    XCTAssertNil(underlyingError.userInfo[NSUnderlyingErrorKey])

    XCTAssertNotNil(try XCTUnwrap(
      underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey]) as? [Int])
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try RPCIssuer?.respond(serverErrorMessage: kErrorMessageCaptchaRequired, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)
    let underlyingUnderlying = try XCTUnwrap(underlyingError.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
    XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

    let dictionary = try XCTUnwrap(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try RPCIssuer?.respond(serverErrorMessage: kErrorMessageCaptchaCheckFailed, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try RPCIssuer?.respond(serverErrorMessage: kErrorMessageCaptchaRequiredInvalidPassword,
                           error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)
    let underlyingUnderlying = try XCTUnwrap(underlyingError.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
    XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

    let dictionary = try XCTUnwrap(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    // We need to return a valid "error" response here, but we are going to intentionally use a bogus
    // error message.
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try RPCIssuer?.respond(serverErrorMessage: kUnknownServerErrorMessage, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)
    let underlyingUnderlying = try XCTUnwrap(underlyingError.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
    XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

    let dictionary = try XCTUnwrap(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try RPCIssuer?.respond(withJSON: [:], error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.unexpectedErrorResponse.rawValue)
    let underlyingUnderlying = try XCTUnwrap(underlyingError.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingUnderlying.domain, kFakeErrorDomain)
    XCTAssertEqual(underlyingUnderlying.code, kFakeErrorCode)

    let dictionary = try XCTUnwrap(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    let kUserDisabledErrorMessage = "USER_DISABLED"
    let kServerErrorDetailMarker = " : "
    let kFakeUserDisabledCustomErrorMessage = "The user has been disabled."
    let customErrorMessage = "\(kUserDisabledErrorMessage)" +
      "\(kServerErrorDetailMarker)\(kFakeUserDisabledCustomErrorMessage)"
    try RPCIssuer?.respond(serverErrorMessage: customErrorMessage, error: responseError)

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
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
    let request = FakeRequest(withDecodingError: NSError(domain: kFakeErrorDomain, code: kFakeErrorCode))
    var callbackInvoked = false
    var rpcResponse: FakeResponse?
    var rpcError: NSError?

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    // It doesn't matter what we respond with here, as long as it's not an error response. The fake
    // response will deterministicly simulate a decoding error regardless of the response value it was
    // given.
    try RPCIssuer?.respond(withJSON: [:])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)

    XCTAssertEqual(rpcError?.domain, AuthErrors.AuthErrorDomain)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.internalError.rawValue)

    let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
    XCTAssertEqual(underlyingError.domain, AuthErrorUtils.internalErrorDomain)
    XCTAssertEqual(underlyingError.code, AuthInternalErrorCode.RPCResponseDecodingError.rawValue)

    let dictionary = try XCTUnwrap(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable])
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

    rpcImplementation?.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? FakeResponse
      rpcError = error as? NSError
    }
    // It doesn't matter what we respond with here, as long as it's not an error response. The fake
    // response will deterministicly simulate a decoding error regardless of the response value it was
    // given.
    try RPCIssuer?.respond(withJSON: [kTestKey : kTestValue])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    XCTAssertEqual(try  XCTUnwrap(rpcResponse?.receivedDictionary[kTestKey] as? String), kTestValue)
  }
}
