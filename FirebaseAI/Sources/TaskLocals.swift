// Copyright 2026 Google LLC
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

/// A container for task-local values used within the Firebase AI Logic SDK.
///
/// See https://developer.apple.com/documentation/swift/tasklocal for more details about
// `TaskLocal` values in Swift.
enum TaskLocals {
  /// A task-local value indicating whether the current request is a hybrid request.
  ///
  /// This is used to pass context down the call stack without modifying function signatures.
  @TaskLocal static var isHybridRequest = false
}
