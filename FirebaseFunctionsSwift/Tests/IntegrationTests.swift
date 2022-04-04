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

import FirebaseFunctions
import FirebaseFunctionsSwift
import FirebaseFunctionsTestingSupport
import XCTest

/// This file was intitialized as a direct port of `FirebaseFunctionsSwift/Tests/IntegrationTests.swift`
/// which itself was ported from the Objective C `FirebaseFunctions/Tests/Integration/FIRIntegrationTests.m`
///
/// The tests require the emulator to be running with `FirebaseFunctions/Backend/start.sh synchronous`
/// The Firebase Functions called in the tests are implemented in `FirebaseFunctions/Backend/index.js`.

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
  let functions = FunctionsFake(
    projectID: "functions-integration-test",
    region: "us-central1",
    customDomain: nil,
    withToken: nil
  )
  let projectID = "functions-swift-integration-test"

  override func setUp() {
    super.setUp()
    functions.useLocalhost()
  }

  func testData() {
    let expectation = expectation(description: #function)
    let data = DataTestRequest(
      bool: true,
      int: 2,
      long: 9_876_543_210,
      string: "four",
      array: [5, 6],
      null: nil
    )
    let function = functions.httpsCallable("dataTest",
                                           requestAs: DataTestRequest.self,
                                           responseAs: DataTestResponse.self)
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
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testDataAsync() async throws {
      let data = DataTestRequest(
        bool: true,
        int: 2,
        long: 9_876_543_210,
        string: "four",
        array: [5, 6],
        null: nil
      )

      let function = functions.httpsCallable("dataTest",
                                             requestAs: DataTestRequest.self,
                                             responseAs: DataTestResponse.self)

      let response = try await function.call(data)
      let expected = DataTestResponse(
        message: "stub response",
        long: 420,
        code: 42
      )
      XCTAssertEqual(response, expected)
    }
  #endif

  func testScalar() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable(
      "scalarTest",
      requestAs: Int16.self,
      responseAs: Int.self
    )
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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testScalarAsync() async throws {
      let function = functions.httpsCallable(
        "scalarTest",
        requestAs: Int16.self,
        responseAs: Int.self
      )

      let result = try await function.call(17)
      XCTAssertEqual(result, 76)
    }

    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testScalarAsyncAlternateSignature() async throws {
      let function: Callable<Int16, Int> = functions.httpsCallable("scalarTest")
      let result = try await function.call(17)
      XCTAssertEqual(result, 76)
    }

  #endif

  func testToken() {
    // Recreate functions with a token.
    let functions = FunctionsFake(
      projectID: "functions-integration-test",
      region: "us-central1",
      customDomain: nil,
      withToken: "token"
    )
    functions.useLocalhost()

    let expectation = expectation(description: #function)
    let function = functions.httpsCallable(
      "FCMTokenTest",
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )
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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testTokenAsync() async throws {
      // Recreate functions with a token.
      let functions = FunctionsFake(
        projectID: "functions-integration-test",
        region: "us-central1",
        customDomain: nil,
        withToken: "token"
      )
      functions.useLocalhost()

      let function = functions.httpsCallable(
        "FCMTokenTest",
        requestAs: [String: Int].self,
        responseAs: [String: Int].self
      )

      let data = try await function.call([:])
      XCTAssertEqual(data, [:])
    }
  #endif

  func testFCMToken() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable(
      "FCMTokenTest",
      requestAs: [String: Int].self,
      responseAs: [String: Int].self
    )
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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testFCMTokenAsync() async throws {
      let function = functions.httpsCallable(
        "FCMTokenTest",
        requestAs: [String: Int].self,
        responseAs: [String: Int].self
      )

      let data = try await function.call([:])
      XCTAssertEqual(data, [:])
    }
  #endif

  func testNull() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable(
      "nullTest",
      requestAs: Int?.self,
      responseAs: Int?.self
    )
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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testNullAsync() async throws {
      let function = functions.httpsCallable(
        "nullTest",
        requestAs: Int?.self,
        responseAs: Int?.self
      )

      let data = try await function.call(nil)
      XCTAssertEqual(data, nil)
    }
  #endif

  func testMissingResult() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable(
      "missingResultTest",
      requestAs: Int?.self,
      responseAs: Int?.self
    )
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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testMissingResultAsync() async {
      let function = functions.httpsCallable(
        "missingResultTest",
        requestAs: Int?.self,
        responseAs: Int?.self
      )
      do {
        _ = try await function.call(nil)
        XCTFail("Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("Response is missing data field.", error.localizedDescription)
      }
    }
  #endif

  func testUnhandledError() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable(
      "unhandledErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testUnhandledErrorAsync() async {
      let function = functions.httpsCallable(
        "unhandledErrorTest",
        requestAs: [Int].self,
        responseAs: Int.self
      )
      do {
        _ = try await function.call([])
        XCTFail("Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("INTERNAL", error.localizedDescription)
      }
    }
  #endif

  func testUnknownError() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable(
      "unknownErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
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
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testUnknownErrorAsync() async {
      let function = functions.httpsCallable(
        "unknownErrorTest",
        requestAs: [Int].self,
        responseAs: Int.self
      )
      do {
        _ = try await function.call([])
        XCTAssertFalse(true, "Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("INTERNAL", error.localizedDescription)
      }
    }
  #endif

  func testExplicitError() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable(
      "explicitErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
    function.call([]) { result in
      do {
        _ = try result.get()
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.outOfRange.rawValue, error.code)
        XCTAssertEqual("explicit nope", error.localizedDescription)
        XCTAssertEqual(["start": 10 as Int32, "end": 20 as Int32, "long": 30],
                       error.userInfo["details"] as! [String: Int32])
        expectation.fulfill()
        return
      }
      XCTFail("Failed to throw error for missing result")
    }
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testExplicitErrorAsync() async {
      let function = functions.httpsCallable(
        "explicitErrorTest",
        requestAs: [Int].self,
        responseAs: Int.self
      )
      do {
        _ = try await function.call([])
        XCTAssertFalse(true, "Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.outOfRange.rawValue, error.code)
        XCTAssertEqual("explicit nope", error.localizedDescription)
        XCTAssertEqual(["start": 10 as Int32, "end": 20 as Int32, "long": 30],
                       error.userInfo["details"] as! [String: Int32])
      }
    }
  #endif

  func testHttpError() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable(
      "httpErrorTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testHttpErrorAsync() async {
      let function = functions.httpsCallable(
        "httpErrorTest",
        requestAs: [Int].self,
        responseAs: Int.self
      )
      do {
        _ = try await function.call([])
        XCTAssertFalse(true, "Failed to throw error for missing result")
      } catch {
        let error = error as NSError
        XCTAssertEqual(FunctionsErrorCode.invalidArgument.rawValue, error.code)
      }
    }
  #endif

  func testTimeout() {
    let expectation = expectation(description: #function)
    var function = functions.httpsCallable(
      "timeoutTest",
      requestAs: [Int].self,
      responseAs: Int.self
    )
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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testTimeoutAsync() async {
      var function = functions.httpsCallable(
        "timeoutTest",
        requestAs: [Int].self,
        responseAs: Int.self
      )
      function.timeoutInterval = 0.05
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
  #endif

  func testCallAsFunction() {
    let expectation = expectation(description: #function)
    let data = DataTestRequest(
      bool: true,
      int: 2,
      long: 9_876_543_210,
      string: "four",
      array: [5, 6],
      null: nil
    )
    let function = functions.httpsCallable("dataTest",
                                           requestAs: DataTestRequest.self,
                                           responseAs: DataTestResponse.self)
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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testCallAsFunctionAsync() async throws {
      let data = DataTestRequest(
        bool: true,
        int: 2,
        long: 9_876_543_210,
        string: "four",
        array: [5, 6],
        null: nil
      )

      let function = functions.httpsCallable("dataTest",
                                             requestAs: DataTestRequest.self,
                                             responseAs: DataTestResponse.self)

      let response = try await function(data)
      let expected = DataTestResponse(
        message: "stub response",
        long: 420,
        code: 42
      )
      XCTAssertEqual(response, expected)
    }
  #endif

  func testInferredTypes() {
    let expectation = expectation(description: #function)
    let data = DataTestRequest(
      bool: true,
      int: 2,
      long: 9_876_543_210,
      string: "four",
      array: [5, 6],
      null: nil
    )
    let function: Callable<DataTestRequest, DataTestResponse> = functions.httpsCallable("dataTest")

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

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testInferredTyesAsync() async throws {
      let data = DataTestRequest(
        bool: true,
        int: 2,
        long: 9_876_543_210,
        string: "four",
        array: [5, 6],
        null: nil
      )

      let function: Callable<DataTestRequest, DataTestResponse> = functions
        .httpsCallable("dataTest")

      let response = try await function(data)
      let expected = DataTestResponse(
        message: "stub response",
        long: 420,
        code: 42
      )
      XCTAssertEqual(response, expected)
    }
  #endif
}
