// Copyright 2026 Google LLC
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

@testable import FirebaseStorage
import Foundation
import XCTest

class StorageObservableTaskTests: StorageTestHelpers {
  func testSuccessIsDeliveredOnceToEachObserver() {
    let callCounts = observeTerminalEvent(status: .success, terminalState: .success)
    XCTAssertEqual(callCounts.before, 1)
    XCTAssertEqual(callCounts.during, 1)
    XCTAssertEqual(callCounts.after, 1)
  }

  func testFailureIsDeliveredOnceToEachObserver() {
    let callCounts = observeTerminalEvent(status: .failure, terminalState: .failed)
    XCTAssertEqual(callCounts.before, 1)
    XCTAssertEqual(callCounts.during, 1)
    XCTAssertEqual(callCounts.after, 1)
  }

  // MARK: - Helpers

  /// Completes an upload task with `terminalState` the way `StorageUploadTask` does: the state is
  /// updated under the state lock, and observers are notified after the lock is released.
  /// Observers are added before the state change, between the state change and the notification
  /// (as can happen when `observe` races with the task completing on another queue), and after
  /// the notification. Returns how many times each observer was called.
  private func observeTerminalEvent(status: StorageTaskStatus,
                                    terminalState: StorageTaskState)
    -> (before: Int, during: Int, after: Int) {
    let ref = rootReference().child("object")
    let task = StorageUploadTask(reference: ref,
                                 queue: ref.storage.dispatchQueue,
                                 data: Data("data".utf8),
                                 metadata: StorageMetadata())
    // Observers run on the callback queue (the main queue), which also serializes the counters.
    var before = 0
    var during = 0
    var after = 0

    task.observe(status) { _ in before += 1 }
    let snapshot = task.stateLock.withLock { () -> StorageTaskSnapshot in
      task.state = terminalState
      if terminalState == .failed {
        task.error = StorageError.unknown(message: "test", serverError: [:]) as NSError
      }
      return task.snapshotUnderLock()
    }
    task.observe(status) { _ in during += 1 }
    task.finishTaskWithStatus(status: status, snapshot: snapshot)
    task.observe(status) { _ in after += 1 }

    // Handlers are dispatched asynchronously to the callback queue; wait until it is drained.
    let drained = expectation(description: "callback queue drained")
    ref.storage.callbackQueue.async { drained.fulfill() }
    wait(for: [drained], timeout: 10)
    return (before, during, after)
  }
}
