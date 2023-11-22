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

/**
 * Enum representing the internal state of an upload or download task.
 */
enum StorageTaskState {
  /**
   * Unknown task state
   */
  case unknown
  /**
   * Task is being queued is ready to run
   */
  case queueing
  /**
   * Task is resuming from a paused state
   */
  case resuming
  /**
   * Task is currently running
   */
  case running
  /**
   * Task reporting a progress event
   */
  case progress
  /**
   * Task is pausing
   */
  case pausing
  /**
   * Task is completing successfully
   */
  case completing
  /**
   * Task is failing unrecoverably
   */
  case failing
  /**
   * Task paused successfully
   */
  case paused
  /**
   * Task cancelled successfully
   */
  case cancelled
  /**
   * Task completed successfully
   */
  case success
  /**
   * Task failed unrecoverably
   */
  case failed
}
