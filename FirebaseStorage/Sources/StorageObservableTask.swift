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
@objc(FIRStorageObservableTask) open class StorageObservableTask: StorageTask {
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

    // Note: self.snapshot is synchronized
    let snapshot = self.snapshot

    // TODO: use an increasing counter instead of a random UUID
    let uuidString = updateHandlerDictionary(for: status, with: callback)
    if let handlerDictionary = handlerDictionaries[status] {
      switch status {
      case .pause:
        if state == .pausing || state == .paused {
          fire(handlers: handlerDictionary, snapshot: snapshot)
        }
      case .resume:
        if state == .resuming || state == .running {
          fire(handlers: handlerDictionary, snapshot: snapshot)
        }
      case .progress:
        if state == .running || state == .progress {
          fire(handlers: handlerDictionary, snapshot: snapshot)
        }
      case .success:
        if state == .success {
          fire(handlers: handlerDictionary, snapshot: snapshot)
        }
      case .failure:
        if state == .failed || state == .failing {
          fire(handlers: handlerDictionary, snapshot: snapshot)
        }
      case .unknown: fatalError("Invalid observer status requested, use one " +
          "of: Pause, Resume, Progress, Complete, or Failure")
      }
    }
    stateLock.lock()
    handleToStatusMap[uuidString] = status
    stateLock.unlock()

    return uuidString
  }

  /**
   * Removes the single observer with the provided handle.
   * - Parameter handle: The handle of the task to remove.
   */
  @objc(removeObserverWithHandle:) open func removeObserver(withHandle handle: String) {
    if let status = handleToStatusMap[handle] {
      stateLock.lock()
      handlerDictionaries[status]?.removeValue(forKey: handle)
      handleToStatusMap.removeValue(forKey: handle)
      stateLock.unlock()
    }
  }

  /**
   * Removes all observers for a single status.
   * - Parameter status: A `StorageTaskStatus` to remove all listeners for.
   */
  @objc(removeAllObserversForStatus:)
  open func removeAllObservers(for status: StorageTaskStatus) {
    if let handlerDictionary = handlerDictionaries[status] {
      stateLock.lock()
      for (key, _) in handlerDictionary {
        handleToStatusMap.removeValue(forKey: key)
      }
      handlerDictionaries[status]?.removeAll()
      stateLock.unlock()
    }
  }

  /**
   * Removes all observers.
   */
  @objc open func removeAllObservers() {
    stateLock.lock()
    for (status, _) in handlerDictionaries {
      handlerDictionaries[status]?.removeAll()
    }
    handleToStatusMap.removeAll()
    stateLock.unlock()
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

  func updateHandlerDictionary(for status: StorageTaskStatus,
                               with handler: @escaping ((StorageTaskSnapshot) -> Void))
    -> String {
    // TODO: use an increasing counter instead of a random UUID
    let uuidString = NSUUID().uuidString
    stateLock.lock()
    handlerDictionaries[status]?[uuidString] = handler
    stateLock.unlock()
    return uuidString
  }

  func fire(for status: StorageTaskStatus, snapshot: StorageTaskSnapshot) {
    if let observerDictionary = handlerDictionaries[status] {
      fire(handlers: observerDictionary, snapshot: snapshot)
    }
  }

  func fire(handlers: [String: (StorageTaskSnapshot) -> Void],
            snapshot: StorageTaskSnapshot) {
    stateLock.lock()
    let enumeration = handlers.enumerated()
    stateLock.unlock()
    for (_, handler) in enumeration {
      reference.storage.callbackQueue.async {
        handler.value(snapshot)
      }
    }
  }
}
