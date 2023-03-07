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

// TODO: Get rid of public's and @objc's once FirebaseAuth.m is in Swift.

/** @class AuthDispatcher
    @brief A utility class used to facilitate scheduling tasks to be executed in the future.
 */
@objc(FIRAuthDispatcher) public class AuthDispatcher: NSObject {
  @objc(sharedInstance) public static let shared = AuthDispatcher()

  /** @property dispatchAfterImplementation
      @brief Allows custom implementation of dispatchAfterDelay:queue:callback:.
      @remarks Set to nil to restore default implementation.
   */
  @objc public
  var dispatchAfterImplementation: ((TimeInterval, DispatchQueue, @escaping () -> Void) -> Void)?

  /** @fn dispatchAfterDelay:queue:callback:
      @brief Schedules task in the future after a specified delay.

      @param delay The delay in seconds after which the task will be scheduled to execute.
      @param queue The dispatch queue on which the task will be submitted.
      @param task The task (block) to be scheduled for future execution.
   */
  @objc public
  func dispatch(afterDelay delay: TimeInterval, queue: DispatchQueue, task: @escaping () -> Void) {
    if let dispatchAfterImplementation {
      dispatchAfterImplementation(delay, queue, task)
    } else {
      queue.asyncAfter(deadline: DispatchTime.now() + delay, execute: task)
    }
  }
}
