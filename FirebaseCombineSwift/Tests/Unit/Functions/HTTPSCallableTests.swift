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
import FirebaseFunctions
import FirebaseCombineSwift

class MockFunctions: HTTPSCallableCombineExtension {
  var callWithDataHandler: ((_ data: Any?, _ completion: (HTTPSCallableResult?, Error?) -> Void)
    -> Void)?
  func call(_ data: Any?, completion: @escaping (HTTPSCallableResult?, Error?) -> Void) {
    callWithDataHandler?(data, completion)
  }

  var callHandler: ((_ completion: @escaping (HTTPSCallableResult?, Error?) -> Void) -> Void)?
  func call(completion: @escaping (HTTPSCallableResult?, Error?) -> Void) {
    callHandler?(completion)
  }
}

class MockCallableResult: HTTPSCallableResult {
  init(mockData: Any) {
    self.mockData = mockData
  }

  var mockData: Any?

  override var data: Any {
    return mockData ?? []
  }
}

class HTTPSCallableTests: XCTestCase {
  func testCallWithoutParameters() {
    // given
    var cancellables = Set<AnyCancellable>()
    let funcationWasCalledExpectation = expectation(description: "Function was called")
    let valueReceivedExpectation = expectation(description: "Value received")
    let finishExpectation = expectation(description: "Finished")

    let expectedResult = MockCallableResult(mockData: "mockResult")

    let callable = MockFunctions()
    callable.callHandler = { completion in
      funcationWasCalledExpectation.fulfill()
      completion(expectedResult, nil)
    }

    callable.call()
      .sink { completion in
        switch completion {
        case .finished:
          finishExpectation.fulfill()
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        valueReceivedExpectation.fulfill()

        guard let result = authDataResult.data as? String else {
          XCTFail("Expected String data")
          return
        }

        XCTAssertEqual(result, "mockResult")
      }
      .store(in: &cancellables)

    // then
    wait(
      for: [funcationWasCalledExpectation, valueReceivedExpectation, finishExpectation],
      timeout: expectationTimeout,
      enforceOrder: true
    )
  }
}
