// Copyright 2023 Google LLC
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
import XCTest

@testable import FirebaseAuth

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class SerialTaskQueueTests: XCTestCase {
  func testExecution() {
    let expectation = self.expectation(description: #function)
    let queue = AuthSerialTaskQueue()
    queue.enqueueTask { completionArg in
      completionArg()
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  func testCompletion() {
    let expectation = self.expectation(description: #function)
    let queue = AuthSerialTaskQueue()
    var completion: (() -> Void)?
    queue.enqueueTask { completionArg in
      completion = completionArg
      expectation.fulfill()
    }
    var executed = false
    var nextExpectation: XCTestExpectation?
    queue.enqueueTask { completionArg in
      executed = true
      completionArg()
      nextExpectation?.fulfill()
    }
    // The second task should not be executed until the first is completed.
    waitForExpectations(timeout: 5)
    XCTAssertNotNil(completion)
    XCTAssertFalse(executed)
    nextExpectation = self.expectation(description: "next")
    completion?()
    waitForExpectations(timeout: 5)
    XCTAssertTrue(executed)
  }

  func testTargetQueue() {
    let expectation = self.expectation(description: #function)
    let queue = AuthSerialTaskQueue()
    var executed = false
    kAuthGlobalWorkQueue.suspend()
    queue.enqueueTask { completionArg in
      executed = true
      completionArg()
      expectation.fulfill()
    }
    // The task should not executed until the global work queue is resumed.
    sleep(1)
    XCTAssertFalse(executed)
    kAuthGlobalWorkQueue.resume()
    waitForExpectations(timeout: 5)
    XCTAssertTrue(executed)
  }

  func testTaskQueueNoAffectTargetQueue() {
    let queue = AuthSerialTaskQueue()
    var completion: (() -> Void)?
    queue.enqueueTask { completionArg in
      completion = completionArg
    }
    var executed = false
    var nextExpectation: XCTestExpectation?
    queue.enqueueTask { completionArg in
      executed = true
      completionArg()
      nextExpectation?.fulfill()
    }
    let expectation = self.expectation(description: #function)
    kAuthGlobalWorkQueue.async {
      expectation.fulfill()
    }
    // The task queue waiting for completion should not affect the global work queue.
    waitForExpectations(timeout: 5)
    XCTAssertNotNil(completion)
    XCTAssertFalse(executed)
    nextExpectation = self.expectation(description: "next")
    completion?()
    waitForExpectations(timeout: 555)
    XCTAssertTrue(executed)
  }
}
