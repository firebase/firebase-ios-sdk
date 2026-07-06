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

#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

/**
 * A superclass to all Storage tasks, including `StorageUploadTask`
 * and `StorageDownloadTask`, to provide state transitions, event raising, and common storage
 * for metadata and errors.
 *
 * Callbacks are always fired on the developer-specified callback queue.
 * If no queue is specified, it defaults to the main queue.
 * This class is thread-safe.
 */
@objc(FIRStorageTask) open class StorageTask: NSObject, @unchecked Sendable {
  /**
   * An immutable view of the task and associated metadata, progress, error, etc.
   */
  @objc public var snapshot: StorageTaskSnapshot {
    objc_sync_enter(StorageTask.self)
    defer { objc_sync_exit(StorageTask.self) }
    let progress = Progress(totalUnitCount: self.progress.totalUnitCount)
    progress.completedUnitCount = self.progress.completedUnitCount
    return StorageTaskSnapshot(
      task: self,
      state: _state,
      reference: reference,
      progress: progress,
      metadata: _metadata,
      error: _error
    )
  }

  // MARK: - Internal Implementations

  private var _state: StorageTaskState = .unknown
  var state: StorageTaskState {
    get {
      objc_sync_enter(StorageTask.self)
      defer { objc_sync_exit(StorageTask.self) }
      return _state
    }
    set {
      objc_sync_enter(StorageTask.self)
      defer { objc_sync_exit(StorageTask.self) }
      _state = newValue
    }
  }

  private var _metadata: StorageMetadata?
  var metadata: StorageMetadata? {
    get {
      objc_sync_enter(StorageTask.self)
      defer { objc_sync_exit(StorageTask.self) }
      return _metadata
    }
    set {
      objc_sync_enter(StorageTask.self)
      defer { objc_sync_exit(StorageTask.self) }
      _metadata = newValue
    }
  }

  private var _error: NSError?
  var error: NSError? {
    get {
      objc_sync_enter(StorageTask.self)
      defer { objc_sync_exit(StorageTask.self) }
      return _error
    }
    set {
      objc_sync_enter(StorageTask.self)
      defer { objc_sync_exit(StorageTask.self) }
      _error = newValue
    }
  }

  /**
   * NSProgress object which tracks the progress of an observable task.
   */
  var progress: Progress

  /**
   * Reference pointing to the location the task is being performed against.
   */
  let reference: StorageReference

  /**
   * A serial queue for all storage operations.
   */
  let dispatchQueue: DispatchQueue

  let baseRequest: URLRequest

  init(reference: StorageReference,
       queue: DispatchQueue) {
    self.reference = reference
    dispatchQueue = queue
    progress = Progress(totalUnitCount: 0)
    baseRequest = StorageUtils.defaultRequestForReference(reference: reference)
  }
}

/**
 * Defines task operations such as pause, resume, cancel, and enqueue for all tasks.
 *
 * All tasks are required to implement enqueue, which begins the task, and may optionally
 * implement pause, resume, and cancel, which operate on the task to pause, resume, and cancel
 * operations.
 */
@objc(FIRStorageTaskManagement) public protocol StorageTaskManagement: NSObjectProtocol {
  /**
   * Prepares a task and begins execution.
   */
  @objc func enqueue()

  /**
   * Pauses a task currently in progress.
   */
  @objc optional func pause()

  /**
   * Cancels a task.
   */
  @objc optional func cancel()

  /**
   * Resumes a paused task.
   */
  @objc optional func resume()
}
