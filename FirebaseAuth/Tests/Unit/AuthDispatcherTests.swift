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
class AuthDispatcherTests: XCTestCase {
  let kTestDelay = 0.1
  let kMaxDifferenceBetweenTimeIntervals = 0.4

  /** @fn testSharedInstance
      @brief Tests @c sharedInstance returns the same object.
   */
  func testSharedInstance() {
    let instance1 = AuthDispatcher.shared
    let instance2 = AuthDispatcher.shared
    XCTAssert(instance1 === instance2)
  }

  /** @fn testDispatchAfterDelay
      @brief Tests @c dispatchAfterDelay indeed dispatches the specified task after the provided
          delay.
   */
  func testDispatchAfterDelay() {
    let dispatcher = AuthDispatcher.shared
    let testWorkQueue = DispatchQueue(label: "test.work.queue")
    let expectation = self.expectation(description: #function)
    let dateBeforeDispatch = Date()
    dispatcher.dispatchAfterImplementation = nil
    dispatcher.dispatch(afterDelay: kTestDelay, queue: testWorkQueue) { [self] in
      let timeSinceDispatch = fabs(dateBeforeDispatch.timeIntervalSinceNow - self.kTestDelay)
      XCTAssertLessThan(timeSinceDispatch, kMaxDifferenceBetweenTimeIntervals)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testSetDispatchAfterImplementation
      @brief Tests that @c dispatchAfterImplementation indeed configures a custom implementation for
          @c dispatchAfterDelay.
   */
  func testSetDispatchAfterImplementation() {
    let dispatcher = AuthDispatcher.shared
    let testWorkQueue = DispatchQueue(label: "test.work.queue")
    let expectation = self.expectation(description: #function)
    dispatcher.dispatchAfterImplementation = { delay, queue, task in
      XCTAssertEqual(self.kTestDelay, delay)
      XCTAssertEqual(testWorkQueue, queue)
      expectation.fulfill()
    }

    dispatcher.dispatch(afterDelay: kTestDelay, queue: testWorkQueue) {
      // Fail to ensure this code is never executed.
      XCTFail("Should not execute this code")
    }
    waitForExpectations(timeout: 5)
  }
}
