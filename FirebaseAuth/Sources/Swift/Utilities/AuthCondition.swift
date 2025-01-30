// Copyright 2024 Google LLC
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

/// Utility struct to make the execution of one task dependent upon a signal from another task.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
struct AuthCondition {
  private let waiter: () async -> Void
  private let stream: AsyncStream<Void>.Continuation

  init() {
    let (stream, continuation) = AsyncStream<Void>.makeStream()
    waiter = {
      for await _ in stream {}
    }
    self.stream = continuation
  }

  // Signal to unblock the waiter.
  func signal() {
    stream.finish()
  }

  /// Wait for the condition.
  func wait() async {
    await waiter()
  }
}
