// Copyright 2024 Google LLC
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

@testable import FirebaseFunctions

import XCTest

final class FunctionsErrorTests: XCTestCase {
  func testInitWithCode() {
    let error = FunctionsError(.permissionDenied)

    let nsError = error as NSError
    XCTAssertEqual(nsError.domain, "com.firebase.functions")
    XCTAssertEqual(nsError.code, 7)
    XCTAssertEqual(nsError.localizedDescription, "PERMISSION DENIED")
    XCTAssertEqual(nsError.userInfo.count, 1)
  }

  func testInitWithCodeAndUserInfo() {
    let error = FunctionsError(.unimplemented, userInfo: ["TEST_Key": "TEST_Value"])

    let nsError = error as NSError
    XCTAssertEqual(nsError.domain, "com.firebase.functions")
    XCTAssertEqual(nsError.code, 12)
    XCTAssertEqual(
      nsError.localizedDescription,
      "The operation couldn’t be completed. (com.firebase.functions error 12.)"
    )
    XCTAssertEqual(nsError.userInfo.count, 1)
    XCTAssertEqual(nsError.userInfo["TEST_Key"] as? String, "TEST_Value")
  }

  func testInitWithOKStatusCodeAndNoErrorBody() {
    // The error should be `nil`.
    let error = FunctionsError(
      httpStatusCode: 200,
      body: nil,
      serializer: FunctionsSerializer()
    )

    XCTAssertNil(error)
  }

  func testInitWithErrorStatusCodeAndNoErrorBody() {
    // The error should be inferred from the HTTP status code.
    let error = FunctionsError(
      httpStatusCode: 429,
      body: nil,
      serializer: FunctionsSerializer()
    )

    guard let error else { return XCTFail("Unexpected `nil` value") }

    let nsError = error as NSError
    XCTAssertEqual(nsError.domain, "com.firebase.functions")
    XCTAssertEqual(nsError.code, 8)
    XCTAssertEqual(nsError.localizedDescription, "RESOURCE EXHAUSTED")
    XCTAssertEqual(nsError.userInfo.count, 1)
  }

  func testInitWithOKStatusCodeAndIncompleteErrorBody() {
    // The status code in the error body takes precedence over the HTTP status code.
    let responseData = #"{ "error": { "status": "OUT_OF_RANGE" } }"#.data(using: .utf8)!

    let error = FunctionsError(
      httpStatusCode: 200,
      body: responseData,
      serializer: FunctionsSerializer()
    )

    guard let error else { return XCTFail("Unexpected `nil` value") }

    let nsError = error as NSError
    XCTAssertEqual(nsError.domain, "com.firebase.functions")
    XCTAssertEqual(nsError.code, 11)
    XCTAssertEqual(nsError.localizedDescription, "OUT OF RANGE")
    XCTAssertEqual(nsError.userInfo.count, 1)
  }

  func testInitWithErrorStatusCodeAndErrorBody() {
    // The status code in the error body takes precedence over the HTTP status code.
    let responseData =
      #"{ "error": { "status": "OUT_OF_RANGE", "message": "TEST_ErrorMessage", "details": 123 } }"#
        .data(using: .utf8)!

    let error = FunctionsError(
      httpStatusCode: 499,
      body: responseData,
      serializer: FunctionsSerializer()
    )

    guard let error else { return XCTFail("Unexpected `nil` value") }

    let nsError = error as NSError
    XCTAssertEqual(nsError.domain, "com.firebase.functions")
    XCTAssertEqual(nsError.code, 11)
    XCTAssertEqual(nsError.localizedDescription, "TEST_ErrorMessage")
    XCTAssertEqual(nsError.userInfo.count, 2)
    XCTAssertEqual(nsError.userInfo["details"] as? Int, 123)
  }

  func testInitWithErrorStatusCodeAndOKErrorBody() {
    // When the status code in the error body is `OK`, error should be `nil` regardless of the HTTP
    // status code.
    let responseData =
      #"{ "error": { "status": "OK", "message": "TEST_ErrorMessage", "details": 123 } }"#
        .data(using: .utf8)!

    let error = FunctionsError(
      httpStatusCode: 401,
      body: responseData,
      serializer: FunctionsSerializer()
    )

    XCTAssertNil(error)
  }

  func testInitWithErrorStatusCodeAndIncompleteErrorBody() {
    // The error name is not in the body; it should be inferred from the HTTP status code.
    let responseData = #"{ "error": { "message": "TEST_ErrorMessage", "details": null } }"#
      .data(using: .utf8)!

    let error = FunctionsError(
      httpStatusCode: 403,
      body: responseData,
      serializer: FunctionsSerializer()
    )

    guard let error else { return XCTFail("Unexpected `nil` value") }

    let nsError = error as NSError
    XCTAssertEqual(nsError.domain, "com.firebase.functions")
    XCTAssertEqual(nsError.code, 7) // `permissionDenied`, inferred from the HTTP status code
    XCTAssertEqual(nsError.localizedDescription, "TEST_ErrorMessage")
    XCTAssertEqual(nsError.userInfo.count, 2)
    XCTAssertEqual(nsError.userInfo["details"] as? NSNull, NSNull())
  }

  func testInitWithErrorStatusCodeAndInvalidErrorBody() {
    // An unsupported status code in the error body should result in the rest of the body ignored.
    let responseData =
      #"{ "error": { "status": "TEST_UNKNOWN_ERROR", "message": "TEST_ErrorMessage", "details": 123 } }"#
        .data(using: .utf8)!

    let error = FunctionsError(
      httpStatusCode: 503,
      body: responseData,
      serializer: FunctionsSerializer()
    )

    guard let error else { return XCTFail("Unexpected `nil` value") }

    let nsError = error as NSError
    XCTAssertEqual(nsError.domain, "com.firebase.functions")
    // Currently, `internal` is used as the fallback error code. Is this correct?
    // Seems like we could get more information from the HTTP status code in such cases.
    XCTAssertEqual(nsError.code, 13)
    XCTAssertEqual(nsError.localizedDescription, "INTERNAL")
    XCTAssertEqual(nsError.userInfo.count, 1)
  }
}
