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

/// An internal actor that protects mutable state for the Sessions SDK.
///
/// This replaces the previous `FBLPromise`-based registration barrier. It acts
/// as a *latching gate*: once every expected subscriber has registered, the
/// gate stays open for the remaining lifetime of the process, so session
/// starts after the first one resolve without suspending. That mirrors the old
/// behavior, where the per-subscriber promises stayed fulfilled once resolved.
///
/// If an expected subscriber never registers, waiters are never resumed and no
/// event is sent. This is also the pre-existing behavior of the unfulfilled
/// promises.
actor SessionsState {
  private var subscribers: [SessionsSubscriber] = []
  private var registeredSubscribers: Set<SessionsSubscriberName> = []
  nonisolated let expectedSubscribers: Set<SessionsSubscriberName>
  private var continuations: [CheckedContinuation<Void, Never>] = []

  init(expectedSubscribers: Set<SessionsSubscriberName>) {
    self.expectedSubscribers = expectedSubscribers
  }

  /// Records a subscriber and opens the gate once all expected subscribers
  /// have registered.
  ///
  /// Registration is idempotent per subscriber *name*. Subscribers that were
  /// never declared as dependencies are still tracked (so they contribute to
  /// the data collection check) but cannot open the gate on their own.
  ///
  /// This method is deliberately non-`async`: it contains no suspension
  /// points, so the actor runs it to completion. The de-duplication check, the
  /// append, and the continuation resume therefore cannot interleave with
  /// another `register` or `waitUntilAllRegistered` call.
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

  /// Suspends until every expected subscriber has registered, then returns a
  /// snapshot of the registered subscribers.
  ///
  /// The snapshot is returned from here rather than read through a separate
  /// accessor so that the session-start path only needs a single actor hop.
  /// As before, the snapshot reflects the state *after* the gate opens, so a
  /// subscriber that registers late is still included.
  func waitUntilAllRegistered() async -> [SessionsSubscriber] {
    if expectedSubscribers.isEmpty || registeredSubscribers.isSuperset(of: expectedSubscribers) {
      return subscribers
    }
    // No lost-wakeup race here: the closure passed to `withCheckedContinuation`
    // runs synchronously in this actor's isolation domain before the caller
    // suspends. A `register` call therefore cannot slip in between the check
    // above and the append below, so the continuation is always either
    // enqueued before the gate opens, or the fast path above already returned.
    //
    // Note: this continuation is not cancellable, so if an expected subscriber
    // never registers, waiters are never resumed. That matches the `FBLPromise`
    // implementation this replaced, where an unfulfilled promise left every
    // `.then` observer pending. Adding cancellation means first deciding what a
    // cancelled waiter returns for a partial subscriber list, then using
    // `withTaskCancellationHandler` with a throwing continuation.
    await withCheckedContinuation { continuation in
      continuations.append(continuation)
    }
    return subscribers
  }

  var currentSubscribers: [SessionsSubscriber] {
    subscribers
  }
}
