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
import FirebaseFunctionsTestingSupport
import XCTest

/// This file was intitialized as a direct port of the Objective C
/// FirebaseFunctions/Tests/Integration/FIRIntegrationTests.m
///
/// The tests require the emulator to be running with `FirebaseFunctions/Backend/start.sh synchronous`
/// The Firebase Functions called in the tests are implemented in `FirebaseFunctions/Backend/index.js`.

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
    let data = [
      "bool": true,
      "int": 2 as Int32,
      "long": 9_876_543_210,
      "string": "four",
      "array": [5 as Int32, 6 as Int32],
      "null": nil,
    ] as [String: Any?]
    let function = functions.httpsCallable("dataTest")
    XCTAssertNotNil(function)
    function.call(data) { result, error in
      do {
        XCTAssertNil(error)
        let data = try XCTUnwrap(result?.data as? [String: Any])
        let message = try XCTUnwrap(data["message"] as? String)
        let long = try XCTUnwrap(data["long"] as? Int64)
        let code = try XCTUnwrap(data["code"] as? Int32)
        XCTAssertEqual(message, "stub response")
        XCTAssertEqual(long, 420)
        XCTAssertEqual(code, 42)
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testDataAsync() async throws {
      let input = [
        "bool": true,
        "int": 2 as Int32,
        "long": 9_876_543_210,
        "string": "four",
        "array": [5 as Int32, 6 as Int32],
        "null": nil,
      ] as [String: Any?]

      let function = functions.httpsCallable("dataTest")
      XCTAssertNotNil(function)

      let result = try await function.call(input)
      let data = try XCTUnwrap(result.data as? [String: Any])
      let message = try XCTUnwrap(data["message"] as? String)
      let long = try XCTUnwrap(data["long"] as? Int64)
      let code = try XCTUnwrap(data["code"] as? Int32)
      XCTAssertEqual(message, "stub response")
      XCTAssertEqual(long, 420)
      XCTAssertEqual(code, 42)
    }
  #endif

  func testScalar() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("scalarTest")
    XCTAssertNotNil(function)
    function.call(17 as Int16) { result, error in
      do {
        XCTAssertNil(error)
        let data = try XCTUnwrap(result?.data as? Int)
        XCTAssertEqual(data, 76)
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testScalarAsync() async throws {
      let function = functions.httpsCallable("scalarTest")
      XCTAssertNotNil(function)

      let result = try await function.call(17 as Int16)
      let data = try XCTUnwrap(result.data as? Int)
      XCTAssertEqual(data, 76)
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
    let function = functions.httpsCallable("FCMTokenTest")
    XCTAssertNotNil(function)
    function.call([:]) { result, error in
      do {
        XCTAssertNil(error)
        let data = try XCTUnwrap(result?.data) as? [String: Int]
        XCTAssertEqual(data, [:])
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
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

      let function = functions.httpsCallable("FCMTokenTest")
      XCTAssertNotNil(function)

      let result = try await function.call([:])
      let data = try XCTUnwrap(result.data) as? [String: Int]
      XCTAssertEqual(data, [:])
    }
  #endif

  func testFCMToken() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("FCMTokenTest")
    XCTAssertNotNil(function)
    function.call([:]) { result, error in
      do {
        XCTAssertNil(error)
        let data = try XCTUnwrap(result?.data) as? [String: Int]
        XCTAssertEqual(data, [:])
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testFCMTokenAsync() async throws {
      let function = functions.httpsCallable("FCMTokenTest")
      XCTAssertNotNil(function)

      let result = try await function.call([:])
      let data = try XCTUnwrap(result.data) as? [String: Int]
      XCTAssertEqual(data, [:])
    }
  #endif

  func testNull() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("nullTest")
    XCTAssertNotNil(function)
    function.call(nil) { result, error in
      do {
        XCTAssertNil(error)
        let data = try XCTUnwrap(result?.data) as? NSNull
        XCTAssertEqual(data, NSNull())
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testNullAsync() async throws {
      let function = functions.httpsCallable("nullTest")
      XCTAssertNotNil(function)

      let result = try await function.call(nil)
      let data = try XCTUnwrap(result.data) as? NSNull
      XCTAssertEqual(data, NSNull())
    }
  #endif

  // No parameters to call should be the same as passing nil.
  func testParameterless() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("nullTest")
    XCTAssertNotNil(function)
    function.call { result, error in
      do {
        XCTAssertNil(error)
        let data = try XCTUnwrap(result?.data) as? NSNull
        XCTAssertEqual(data, NSNull())
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testParameterlessAsync() async throws {
      let function = functions.httpsCallable("nullTest")
      XCTAssertNotNil(function)

      let result = try await function.call()
      let data = try XCTUnwrap(result.data) as? NSNull
      XCTAssertEqual(data, NSNull())
    }
  #endif

  func testMissingResult() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("missingResultTest")
    XCTAssertNotNil(function)
    function.call(nil) { result, error in
      do {
        XCTAssertNotNil(error)
        let error = try XCTUnwrap(error) as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("Response is missing data field.", error.localizedDescription)
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    XCTAssert(true)
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testMissingResultAsync() async throws {
      let function = functions.httpsCallable("missingResultTest")
      XCTAssertNotNil(function)
      do {
        _ = try await function.call(nil)
      } catch {
        let error = try XCTUnwrap(error) as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("Response is missing data field.", error.localizedDescription)
        return
      }
      XCTAssertFalse(true, "Failed to throw error for missing result")
    }
  #endif

  func testUnhandledError() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("unhandledErrorTest")
    XCTAssertNotNil(function)
    function.call([]) { result, error in
      do {
        XCTAssertNotNil(error)
        let error = try XCTUnwrap(error! as NSError)
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("INTERNAL", error.localizedDescription)
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    XCTAssert(true)
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testUnhandledErrorAsync() async throws {
      let function = functions.httpsCallable("unhandledErrorTest")
      XCTAssertNotNil(function)
      do {
        _ = try await function.call([])
      } catch {
        let error = try XCTUnwrap(error) as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("INTERNAL", error.localizedDescription)
        return
      }
      XCTAssertFalse(true, "Failed to throw error for missing result")
    }
  #endif

  func testUnknownError() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("unknownErrorTest")
    XCTAssertNotNil(function)
    function.call([]) { result, error in
      do {
        XCTAssertNotNil(error)
        let error = try XCTUnwrap(error! as NSError)
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("INTERNAL", error.localizedDescription)
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    XCTAssert(true)
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testUnknownErrorAsync() async throws {
      let function = functions.httpsCallable("unknownErrorTest")
      XCTAssertNotNil(function)
      do {
        _ = try await function.call([])
      } catch {
        let error = try XCTUnwrap(error) as NSError
        XCTAssertEqual(FunctionsErrorCode.internal.rawValue, error.code)
        XCTAssertEqual("INTERNAL", error.localizedDescription)
        return
      }
      XCTAssertFalse(true, "Failed to throw error for missing result")
    }
  #endif

  func testExplicitError() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("explicitErrorTest")
    XCTAssertNotNil(function)
    function.call([]) { result, error in
      do {
        XCTAssertNotNil(error)
        let error = try XCTUnwrap(error! as NSError)
        XCTAssertEqual(FunctionsErrorCode.outOfRange.rawValue, error.code)
        XCTAssertEqual("explicit nope", error.localizedDescription)
        XCTAssertEqual(["start": 10 as Int32, "end": 20 as Int32, "long": 30],
                       error.userInfo[FunctionsErrorDetailsKey] as! [String: Int32])
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    XCTAssert(true)
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testExplicitErrorAsync() async throws {
      let function = functions.httpsCallable("explicitErrorTest")
      XCTAssertNotNil(function)
      do {
        _ = try await function.call([])
      } catch {
        let error = try XCTUnwrap(error) as NSError
        XCTAssertEqual(FunctionsErrorCode.outOfRange.rawValue, error.code)
        XCTAssertEqual("explicit nope", error.localizedDescription)
        XCTAssertEqual(["start": 10 as Int32, "end": 20 as Int32, "long": 30],
                       error.userInfo[FunctionsErrorDetailsKey] as! [String: Int32])
        return
      }
      XCTAssertFalse(true, "Failed to throw error for missing result")
    }
  #endif

  func testHttpError() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("httpErrorTest")
    XCTAssertNotNil(function)
    function.call([]) { result, error in
      do {
        XCTAssertNotNil(error)
        let error = try XCTUnwrap(error! as NSError)
        XCTAssertEqual(FunctionsErrorCode.invalidArgument.rawValue, error.code)
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    XCTAssert(true)
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testHttpErrorAsync() async throws {
      let function = functions.httpsCallable("httpErrorTest")
      XCTAssertNotNil(function)
      do {
        _ = try await function.call([])
      } catch {
        let error = try XCTUnwrap(error) as NSError
        XCTAssertEqual(FunctionsErrorCode.invalidArgument.rawValue, error.code)
        return
      }
      XCTAssertFalse(true, "Failed to throw error for missing result")
    }
  #endif

  func testTimeout() {
    let expectation = expectation(description: #function)
    let function = functions.httpsCallable("timeoutTest")
    XCTAssertNotNil(function)
    function.timeoutInterval = 0.05
    function.call([]) { result, error in
      do {
        XCTAssertNotNil(error)
        let error = try XCTUnwrap(error! as NSError)
        XCTAssertEqual(FunctionsErrorCode.deadlineExceeded.rawValue, error.code)
        XCTAssertEqual("DEADLINE EXCEEDED", error.localizedDescription)
        XCTAssertNil(error.userInfo[FunctionsErrorDetailsKey])
        expectation.fulfill()
      } catch {
        XCTAssert(false, "Failed to unwrap the function result: \(error)")
      }
    }
    XCTAssert(true)
    waitForExpectations(timeout: 5)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testTimeoutAsync() async throws {
      let function = functions.httpsCallable("timeoutTest")
      XCTAssertNotNil(function)
      function.timeoutInterval = 0.05
      do {
        _ = try await function.call([])
      } catch {
        let error = try XCTUnwrap(error) as NSError
        XCTAssertEqual(FunctionsErrorCode.deadlineExceeded.rawValue, error.code)
        XCTAssertEqual("DEADLINE EXCEEDED", error.localizedDescription)
        XCTAssertNil(error.userInfo[FunctionsErrorDetailsKey])
        return
      }
      XCTAssertFalse(true, "Failed to throw error for missing result")
    }
  #endif
}
