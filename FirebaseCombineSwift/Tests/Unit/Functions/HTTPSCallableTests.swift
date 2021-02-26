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
import XCTest
@testable import FirebaseFunctions

class MockFunctions: Functions {
  var mockCallFunction: () throws -> HTTPSCallableResult?
  var mockVerifyParameter: ((_ data: Any?) throws -> Void)?
  override func callFunction(_ name: String,
                             with data: Any?,
                             timeout: TimeInterval,
                             completion: @escaping (HTTPSCallableResult?, Error?) -> Void) {
    do {
      try mockVerifyParameter?(data)
      let result = try mockCallFunction()
      completion(result, nil)
    } catch {
      completion(nil, error)
    }
  }
}

class HTTPSCallableTests: XCTestCase {
  func testCallWithoutParametersSuccess() {
    // given
    var cancellables = Set<AnyCancellable>()
    let functionWasCalledExpectation = expectation(description: "Function was called")
    functionWasCalledExpectation.assertForOverFulfill = true
    let callbackWasCalledExpectation = expectation(description: "Callback was called")

    let functions = MockFunctions.functions()
    let expectedResult = "mockResult w/o parameters"

    functions.mockCallFunction = {
      functionWasCalledExpectation.fulfill()
      return HTTPSCallableResult(data: expectedResult)
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
        callbackWasCalledExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(
      for: [callbackWasCalledExpectation, functionWasCalledExpectation],
      timeout: expectationTimeout
    )
  }

  func testCallWithParametersSuccess() {
    // given
    var cancellables = Set<AnyCancellable>()
    let funcationWasCalledExpectation = expectation(description: "Function was called")

    let functions = MockFunctions.functions()
    let inputParameter = "input parameter"
    let expectedResult = "mockResult w/ parameters: \(inputParameter)"
    functions.mockVerifyParameter = { data in
      XCTAssertEqual(data as? String, inputParameter)
    }
    functions.mockCallFunction = {
      HTTPSCallableResult(data: expectedResult)
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
        funcationWasCalledExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [funcationWasCalledExpectation], timeout: expectationTimeout)
  }

  func testCallWithParametersFailure() {
    // given
    var cancellables = Set<AnyCancellable>()
    let functionCallFailedExpectation = expectation(description: "Function call failed")

    let functions = MockFunctions.functions()
    let inputParameter = "input parameter"
    functions.mockCallFunction = {
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
    wait(for: [functionCallFailedExpectation], timeout: expectationTimeout)
  }
}
