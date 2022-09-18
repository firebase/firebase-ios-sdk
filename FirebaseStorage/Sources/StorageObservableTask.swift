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

import FirebaseStorageInternal

/**
 * An extended `StorageTask` providing observable semantics that can be used for responding to changes
 * in task state.
 * Observers produce a `StorageHandle`, which is used to keep track of and remove specific
 * observers at a later date.
 * This class is not thread safe and can only be called on the main thread.
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
    return (impl as! FIRIMPLStorageObservableTask)
      .observe(FIRIMPLStorageTaskStatus(rawValue: status.rawValue)!) { snapshot in
        handler(StorageTaskSnapshot(impl: snapshot, task: StorageTask(impl: snapshot.task)))
      }
  }

  /**
   * Removes the single observer with the provided handle.
   * - Parameter handle The handle of the task to remove.
   */
  @objc(removeObserverWithHandle:) open func removeObserver(withHandle handle: String) {
    (impl as! FIRIMPLStorageObservableTask).removeObserver(withHandle: handle)
  }

  /**
   * Removes all observers for a single status.
   * - Parameter status A `StorageTaskStatus` to remove all listeners for.
   */
  @objc(removeAllObserversForStatus:)
  open func removeAllObservers(for status: StorageTaskStatus) {
    (impl as! FIRIMPLStorageObservableTask)
      .removeAllObservers(for: FIRIMPLStorageTaskStatus(rawValue: status.rawValue)!)
  }

  /**
   * Removes all observers.
   */
  @objc open func removeAllObservers() {
    (impl as! FIRIMPLStorageObservableTask).removeAllObservers()
  }

  internal init(impl: FIRIMPLStorageObservableTask) {
    super.init(impl: impl)
  }
}
