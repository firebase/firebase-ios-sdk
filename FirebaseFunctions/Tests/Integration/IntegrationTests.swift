// Copyright 2021 Google LLC
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

import FirebaseAuthInterop
@testable import FirebaseFunctions
import FirebaseMessagingInterop
import XCTest

/// This file was initialized as a direct port of
/// `FirebaseFunctionsSwift/Tests/IntegrationTests.swift`
/// which itself was ported from the Objective-C
/// `FirebaseFunctions/Tests/Integration/FIRIntegrationTests.m`
///
/// The tests require the emulator to be running with `FirebaseFunctions/Backend/start.sh
/// synchronous`
/// The Firebase Functions called in the tests are implemented in
/// `FirebaseFunctions/Backend/index.js`.

struct DataTestRequest: Encodable {
  var bool: Bool
  var int: Int32
  var long: Int64
  var string: String
  var array: [Int32]
  // NOTE: Auto-synthesized Encodable conformance uses 'encodeIfPresent' to
  // encode Optional values. To encode Optional.none as null you either need
  // to write a manual encodable conformance or use a helper like the
  // propertyWrapper here:
  @NullEncodable var null: Bool?
}

@propertyWrapper
struct NullEncodable<T>: Encodable where T: Encodable {
  var wrappedValue: T?

  init(wrappedValue: T?) {
    self.wrappedValue = wrappedValue
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch wrappedValue {
    case let .some(value): try container.encode(value)
    case .none: try container.encodeNil()
    }
  }
}

struct DataTestResponse: Decodable, Equatable {
  var message: String
  var long: Int64
  var code: Int32
}

class IntegrationTests: XCTestCase {
  let functions = Functions(projectID: "functions-integration-test",
                            region: "us-central1",
                            customDomain: nil,
                            auth: nil,
                            messaging: MessagingTokenProvider(),
                            appCheck: nil)

  override func setUp() {
    super.setUp()
    functions.useEmulator(withHost: "localhost", port: 5005)
  }

  func emulatorURL(_ funcName: String) -> URL {
    return URL(string: "http://localhost:5005/functions-integration-test/us-central1/\(funcName)")!
  }

  func testData() {
    let data = DataTestRequest(
      bool: true,
      int: 2,
      long: 9_876_543_210,
      string: "four",
      array: [5, 6],
      null: nil
    )
    let byName = functions.httpsCallable("dataTest",
                                         requestAs: DataTestRequest.self,
                                         responseAs: DataTestResponse.self)
    let byURL = functions.httpsCallable(emulatorURL("dataTest"),
                                        requestAs: DataTestRequest.self,
                                        responseAs: DataTestResponse.self)

    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function.call(data) { result in
        do {
          let response = try result.get()
          let expected = DataTestResponse(
            message: "stub response",
            long: 420,
            code: 42
          )
          XCTAssertEqual(response, expected)
        } catch {
          XCTFail("Failed to unwrap the function result: \(error)")
        }
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testDataAsync() async throws {
    let data = DataTestRequest(
      bool: true,
      int: 2,
      long: 9_876_543_210,
      string: "four",
      array: [5, 6],
      null: nil
    )

    let byName = functions.httpsCallable("dataTest",
                                         requestAs: DataTestRequest.self,
                                         responseAs: DataTestResponse.self)
    let byUrl = functions.httpsCallable(emulatorURL("dataTest"),
                                        requestAs: DataTestRequest.self,
                                        responseAs: DataTestResponse.self)

    for function in [byName, byUrl] {
      let response = try await function.call(data)
      let expected = DataTestResponse(
        message: "stub response",
        long: 420,
        code: 42
      )
      XCTAssertEqual(response, expected)
    }
  }

  func testScalar() {
    let byName = functions.httpsCallable(
      "scalarTest",
      requestAs: Int16.self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("scalarTest"),
      requestAs: Int16.self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function.call(17) { result in
        do {
          let response = try result.get()
          XCTAssertEqual(response, 76)
        } catch {
          XCTAssert(false, "Failed to unwrap the function result: \(error)")
        }
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testScalarAsync() async throws {
    let byName = functions.httpsCallable(
      "scalarTest",
      requestAs: Int16.self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("scalarTest"),
      requestAs: Int16.self,
      responseAs: Int.self
    )

    for function in [byName, byURL] {
      let result = try await function.call(17)
      XCTAssertEqual(result, 76)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testScalarAsyncAlternateSignature() async throws {
    let byName: Callable<Int16, Int> = functions.httpsCallable("scalarTest")
    let byURL: Callable<Int16, Int> = functions.httpsCallable(emulatorURL("scalarTest"))
    for function in [byName, byURL] {
      let result = try await function.call(17)
      XCTAssertEqual(result, 76)
    }
  }

  func testToken() {
    // Recreate functions with a token.
    let functions = Functions(
      projectID: "functions-integration-test",
      region: "us-central1",
      customDomain: nil,
      auth: AuthTokenProvider(token: "token"),
      messaging: MessagingTokenProvider(),
      appCheck: nil
    )
    functions.useEmulator(withHost: "localhost", port: 5005)

    let byName = functions.httpsCallable(
      "tokenTest",
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("tokenTest"),
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      XCTAssertNotNil(function)
      function.call([:]) { result in
        do {
          let data = try result.get()
          XCTAssertEqual(data, [:])
        } catch {
          XCTAssert(false, "Failed to unwrap the function result: \(error)")
        }
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testTokenAsync() async throws {
    // Recreate functions with a token.
    let functions = Functions(
      projectID: "functions-integration-test",
      region: "us-central1",
      customDomain: nil,
      auth: AuthTokenProvider(token: "token"),
      messaging: MessagingTokenProvider(),
      appCheck: nil
    )
    functions.useEmulator(withHost: "localhost", port: 5005)

    let byName = functions.httpsCallable(
      "tokenTest",
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("tokenTest"),
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )

    for function in [byName, byURL] {
      let data = try await function.call([:])
      XCTAssertEqual(data, [:])
    }
  }

  func testFCMToken() {
    let byName = functions.httpsCallable(
      "FCMTokenTest",
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("FCMTokenTest"),
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function.call([:]) { result in
        do {
          let data = try result.get()
          XCTAssertEqual(data, [:])
        } catch {
          XCTAssert(false, "Failed to unwrap the function result: \(error)")
        }
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testFCMTokenAsync() async throws {
    let byName = functions.httpsCallable(
      "FCMTokenTest",
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("FCMTokenTest"),
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )

    for function in [byName, byURL] {
      let data = try await function.call([:])
      XCTAssertEqual(data, [:])
    }
  }

  func testNull() {
    let byName = functions.httpsCallable(
      "nullTest",
      requestAs: Int?.self,
      responseAs: Int?.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("nullTest"),
      requestAs: Int?.self,
      responseAs: Int?.self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function.call(nil) { result in
        do {
          let data = try result.get()
          XCTAssertEqual(data, nil)
        } catch {
          XCTAssert(false, "Failed to unwrap the function result: \(error)")
        }
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testNullAsync() async throws {
    let byName = functions.httpsCallable(
      "nullTest",
      requestAs: Int?.self,
      responseAs: Int?.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("nullTest"),
      requestAs: Int?.self,
      responseAs: Int?.self
    )

    for function in [byName, byURL] {
      let data = try await function.call(nil)
      XCTAssertEqual(data, nil)
    }
  }

  func testMissingResult() {
    let byName = functions.httpsCallable(
      "missingResultTest",
      requestAs: Int?.self,
      responseAs: Int?.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("missingResultTest"),
      requestAs: Int?.self,
      responseAs: Int?.self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function.call(nil) { result in
        do {
          _ = try result.get()
        } catch {
          let error = error as NSError
          XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
          XCTAssertEqual("Response is missing data field.", error.localizedDescription)
          expectation.fulfill()
          return
        }
        XCTFail("Failed to throw error for missing result")
      }

      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testMissingResultAsync() async {
    let byName = functions.httpsCallable(
      "missingResultTest",
      requestAs: Int?.self,
      responseAs: Int?.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("missingResultTest"),
      requestAs: Int?.self,
      responseAs: Int?.self
    )
    for function in [byName, byURL] {
      do {
        _ = try await function.call(nil)
        XCTFail("Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("Response is missing data field.", error.localizedDescription)
      }
    }
  }

  func testUnhandledError() {
    let byName = functions.httpsCallable(
      "unhandledErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("unhandledErrorTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function.call([]) { result in
        do {
          _ = try result.get()
        } catch {
          let error = error as NSError
          XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
          XCTAssertEqual("INTERNAL", error.localizedDescription)
          expectation.fulfill()
          return
        }
        XCTFail("Failed to throw error for missing result")
      }
      XCTAssert(true)
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testUnhandledErrorAsync() async {
    let byName = functions.httpsCallable(
      "unhandledErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      "unhandledErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      do {
        _ = try await function.call([])
        XCTFail("Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("INTERNAL", error.localizedDescription)
      }
    }
  }

  func testUnknownError() {
    let byName = functions.httpsCallable(
      "unknownErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("unknownErrorTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function.call([]) { result in
        do {
          _ = try result.get()
        } catch {
          let error = error as NSError
          XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
          XCTAssertEqual("INTERNAL", error.localizedDescription)
          expectation.fulfill()
          return
        }
        XCTFail("Failed to throw error for missing result")
      }
    }
    waitForExpectations(timeout: 5)
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testUnknownErrorAsync() async {
    let byName = functions.httpsCallable(
      "unknownErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("unknownErrorTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      do {
        _ = try await function.call([])
        XCTAssertFalse(true, "Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("INTERNAL", error.localizedDescription)
      }
    }
  }

  func testExplicitError() {
    let byName = functions.httpsCallable(
      "explicitErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      "explicitErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function.call([]) { result in
        do {
          _ = try result.get()
        } catch {
          let error = error as NSError
          XCTAssertEqual(FunctionsErrorCode.outOfRange.rawValue, error.code)
          XCTAssertEqual("explicit nope", error.localizedDescription)
          XCTAssertEqual(["start": 10 as Int32, "end": 20 as Int32, "long": 30],
                         error.userInfo["details"] as? [String: Int32])
          expectation.fulfill()
          return
        }
        XCTFail("Failed to throw error for missing result")
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testExplicitErrorAsync() async {
    let byName = functions.httpsCallable(
      "explicitErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("explicitErrorTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      do {
        _ = try await function.call([])
        XCTAssertFalse(true, "Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.outOfRange.rawValue, error.code)
        XCTAssertEqual("explicit nope", error.localizedDescription)
        XCTAssertEqual(["start": 10 as Int32, "end": 20 as Int32, "long": 30],
                       error.userInfo["details"] as? [String: Int32])
      }
    }
  }

  func testHttpError() {
    let byName = functions.httpsCallable(
      "httpErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("httpErrorTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      XCTAssertNotNil(function)
      function.call([]) { result in
        do {
          _ = try result.get()
        } catch {
          let error = error as NSError
          XCTAssertEqual(FunctionsErrorCode.invalidArgument.rawValue, error.code)
          expectation.fulfill()
          return
        }
        XCTFail("Failed to throw error for missing result")
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testHttpErrorAsync() async {
    let byName = functions.httpsCallable(
      "httpErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("httpErrorTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      do {
        _ = try await function.call([])
        XCTAssertFalse(true, "Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.invalidArgument.rawValue, error.code)
      }
    }
  }

  func testThrowError() {
    let byName = functions.httpsCallable(
      "throwTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("throwTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      XCTAssertNotNil(function)
      function.call([]) { result in
        do {
          _ = try result.get()
        } catch {
          let error = error as NSError
          XCTAssertEqual(FunctionsErrorCode.invalidArgument.rawValue, error.code)
          XCTAssertEqual(error.localizedDescription, "Invalid test requested.")
          expectation.fulfill()
          return
        }
        XCTFail("Failed to throw error for missing result")
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testThrowErrorAsync() async {
    let byName = functions.httpsCallable(
      "throwTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("throwTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for function in [byName, byURL] {
      do {
        _ = try await function.call([])
        XCTAssertFalse(true, "Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.invalidArgument.rawValue, error.code)
        XCTAssertEqual(error.localizedDescription, "Invalid test requested.")
      }
    }
  }

  func testTimeout() {
    let byName = functions.httpsCallable(
      "timeoutTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    let byURL = functions.httpsCallable(
      emulatorURL("timeoutTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    for var function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function.timeoutInterval = 0.05
      function.call([]) { result in
        do {
          _ = try result.get()
        } catch {
          let error = error as NSError
          XCTAssertEqual(FunctionsErrorCode.deadlineExceeded.rawValue, error.code)
          XCTAssertEqual("DEADLINE EXCEEDED", error.localizedDescription)
          XCTAssertNil(error.userInfo["details"])
          expectation.fulfill()
          return
        }
        XCTFail("Failed to throw error for missing result")
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testTimeoutAsync() async {
    var byName = functions.httpsCallable(
      "timeoutTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    byName.timeoutInterval = 0.05
    var byURL = functions.httpsCallable(
      emulatorURL("timeoutTest"),
      requestAs: [Int].self,
      responseAs: Int.self
    )
    byURL.timeoutInterval = 0.05
    for function in [byName, byURL] {
      do {
        _ = try await function.call([])
        XCTAssertFalse(true, "Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.deadlineExceeded.rawValue, error.code)
        XCTAssertEqual("DEADLINE EXCEEDED", error.localizedDescription)
        XCTAssertNil(error.userInfo["details"])
      }
    }
  }

  func testCallAsFunction() {
    let data = DataTestRequest(
      bool: true,
      int: 2,
      long: 9_876_543_210,
      string: "four",
      array: [5, 6],
      null: nil
    )
    let byName = functions.httpsCallable("dataTest",
                                         requestAs: DataTestRequest.self,
                                         responseAs: DataTestResponse.self)
    let byURL = functions.httpsCallable(emulatorURL("dataTest"),
                                        requestAs: DataTestRequest.self,
                                        responseAs: DataTestResponse.self)
    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function(data) { result in
        do {
          let response = try result.get()
          let expected = DataTestResponse(
            message: "stub response",
            long: 420,
            code: 42
          )
          XCTAssertEqual(response, expected)
          expectation.fulfill()
        } catch {
          XCTAssert(false, "Failed to unwrap the function result: \(error)")
        }
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testCallAsFunctionAsync() async throws {
    let data = DataTestRequest(
      bool: true,
      int: 2,
      long: 9_876_543_210,
      string: "four",
      array: [5, 6],
      null: nil
    )

    let byName = functions.httpsCallable("dataTest",
                                         requestAs: DataTestRequest.self,
                                         responseAs: DataTestResponse.self)

    let byURL = functions.httpsCallable(emulatorURL("dataTest"),
                                        requestAs: DataTestRequest.self,
                                        responseAs: DataTestResponse.self)

    for function in [byName, byURL] {
      let response = try await function(data)
      let expected = DataTestResponse(
        message: "stub response",
        long: 420,
        code: 42
      )
      XCTAssertEqual(response, expected)
    }
  }

  func testInferredTypes() {
    let data = DataTestRequest(
      bool: true,
      int: 2,
      long: 9_876_543_210,
      string: "four",
      array: [5, 6],
      null: nil
    )
    let byName: Callable<DataTestRequest, DataTestResponse> = functions.httpsCallable("dataTest")
    let byURL: Callable<DataTestRequest, DataTestResponse> = functions
      .httpsCallable(emulatorURL("dataTest"))

    for function in [byName, byURL] {
      let expectation = expectation(description: #function)
      function(data) { result in
        do {
          let response = try result.get()
          let expected = DataTestResponse(
            message: "stub response",
            long: 420,
            code: 42
          )
          XCTAssertEqual(response, expected)
          expectation.fulfill()
        } catch {
          XCTAssert(false, "Failed to unwrap the function result: \(error)")
        }
      }
      waitForExpectations(timeout: 5)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func testInferredTyesAsync() async throws {
    let data = DataTestRequest(
      bool: true,
      int: 2,
      long: 9_876_543_210,
      string: "four",
      array: [5, 6],
      null: nil
    )

    let byName: Callable<DataTestRequest, DataTestResponse> = functions
      .httpsCallable("dataTest")
    let byURL: Callable<DataTestRequest, DataTestResponse> = functions
      .httpsCallable(emulatorURL("dataTest"))

    for function in [byName, byURL] {
      let response = try await function(data)
      let expected = DataTestResponse(
        message: "stub response",
        long: 420,
        code: 42
      )
      XCTAssertEqual(response, expected)
    }
  }
}

private class AuthTokenProvider: AuthInterop {
  func getUserID() -> String? {
    return "fake user"
  }

  let token: String

  init(token: String) {
    self.token = token
  }

  func getToken(forcingRefresh: Bool, completion: (String?, Error?) -> Void) {
    completion(token, nil)
  }
}

private class MessagingTokenProvider: NSObject, MessagingInterop {
  var fcmToken: String? { return "fakeFCMToken" }
}
