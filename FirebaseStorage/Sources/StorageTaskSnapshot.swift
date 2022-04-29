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

  // MARK: - NSObject overrides

  @objc override public var description: String {
    return saveDescription
  }

  private let saveDescription: String

  internal convenience init(task: StorageTask) {
    self.init(impl: task.impl.snapshot, task: task)
  }

  internal init(impl: FIRIMPLStorageTaskSnapshot, task: StorageTask) {
    self.task = task
    if let metadata = impl.metadata {
      self.metadata = StorageMetadata(impl: metadata)
    } else {
      metadata = nil
    }
    reference = StorageReference(impl.reference)
    progress = impl.progress
    error = impl.error
    status = StorageTaskStatus(rawValue: impl.status.rawValue)!
    saveDescription = impl.description
  }
}
