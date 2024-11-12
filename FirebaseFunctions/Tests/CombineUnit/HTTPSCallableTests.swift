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
import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
@testable import FirebaseFunctions
import FirebaseFunctionsCombineSwift
import FirebaseMessagingInterop
import GTMSessionFetcherCore
import XCTest

// hardcoded in HTTPSCallable.swift
private let timeoutInterval: TimeInterval = 70.0
private let expectationTimeout: TimeInterval = 2

class MockFunctions: Functions {
  let mockCallFunction: () throws -> HTTPSCallableResult
  var verifyParameters: ((_ url: URL, _ data: Any?, _ timeout: TimeInterval) throws -> Void)?
  override func callFunction(at url: URL,
                             withObject data: Any?,
                             options: HTTPSCallableOptions?,
                             timeout: TimeInterval,
                             completion: @escaping (
                               (Result<HTTPSCallableResult, any Error>) -> Void
                             )) {
    do {
      try verifyParameters?(url, data, timeout)
      let result = try mockCallFunction()
      completion(.success(result))
    } catch {
      completion(.failure(error))
    }
  }

  init(mockCallFunction: @escaping () throws -> HTTPSCallableResult) {
    self.mockCallFunction = mockCallFunction
    super.init(
      projectID: "dummy-project",
      region: "test-region",
      customDomain: nil,
      auth: nil,
      messaging: nil,
      appCheck: nil,
      fetcherService: GTMSessionFetcherService()
    )
  }
}

public class HTTPSCallableResultFake: HTTPSCallableResult {
  let fakeData: String
  init(data: String) {
    fakeData = data
    super.init(data: data)
  }
}

@available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
class HTTPSCallableTests: XCTestCase {
  func testCallWithoutParametersSuccess() {
    // given
    var cancellables = Set<AnyCancellable>()
    let httpsFunctionWasCalledExpectation = expectation(description: "HTTPS Function was called")
    let functionWasCalledExpectation = expectation(description: "Function was called")
    let expectedResult = "mockResult w/o parameters"

    let functions = MockFunctions {
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

    let inputParameter = "input parameter"
    let expectedResult = "mockResult w/ parameters: \(inputParameter)"
    let functions = MockFunctions {
      httpsFunctionWasCalledExpectation.fulfill()
      return HTTPSCallableResultFake(data: expectedResult)
    }
    functions.verifyParameters = { url, data, timeout in
      XCTAssertEqual(
        url.absoluteString,
        "https://test-region-dummy-project.cloudfunctions.net/dummyFunction"
      )
      XCTAssertEqual(data as? String, inputParameter)
      XCTAssertEqual(timeout as TimeInterval, timeoutInterval)
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

    let inputParameter = "input parameter"
    let functions = MockFunctions {
      httpsFunctionWasCalledExpectation.fulfill()
      throw NSError(domain: FunctionsErrorDomain,
                    code: FunctionsErrorCode.internal.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "Response is missing data field."])
    }
    functions.verifyParameters = { url, data, timeout in
      XCTAssertEqual(
        url.absoluteString,
        "https://test-region-dummy-project.cloudfunctions.net/dummyFunction"
      )
      XCTAssertEqual(data as? String, inputParameter)
      XCTAssertEqual(timeout as TimeInterval, timeoutInterval)
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
