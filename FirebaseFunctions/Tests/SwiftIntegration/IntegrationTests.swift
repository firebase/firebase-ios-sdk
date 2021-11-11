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
    waitForExpectations(timeout: 1)
  }

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
    waitForExpectations(timeout: 1)
  }

  func testToken() {
    // Recreate _functions with a token.
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
    waitForExpectations(timeout: 1)
  }

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
    waitForExpectations(timeout: 1)
  }

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
    waitForExpectations(timeout: 1)
  }

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
    waitForExpectations(timeout: 1)
  }

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
    waitForExpectations(timeout: 1)
  }

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
    waitForExpectations(timeout: 1)
  }

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
    waitForExpectations(timeout: 1)
  }

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
    waitForExpectations(timeout: 1)
  }

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
    waitForExpectations(timeout: 1)
  }
}
