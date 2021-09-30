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

import Combine
import FirebaseCore
import FirebaseFunctionsCombineSwift
@testable import FirebaseFunctionsTestingSupport
import XCTest

// hardcoded in FIRHTTPSCallable.m
private let kFunctionsTimeout: TimeInterval = 70.0
private let expectationTimeout: TimeInterval = 2

class MockFunctions: Functions {
  var mockCallFunction: () throws -> HTTPSCallableResult?
  var verifyParameters: ((_ name: String, _ data: Any?, _ timeout: TimeInterval) throws -> Void)?
  override func callFunction(_ name: String,
                             with data: Any?,
                             timeout: TimeInterval,
                             completion: @escaping (HTTPSCallableResult?, Error?) -> Void) {
    do {
      try verifyParameters?(name, data, timeout)
      let result = try mockCallFunction()
      completion(result, nil)
    } catch {
      completion(nil, error)
    }
  }
}

@available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
class HTTPSCallableTests: XCTestCase {
  override func setUp() {
    super.setUp()

    if FirebaseApp.app() == nil {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      FirebaseApp.configure(options: options)
    }
  }

  func testCallWithoutParametersSuccess() {
    // given
    var cancellables = Set<AnyCancellable>()
    let httpsFunctionWasCalledExpectation = expectation(description: "HTTPS Function was called")
    let functionWasCalledExpectation = expectation(description: "Function was called")

    let functions = MockFunctions.functions()
    let expectedResult = "mockResult w/o parameters"

    functions.mockCallFunction = {
      httpsFunctionWasCalledExpectation.fulfill()
      return HTTPSCallableResultFake(data: expectedResult)
    }
    let dummyFunction = functions.httpsCallable("dummyFunction")

    // when
    dummyFunction.call()
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { functionResult in
        guard let result = functionResult.data as? String else {
          XCTFail("Expected String data")
          return
        }

        XCTAssertEqual(result, expectedResult)
        functionWasCalledExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(
      for: [functionWasCalledExpectation, httpsFunctionWasCalledExpectation],
      timeout: expectationTimeout
    )
  }

  func testCallWithParametersSuccess() {
    // given
    var cancellables = Set<AnyCancellable>()
    let httpsFunctionWasCalledExpectation = expectation(description: "HTTPS Function was called")
    let functionWasCalledExpectation = expectation(description: "Function was called")

    let functions = MockFunctions.functions()
    let inputParameter = "input parameter"
    let expectedResult = "mockResult w/ parameters: \(inputParameter)"
    functions.verifyParameters = { name, data, timeout in
      XCTAssertEqual(name as String, "dummyFunction")
      XCTAssertEqual(data as? String, inputParameter)
      XCTAssertEqual(timeout as TimeInterval, kFunctionsTimeout)
    }
    functions.mockCallFunction = {
      httpsFunctionWasCalledExpectation.fulfill()
      return HTTPSCallableResultFake(data: expectedResult)
    }
    let dummyFunction = functions.httpsCallable("dummyFunction")

    // when
    dummyFunction.call(inputParameter)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { functionResult in
        guard let result = functionResult.data as? String else {
          XCTFail("Expected String data")
          return
        }

        XCTAssertEqual(result, expectedResult)
        functionWasCalledExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(
      for: [httpsFunctionWasCalledExpectation, functionWasCalledExpectation],
      timeout: expectationTimeout
    )
  }

  func testCallWithParametersFailure() {
    // given
    var cancellables = Set<AnyCancellable>()
    let httpsFunctionWasCalledExpectation = expectation(description: "HTTPS Function was called")
    let functionCallFailedExpectation = expectation(description: "Function call failed")

    let functions = MockFunctions.functions()
    let inputParameter = "input parameter"
    functions.verifyParameters = { name, data, timeout in
      XCTAssertEqual(name as String, "dummyFunction")
      XCTAssertEqual(data as? String, inputParameter)
      XCTAssertEqual(timeout as TimeInterval, kFunctionsTimeout)
    }
    functions.mockCallFunction = {
      httpsFunctionWasCalledExpectation.fulfill()
      throw NSError(domain: FunctionsErrorDomain,
                    code: FunctionsErrorCode.internal.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "Response is missing data field."])
    }
    let dummyFunction = functions.httpsCallable("dummyFunction")

    // when
    dummyFunction.call(inputParameter)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          // Verify user mismatch error.
          XCTAssertEqual(error.code, FunctionsErrorCode.internal.rawValue)

          functionCallFailedExpectation.fulfill()
        }
      } receiveValue: { functionResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(
      for: [functionCallFailedExpectation, httpsFunctionWasCalledExpectation],
      timeout: expectationTimeout
    )
  }
}
