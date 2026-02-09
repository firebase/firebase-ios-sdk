// Copyright 2025 Google LLC
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

import XCTest
@testable import FirebaseCoreInternal

final class UnfairLockTests: XCTestCase {

  func testLockProtectsState() {
    let lock = UnfairLock(0)
    let iterations = 1000

    // Using DispatchQueue.concurrentPerform to simulate concurrency
    DispatchQueue.concurrentPerform(iterations: iterations) { _ in
      lock.withLock { value in
        value += 1
      }
    }

    XCTAssertEqual(lock.value(), iterations)
  }

  func testValueReturnsCurrentValue() {
    let lock = UnfairLock(42)
    XCTAssertEqual(lock.value(), 42)
  }

  func testWithLockMutatesValue() {
    let lock = UnfairLock("initial")
    lock.withLock { value in
      value = "updated"
    }
    XCTAssertEqual(lock.value(), "updated")
  }
}
