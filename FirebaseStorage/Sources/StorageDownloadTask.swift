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
 * `StorageDownloadTask` implements resumable downloads from an object in Firebase Storage.
 * Downloads can be returned on completion with a completion handler, and can be monitored
 * by attaching observers, or controlled by calling `pause()`, `resume()`,
 * or `cancel()`.
 * Downloads can currently be returned as `Data` in memory, or as a `URL` to a file on disk.
 * Downloads are performed on a background queue, and callbacks are raised on the developer
 * specified `callbackQueue` in Storage, or the main queue if left unspecified.
 * Currently all uploads must be initiated and managed on the main queue.
 */
@objc(FIRStorageDownloadTask) open class StorageDownloadTask: StorageObservableTask,
  StorageTaskManagement {
  /**
   * Prepares a task and begins execution.
   */
  @objc open func enqueue() {
    (impl as! FIRIMPLStorageDownloadTask).enqueue()
  }

  /**
   * Pauses a task currently in progress. Calling this on a paused task has no effect.
   */
  @objc open func pause() {
    (impl as! FIRIMPLStorageDownloadTask).pause()
  }

  /**
   * Cancels a task.
   */
  @objc open func cancel() {
    (impl as! FIRIMPLStorageDownloadTask).cancel()
  }

  /**
   * Resumes a paused task. Calling this on a running task has no effect.
   */
  @objc open func resume() {
    (impl as! FIRIMPLStorageDownloadTask).resume()
  }

  internal init(_ impl: FIRIMPLStorageDownloadTask) {
    super.init(impl: impl)
  }
}
