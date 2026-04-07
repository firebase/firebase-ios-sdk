// Copyright 2026 Google LLC
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

#if SWIFT_PACKAGE
  @testable import FirebaseCrashlyticsSwift
#else
  @testable import FirebaseCrashlytics
#endif

import Foundation
import Testing

@Suite struct ErrorInspectorTests {
  @Test(arguments: [
    (.error1, "TestErrorEnum.error1"),
    (.error2(999), "TestErrorEnum.error2"),
    (.error3("TEST_AssociatedValue"), "TestErrorEnum.error3"),
    (.error4(TestErrorClass()), "TestErrorEnum.error4"),
  ] as [(TestErrorEnum, String)]) func swiftEnumError(error: TestErrorEnum,
                                                      expectedDescription: String) {
    let description = ErrorInspector.identityDescription(for: error)

    #expect(description == expectedDescription)
  }

  @Test(arguments: [
    (.error1, "TEST_CustomErrorEnumDomain.987"),
    (.error2(999), "TEST_CustomErrorEnumDomain.654"),
  ] as [(TestCustomErrorEnum, String)]) func swiftCustomEnumError(error: TestCustomErrorEnum,
                                                                  expectedDescription: String) {
    let description = ErrorInspector.identityDescription(for: error)

    #expect(description == expectedDescription)
  }

  @Test func swiftStructError() {
    let description = ErrorInspector.identityDescription(
      for: TestErrorStruct(value: 999)
    )

    #expect(description == "TestErrorStruct.1")
  }

  @Test func swiftClassError() {
    let description = ErrorInspector.identityDescription(for: TestErrorClass())

    #expect(description == "TEST_ErrorClassDomain.789")
  }

  @Test func nsError() {
    let error = NSError(
      domain: "TEST_NSError",
      code: 123,
      userInfo: [NSLocalizedDescriptionKey: "TEST_LocDesc"]
    )

    let description = ErrorInspector.identityDescription(for: error)

    #expect(description == "TEST_NSError.123")
  }

  @Test func nsErrorSubclass() {
    let error = SomeNSError(
      domain: "TEST_NSErrorSubclass",
      code: 456,
      userInfo: [NSLocalizedDescriptionKey: "TEST_LocDesc"]
    )

    let description = ErrorInspector.identityDescription(for: error)

    #expect(description == "TEST_NSErrorSubclass.456")
  }

  // This is a known edge case. If an error inherits from `NSError`
  // and at the same time uses `SwiftNative` in its class name,
  // it will be treated as if it were a Swift `Error` bridged to `NSError`,
  // i.e. the error’s identity will be based on its class name, not `domain`
  // (but `domain` and all other properties remain intact and available).
  @Test func nsErrorSubclassWithSpecialName() {
    let error = TestSwiftNativeError(
      domain: "TEST_NSErrorSubclass",
      code: 789,
      userInfo: [NSLocalizedDescriptionKey: "TEST_LocDesc"]
    )

    let description = ErrorInspector.identityDescription(for: error)

    #expect(description == "TestSwiftNativeError.789")
  }
}

enum TestErrorEnum: Error {
  case error1
  case error2(Int)
  case error3(String)
  case error4(Any)
}

enum TestCustomErrorEnum: CustomNSError {
  case error1
  case error2(Int)

  static var errorDomain: String { "TEST_CustomErrorEnumDomain" }

  var errorCode: Int {
    switch self {
    case .error1: 987
    case .error2: 654
    }
  }
}

struct TestErrorStruct: Error {
  let value: Int
}

class TestErrorClass: CustomNSError {
  static var errorDomain: String { "TEST_ErrorClassDomain" }
  var errorCode: Int { 789 }
}

class SomeNSError: NSError, @unchecked Sendable {}
class TestSwiftNativeError: NSError, @unchecked Sendable {}
