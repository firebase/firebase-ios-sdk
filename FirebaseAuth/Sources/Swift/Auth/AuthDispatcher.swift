// Copyright 2023 Google LLC
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

/// A utility class used to facilitate scheduling tasks to be executed in the future.
class AuthDispatcher {
  static let shared = AuthDispatcher()

  /// Allows custom implementation of dispatchAfterDelay:queue:callback:.
  ///
  /// Set to nil to restore default implementation.
  var dispatchAfterImplementation: ((TimeInterval, DispatchQueue, @escaping () -> Void) -> Void)?

  /// Schedules task in the future after a specified delay.
  /// - Parameter delay: The delay in seconds after which the task will be scheduled to execute.
  /// - Parameter queue: The dispatch queue on which the task will be submitted.
  /// - Parameter task: The task(block) to be scheduled for future execution.
  func dispatch(afterDelay delay: TimeInterval,
                queue: DispatchQueue,
                task: @escaping () -> Void) {
    if let dispatchAfterImplementation {
      dispatchAfterImplementation(delay, queue, task)
    } else {
      queue.asyncAfter(deadline: DispatchTime.now() + delay, execute: task)
    }
  }
}
