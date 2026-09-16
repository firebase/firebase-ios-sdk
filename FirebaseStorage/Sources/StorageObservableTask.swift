// Copyright 2022 Google LLC
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

/**
 * An extended `StorageTask` providing observable semantics that can be used for responding to changes
 * in task state.
 *
 * Observers produce a `StorageHandle`, which is used to keep track of and remove specific
 * observers at a later date.
 */
@objc(FIRStorageObservableTask) open class StorageObservableTask: StorageTask, @unchecked Sendable {
  /**
   * Observes changes in the upload status: Resume, Pause, Progress, Success, and Failure.
   * - Parameters:
   *   - status: The `StorageTaskStatus` change to observe.
   *   - handler: A callback that fires every time the status event occurs,
   *        containing a `StorageTaskSnapshot` describing task state.
   * - Returns: A task handle that can be used to remove the observer at a later date.
   */
  @objc(observeStatus:handler:) @discardableResult
  open func observe(_ status: StorageTaskStatus,
                    handler: @escaping (StorageTaskSnapshot) -> Void) -> String {
    let callback = handler
    let uuidString = UUID().uuidString

    let snapshot = stateLock.withLock { () -> StorageTaskSnapshot in
      handlerDictionaries[status]?[uuidString] = callback
      handleToStatusMap[uuidString] = status
      return snapshotUnderLock()
    }

    var shouldFire = false
    switch status {
    case .pause:
      shouldFire = snapshot.state == .pausing || snapshot.state == .paused
    case .resume:
      shouldFire = snapshot.state == .resuming || snapshot.state == .running
    case .progress:
      shouldFire = snapshot.state == .running || snapshot.state == .progress
    case .success:
      shouldFire = snapshot.state == .success
    case .failure:
      shouldFire = snapshot.state == .failed || snapshot.state == .failing
    case .unknown:
      fatalError(
        "Invalid observer status requested, use one of: Pause, Resume, Progress, Complete, or Failure"
      )
    }

    if shouldFire {
      reference.storage.callbackQueue.async {
        callback(snapshot)
      }
    }

    return uuidString
  }

  /**
   * Removes the single observer with the provided handle.
   * - Parameter handle: The handle of the task to remove.
   */
  @objc(removeObserverWithHandle:) open func removeObserver(withHandle handle: String) {
    stateLock.withLock {
      if let status = handleToStatusMap[handle] {
        handlerDictionaries[status]?.removeValue(forKey: handle)
        handleToStatusMap.removeValue(forKey: handle)
      }
    }
  }

  /**
   * Removes all observers for a single status.
   * - Parameter status: A `StorageTaskStatus` to remove all listeners for.
   */
  @objc(removeAllObserversForStatus:)
  open func removeAllObservers(for status: StorageTaskStatus) {
    stateLock.withLock {
      if let handlerDictionary = handlerDictionaries[status] {
        for (key, _) in handlerDictionary {
          handleToStatusMap.removeValue(forKey: key)
        }
        handlerDictionaries[status]?.removeAll()
      }
    }
  }

  /**
   * Removes all observers.
   */
  @objc open func removeAllObservers() {
    stateLock.withLock {
      for (status, _) in handlerDictionaries {
        handlerDictionaries[status]?.removeAll()
      }
      handleToStatusMap.removeAll()
    }
  }

  // MARK: - Private Handler Dictionaries

  var handlerDictionaries: [StorageTaskStatus: [String: (StorageTaskSnapshot) -> Void]]
  var handleToStatusMap: [String: StorageTaskStatus]

  /**
   * The file to download to or upload from
   */
  let fileURL: URL?

  // MARK: - Internal Implementations

  init(reference: StorageReference,
       queue: DispatchQueue,
       file: URL?) {
    handlerDictionaries = [
      .resume: [String: (StorageTaskSnapshot) -> Void](),
      .pause: [String: (StorageTaskSnapshot) -> Void](),
      .progress: [String: (StorageTaskSnapshot) -> Void](),
      .success: [String: (StorageTaskSnapshot) -> Void](),
      .failure: [String: (StorageTaskSnapshot) -> Void](),
    ]
    handleToStatusMap = [:]
    fileURL = file
    super.init(reference: reference, queue: queue)
  }

  func fire(for status: StorageTaskStatus, snapshot: StorageTaskSnapshot) {
    if let observerDictionary = stateLock.withLock({ handlerDictionaries[status] }) {
      fire(handlers: observerDictionary, snapshot: snapshot)
    }
  }

  func fire(handlers: [String: (StorageTaskSnapshot) -> Void],
            snapshot: StorageTaskSnapshot) {
    for handler in handlers.values {
      reference.storage.callbackQueue.async {
        handler(snapshot)
      }
    }
  }
}
