//
// Copyright 2024-2026 Google LLC
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

/// An internal actor that protects mutable state for the Sessions SDK.
actor SessionsState {
  private var subscribers: [SessionsSubscriber] = []
  private var registeredSubscribers: Set<SessionsSubscriberName> = []
  nonisolated let expectedSubscribers: Set<SessionsSubscriberName>
  private var continuations: [CheckedContinuation<Void, Never>] = []

  init(expectedSubscribers: Set<SessionsSubscriberName>) {
    self.expectedSubscribers = expectedSubscribers
  }

  func register(subscriber: SessionsSubscriber, name: SessionsSubscriberName) {
    guard !registeredSubscribers.contains(name) else { return }
    subscribers.append(subscriber)
    registeredSubscribers.insert(name)
    if registeredSubscribers.isSuperset(of: expectedSubscribers) {
      for continuation in continuations {
        continuation.resume()
      }
      continuations.removeAll()
    }
  }

  func waitUntilAllRegistered() async {
    if expectedSubscribers.isEmpty || registeredSubscribers.isSuperset(of: expectedSubscribers) {
      return
    }
    // Note: If cancellation is required, use withTaskCancellationHandler and a throwing continuation.
    await withCheckedContinuation { continuation in
      continuations.append(continuation)
    }
  }

  var currentSubscribers: [SessionsSubscriber] {
    subscribers
  }
}
