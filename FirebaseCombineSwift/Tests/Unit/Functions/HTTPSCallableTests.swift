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

class MockFunctions: Functions {
  override func callFunction(_ name: String,
                             with data: Any?,
                             timeout: TimeInterval,
                             completion: @escaping (HTTPSCallableResult?, Error?) -> Void) {
    let result = HTTPSCallableResult(data: "mockResult")
    completion(result, nil)
  }
}

class HTTPSCallableTests: XCTestCase {
  func testCallWithoutParameters() {
    // given
    var cancellables = Set<AnyCancellable>()
    let funcationWasCalledExpectation = expectation(description: "Function was called")

    let dummy = MockFunctions.functions().httpsCallable("dummy")
    dummy.foo()
    dummy.call()
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        guard let result = authDataResult.data as? String else {
          XCTFail("Expected String data")
          return
        }

        XCTAssertEqual(result, "mockResult")
        funcationWasCalledExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [funcationWasCalledExpectation], timeout: expectationTimeout)
  }
}
