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
 * `StorageTaskSnapshot` represents an immutable view of a task.
 * A snapshot contains a task, storage reference, metadata (if it exists),
 * progress, and an error (if one occurred).
 */
@objc(FIRStorageTaskSnapshot) open class StorageTaskSnapshot: NSObject {
  /**
   * The task this snapshot represents.
   */
  @objc public let task: StorageTask

  /**
   * Metadata returned by the task, or `nil` if no metadata returned.
   */
  @objc public let metadata: StorageMetadata?

  /**
   * The `StorageReference` this task operates on.
   */
  @objc public let reference: StorageReference

  /**
   * An object which tracks the progress of an upload or download.
   */
  @objc public let progress: Progress?

  /**
   * An error raised during task execution, or `nil` if no error occurred.
   */
  @objc public let error: Error?

  /**
   * The status of the task.
   */
  @objc public let status: StorageTaskStatus

  // MARK: NSObject overrides

  @objc override public var description: String {
    switch status {
    case .resume: return "<State: Resume>"
    case .progress: return "<State: Progress, Progress: \(String(describing: progress))>"
    case .pause: return "<State: Paused>"
    case .success: return "<State: Success>"
    case .failure: return "<State: Failed, Error: \(String(describing: error))"
    case .unknown: return "<State: Unknown>"
    }
  }

  init(task: StorageTask,
       state: StorageTaskState,
       reference: StorageReference,
       progress: Progress,
       metadata: StorageMetadata? = nil,
       error: NSError? = nil) {
    self.task = task
    self.reference = reference
    self.progress = progress
    self.error = error
    self.metadata = metadata

    switch state {
    case .queueing, .running, .resuming: status = StorageTaskStatus.resume
    case .progress: status = StorageTaskStatus.progress
    case .paused, .pausing: status = StorageTaskStatus.pause
    case .success, .completing: status = StorageTaskStatus.success
    case .cancelled, .failed, .failing: status = .failure
    case .unknown: status = .unknown
    }
  }
}
