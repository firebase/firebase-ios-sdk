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

/// - Important: These tests require the emulator. Run `./FirebaseFunctions/Backend/start.sh`
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

  @MainActor func testData() {
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

  @MainActor func testScalar() {
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

  func testScalarAsyncAlternateSignature() async throws {
    let byName: Callable<Int16, Int> = functions.httpsCallable("scalarTest")
    let byURL: Callable<Int16, Int> = functions.httpsCallable(emulatorURL("scalarTest"))
    for function in [byName, byURL] {
      let result = try await function.call(17)
      XCTAssertEqual(result, 76)
    }
  }

  @MainActor func testToken() {
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

  @MainActor func testFCMToken() {
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

  @MainActor func testNull() {
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

  @MainActor func testMissingResult() {
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

  @MainActor func testUnhandledError() {
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

  @MainActor func testUnknownError() {
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

  @MainActor func testExplicitError() {
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

  @MainActor func testHttpError() {
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

  @MainActor func testThrowError() {
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

  @MainActor func testTimeout() {
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

  @MainActor func testCallAsFunction() {
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

  @MainActor func testInferredTypes() {
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

  @MainActor func testFunctionsReturnsOnMainThread() {
    let expectation = expectation(description: #function)
    functions.httpsCallable(
      "scalarTest",
      requestAs: Int16.self,
      responseAs: Int.self
    ).call(17) { result in
      guard case .success = result else {
        return XCTFail("Unexpected failure.")
      }
      XCTAssert(Thread.isMainThread)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  @MainActor func testFunctionsThrowsOnMainThread() {
    let expectation = expectation(description: #function)
    functions.httpsCallable(
      "httpErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    ).call([]) { result in
      guard case .failure = result else {
        return XCTFail("Unexpected failure.")
      }
      XCTAssert(Thread.isMainThread)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }
}

// MARK: - Streaming

/// A convenience type used to represent that a callable function does not
/// accept parameters.
///
/// This can be used as the generic `Request` parameter to ``Callable`` to
/// indicate the callable function does not accept parameters.
private struct EmptyRequest: Encodable, Sendable {}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension IntegrationTests {
  func testStream_NoArgs() async throws {
    // 1. Custom `EmptyRequest` struct is passed as a placeholder generic arg.
    let callable: Callable<EmptyRequest, String> = functions.httpsCallable("genStream")
    // 2. No request data is passed when creating stream.
    let stream = try callable.stream()
    var streamContents: [String] = []
    for try await response in stream {
      streamContents.append(response)
    }
    XCTAssertEqual(
      streamContents,
      ["hello", "world", "this", "is", "cool"]
    )
  }

  @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
  func testStream_NoArgs_UeeNever() async throws {
    let callable: Callable<Never, String> = functions.httpsCallable("genStream")
    let stream = try callable.stream()
    var streamContents: [String] = []
    for try await response in stream {
      streamContents.append(response)
    }
    XCTAssertEqual(
      streamContents,
      ["hello", "world", "this", "is", "cool"]
    )
  }

  func testStream_SimpleStreamResponse() async throws {
    let callable: Callable<EmptyRequest, StreamResponse<String, String>> = functions
      .httpsCallable("genStream")
    let stream = try callable.stream()
    var streamContents: [String] = []
    for try await response in stream {
      switch response {
      case let .message(message):
        streamContents.append(message)
      case let .result(result):
        streamContents.append(result)
      }
    }
    XCTAssertEqual(
      streamContents,
      ["hello", "world", "this", "is", "cool", "hello world this is cool"]
    )
  }

  func testStream_CodableString() async throws {
    let byName: Callable<EmptyRequest, String> = functions.httpsCallable("genStream")
    let stream = try byName.stream()
    let result: [String] = try await stream.reduce([]) { $0 + [$1] }
    XCTAssertEqual(result, ["hello", "world", "this", "is", "cool"])
  }

  private struct Location: Codable, Equatable {
    let name: String
  }

  private struct WeatherForecast: Decodable, Equatable {
    enum Conditions: String, Decodable {
      case sunny
      case rainy
      case snowy
    }

    let location: Location
    let temperature: Int
    let conditions: Conditions
  }

  private struct WeatherForecastReport: Decodable, Equatable {
    let forecasts: [WeatherForecast]
  }

  func testStream_CodableObject() async throws {
    let callable: Callable<[Location], WeatherForecast> = functions
      .httpsCallable("genStreamWeather")
    let stream = try callable.stream([
      Location(name: "Toronto"),
      Location(name: "London"),
      Location(name: "Dubai"),
    ])
    let result: [WeatherForecast] = try await stream.reduce([]) { $0 + [$1] }
    XCTAssertEqual(
      result,
      [
        WeatherForecast(location: Location(name: "Toronto"), temperature: 25, conditions: .snowy),
        WeatherForecast(location: Location(name: "London"), temperature: 50, conditions: .rainy),
        WeatherForecast(location: Location(name: "Dubai"), temperature: 75, conditions: .sunny),
      ]
    )
  }

  func testStream_ResponseMessageDecodingFailure() async throws {
    let callable: Callable<[Location], StreamResponse<WeatherForecast, WeatherForecastReport>> =
      functions
        .httpsCallable("genStreamWeatherError")
    let stream = try callable.stream([Location(name: "Toronto")])
    do {
      for try await _ in stream {
        XCTFail("Expected error to be thrown from stream.")
      }
    } catch let error as FunctionsError where error.code == .dataLoss {
      XCTAssertNotNil(error.errorUserInfo[NSUnderlyingErrorKey] as? DecodingError)
    }
  }

  func testStream_ResponseResultDecodingFailure() async throws {
    let callable: Callable<[Location], StreamResponse<WeatherForecast, String>> = functions
      .httpsCallable("genStreamWeather")
    let stream = try callable.stream([Location(name: "Toronto")])
    do {
      for try await response in stream {
        if case .result = response {
          XCTFail("Expected error to be thrown from stream.")
        }
      }
    } catch let error as FunctionsError where error.code == .dataLoss {
      XCTAssertNotNil(error.errorUserInfo[NSUnderlyingErrorKey] as? DecodingError)
    }
  }

  func testStream_ComplexStreamResponse() async throws {
    let callable: Callable<[Location], StreamResponse<WeatherForecast, WeatherForecastReport>> =
      functions
        .httpsCallable("genStreamWeather")
    let stream = try callable.stream([
      Location(name: "Toronto"),
      Location(name: "London"),
      Location(name: "Dubai"),
    ])
    var streamContents: [WeatherForecast] = []
    var streamResult: WeatherForecastReport?
    for try await response in stream {
      switch response {
      case let .message(message):
        streamContents.append(message)
      case let .result(result):
        streamResult = result
      }
    }
    XCTAssertEqual(
      streamContents,
      [
        WeatherForecast(location: Location(name: "Toronto"), temperature: 25, conditions: .snowy),
        WeatherForecast(location: Location(name: "London"), temperature: 50, conditions: .rainy),
        WeatherForecast(location: Location(name: "Dubai"), temperature: 75, conditions: .sunny),
      ]
    )

    try XCTAssertEqual(
      XCTUnwrap(streamResult), WeatherForecastReport(forecasts: streamContents)
    )
  }

  func testStream_ComplexStreamResponse_Functional() async throws {
    let callable: Callable<[Location], StreamResponse<WeatherForecast, WeatherForecastReport>> =
      functions
        .httpsCallable("genStreamWeather")
    let stream = try callable.stream([
      Location(name: "Toronto"),
      Location(name: "London"),
      Location(name: "Dubai"),
    ])
    let result: (accumulatedMessages: [WeatherForecast], result: WeatherForecastReport?) =
      try await stream.reduce(([], nil)) { partialResult, streamResponse in
        switch streamResponse {
        case let .message(message):
          (partialResult.accumulatedMessages + [message], partialResult.result)
        case let .result(result):
          (partialResult.accumulatedMessages, result)
        }
      }
    XCTAssertEqual(
      result.accumulatedMessages,
      [
        WeatherForecast(location: Location(name: "Toronto"), temperature: 25, conditions: .snowy),
        WeatherForecast(location: Location(name: "London"), temperature: 50, conditions: .rainy),
        WeatherForecast(location: Location(name: "Dubai"), temperature: 75, conditions: .sunny),
      ]
    )

    try XCTAssertEqual(
      XCTUnwrap(result.result), WeatherForecastReport(forecasts: result.accumulatedMessages)
    )
  }

  // Concurrency rules prevent easily testing this feature.
  #if swift(<6)
    func testStream_Canceled() async throws {
      let task = Task.detached { [self] in
        let callable: Callable<EmptyRequest, String> = functions.httpsCallable("genStream")
        let stream = try callable.stream()
        // Since we cancel the call we are expecting an empty array.
        return try await stream.reduce([]) { $0 + [$1] } as [String]
      }
      // We cancel the task and we expect a null response even if the stream was initiated.
      task.cancel()
      let respone = try await task.value
      XCTAssertEqual(respone, [])
    }
  #endif

  func testStream_NonexistentFunction() async throws {
    let callable: Callable<EmptyRequest, String> = functions.httpsCallable(
      "nonexistentFunction"
    )
    let stream = try callable.stream()
    do {
      for try await _ in stream {
        XCTFail("Expected error to be thrown from stream.")
      }
    } catch let error as FunctionsError where error.code == .notFound {
      XCTAssertEqual(error.localizedDescription, "NOT FOUND")
    }
  }

  func testStream_StreamError() async throws {
    let callable: Callable<EmptyRequest, String> = functions.httpsCallable("genStreamError")
    let stream = try callable.stream()
    do {
      for try await _ in stream {
        XCTFail("Expected error to be thrown from stream.")
      }
    } catch let error as FunctionsError where error.code == .internal {
      XCTAssertEqual(error.localizedDescription, "INTERNAL")
    }
  }

  func testStream_RequestEncodingFailure() async throws {
    struct Foo: Encodable {
      enum CodingKeys: CodingKey {}

      func encode(to encoder: any Encoder) throws {
        throw EncodingError
          .invalidValue("", EncodingError.Context(codingPath: [], debugDescription: ""))
      }
    }
    let callable: Callable<Foo, String> = functions
      .httpsCallable("genStream")
    do {
      _ = try callable.stream(Foo())
    } catch let error as FunctionsError where error.code == .invalidArgument {
      _ = try XCTUnwrap(error.errorUserInfo[NSUnderlyingErrorKey] as? EncodingError)
    }
  }

  /// This tests an edge case to assert that if a custom `Response` is used
  /// that matches the decoding logic of `StreamResponse`, the custom
  /// `Response` does not decode successfully.
  func testStream_ResultIsOnlyExposedInStreamResponse() async throws {
    // The implementation is copied from `StreamResponse`. The only difference is the do-catch is
    // removed from the decoding initializer.
    enum MyStreamResponse<Message: Decodable & Sendable, Result: Decodable & Sendable>: Decodable,
      Sendable {
      /// The message yielded by the callable function.
      case message(Message)
      /// The final result returned by the callable function.
      case result(Result)

      private enum CodingKeys: String, CodingKey {
        case message
        case result
      }

      public init(from decoder: any Decoder) throws {
        let container = try decoder
          .container(keyedBy: Self<Message, Result>.CodingKeys.self)
        var allKeys = ArraySlice(container.allKeys)
        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
          throw DecodingError
            .typeMismatch(
              Self<Message,
                Result>.self,
              DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Invalid number of keys found, expected one.",
                underlyingError: nil
              )
            )
        }

        switch onlyKey {
        case .message:
          self = try Self
            .message(container.decode(Message.self, forKey: .message))
        case .result:
          self = try Self
            .result(container.decode(Result.self, forKey: .result))
        }
      }
    }

    let callable: Callable<[Location], MyStreamResponse<WeatherForecast, WeatherForecastReport>> =
      functions
        .httpsCallable("genStreamWeather")
    let stream = try callable.stream([Location(name: "Toronto")])
    do {
      for try await _ in stream {
        XCTFail("Expected error to be thrown from stream.")
      }
    } catch let error as FunctionsError where error.code == .dataLoss {
      XCTAssertNotNil(error.errorUserInfo[NSUnderlyingErrorKey] as? DecodingError)
    }
  }

  func testStream_ForNonStreamingCF3() async throws {
    let callable: Callable<Int16, Int> = functions.httpsCallable("scalarTest")
    let stream = try callable.stream(17)
    do {
      for try await _ in stream {
        XCTFail("Expected error to be thrown from stream.")
      }
    } catch let error as FunctionsError where error.code == .dataLoss {
      XCTAssertEqual(error.localizedDescription, "Unexpected format for streamed response.")
    }
  }

  func testStream_EmptyStream() async throws {
    let callable: Callable<EmptyRequest, String> = functions.httpsCallable("genStreamEmpty")
    var streamContents: [String] = []
    for try await response in try callable.stream() {
      streamContents.append(response)
    }
    XCTAssertEqual(streamContents, [])
  }

  func testStream_ResultOnly() async throws {
    let callable: Callable<EmptyRequest, String> = functions.httpsCallable("genStreamResultOnly")
    let stream = try callable.stream()
    for try await _ in stream {
      // The stream should not yield anything, so this should not be reached.
      XCTFail("Stream should not yield any messages")
    }
    // Because StreamResponse was not used, the result is not accessible,
    // but the message should not throw.
  }

  func testStream_ResultOnly_StreamResponse() async throws {
    struct EmptyResponse: Decodable, Sendable {}
    let callable: Callable<EmptyRequest, StreamResponse<EmptyResponse, String>> = functions
      .httpsCallable(
        "genStreamResultOnly"
      )
    let stream = try callable.stream()
    var streamResult = ""
    for try await response in stream {
      switch response {
      case .message:
        XCTFail("Stream should not yield any messages")
      case let .result(result):
        streamResult = result
      }
    }
    // The hardcoded string matches the CF3's return value.
    XCTAssertEqual(streamResult, "Only a result")
  }

  func testStream_UnexpectedType() async throws {
    // This function yields strings, not integers.
    let callable: Callable<EmptyRequest, Int> = functions.httpsCallable("genStream")
    let stream = try callable.stream()
    do {
      for try await _ in stream {
        XCTFail("Expected error to be thrown from stream.")
      }
    } catch let error as FunctionsError where error.code == .dataLoss {
      XCTAssertNotNil(error.errorUserInfo[NSUnderlyingErrorKey] as? DecodingError)
    }
  }

  func testStream_Timeout() async throws {
    var callable: Callable<EmptyRequest, String> = functions.httpsCallable("timeoutTest")
    // Set a short timeout
    callable.timeoutInterval = 0.01 // 10 milliseconds

    let stream = try callable.stream()

    do {
      for try await _ in stream {
        XCTFail("Expected error to be thrown from stream.")
      }
    } catch let error as FunctionsError where error.code == .unavailable {
      // This should be a timeout error.
      XCTAssertEqual(
        error.localizedDescription,
        "The operation couldn’t be completed. (com.firebase.functions error 14.)"
      )
      XCTAssertNotNil(error.errorUserInfo[NSUnderlyingErrorKey] as? URLError)
    }
  }

  func testStream_LargeData() async throws {
    func generateLargeString() -> String {
      var largeString = ""
      for _ in 0 ..< 10000 {
        largeString += "A"
      }
      return largeString
    }
    let callable: Callable<EmptyRequest, String> = functions.httpsCallable("genStreamLargeData")
    let stream = try callable.stream()
    var concatenatedData = ""
    for try await response in stream {
      concatenatedData += response
    }
    // Assert that the concatenated data matches the expected large data.
    XCTAssertEqual(concatenatedData, generateLargeString())
  }
}

// MARK: - Helpers

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
