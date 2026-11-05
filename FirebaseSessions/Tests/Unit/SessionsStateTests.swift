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

import XCTest

@testable import FirebaseSessions

/// A one-way flag used to observe whether an awaiting `Task` has resumed
/// without blocking the cooperative thread pool.
private actor Signal {
  private(set) var isSet = false

  func set() {
    isSet = true
  }
}

final class SessionsStateTests: XCTestCase {
  /// Generous timeout for operations that are expected to complete.
  private static let timeout: TimeInterval = 5

  /// Gives any runnable `Task` ample opportunity to make progress. Used before
  /// asserting that a waiter has *not* resumed, so that the assertion fails
  /// loudly rather than passing because the waiter simply hadn't been
  /// scheduled yet.
  private static func drainScheduler() async {
    for _ in 0 ..< 20 {
      await Task.yield()
    }
    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
  }

  // MARK: - Gate opens when there is nothing to wait for

  func test_noExpectedSubscribers_waitReturnsImmediately() async {
    let state = SessionsState(expectedSubscribers: [])

    let resumed = expectation(description: "waitUntilAllRegistered returned")
    Task {
      let subscribers = await state.waitUntilAllRegistered()
      XCTAssertTrue(subscribers.isEmpty)
      resumed.fulfill()
    }

    await fulfillment(of: [resumed], timeout: Self.timeout)
  }

  // MARK: - Gate stays closed until every expected subscriber registers

  func test_waitDoesNotResumeUntilAllExpectedSubscribersRegister() async {
    let state = SessionsState(expectedSubscribers: [.Crashlytics, .Performance])

    let signal = Signal()
    let resumed = expectation(description: "waiter resumed once all registered")
    let waiter = Task { () -> [SessionsSubscriber] in
      let subscribers = await state.waitUntilAllRegistered()
      await signal.set()
      resumed.fulfill()
      return subscribers
    }

    // Only one of the two expected subscribers has registered.
    await state.register(subscriber: MockSubscriber(name: .Crashlytics), name: .Crashlytics)
    await Self.drainScheduler()

    let resumedEarly = await signal.isSet
    XCTAssertFalse(
      resumedEarly,
      "waitUntilAllRegistered() resumed before Performance registered"
    )

    // Completing the set must open the gate.
    await state.register(subscriber: MockSubscriber(name: .Performance), name: .Performance)
    await fulfillment(of: [resumed], timeout: Self.timeout)

    // The gate hands back a snapshot containing both subscribers.
    let names = await Set(waiter.value.map(\.sessionsSubscriberName))
    XCTAssertEqual(names, [.Crashlytics, .Performance])
  }

  /// A subscriber that never declared itself as a dependency must not satisfy
  /// the gate on its own, but it should still be reported as a subscriber.
  /// This matches the pre-refactor promise-based behavior, where only expected
  /// subscribers had a promise to fulfill but every registrant was appended to
  /// the `subscribers` array.
  func test_unexpectedSubscriber_doesNotOpenGateButIsStillTracked() async {
    let state = SessionsState(expectedSubscribers: [.Crashlytics])

    let signal = Signal()
    let resumed = expectation(description: "waiter resumed once Crashlytics registered")
    let waiter = Task { () -> [SessionsSubscriber] in
      let subscribers = await state.waitUntilAllRegistered()
      await signal.set()
      resumed.fulfill()
      return subscribers
    }

    await state.register(subscriber: MockSubscriber(name: .Performance), name: .Performance)
    await Self.drainScheduler()

    let resumedEarly = await signal.isSet
    XCTAssertFalse(
      resumedEarly,
      "An unexpected subscriber must not satisfy the registration gate"
    )

    await state.register(subscriber: MockSubscriber(name: .Crashlytics), name: .Crashlytics)
    await fulfillment(of: [resumed], timeout: Self.timeout)

    let names = await Set(waiter.value.map(\.sessionsSubscriberName))
    XCTAssertEqual(names, [.Crashlytics, .Performance])
  }

  // MARK: - Gate stays open for subsequent session starts

  /// Each app foreground beyond the session timeout starts a new session and
  /// awaits the gate again. Once satisfied, the gate must never re-close.
  func test_waitAfterAllRegistered_returnsImmediatelyEveryTime() async {
    let state = SessionsState(expectedSubscribers: [.Crashlytics])
    await state.register(subscriber: MockSubscriber(name: .Crashlytics), name: .Crashlytics)

    for initiation in 1 ... 3 {
      let resumed = expectation(description: "wait returned for initiation \(initiation)")
      Task {
        let subscribers = await state.waitUntilAllRegistered()
        XCTAssertEqual(subscribers.count, 1)
        resumed.fulfill()
      }
      await fulfillment(of: [resumed], timeout: Self.timeout)
    }
  }

  // MARK: - Every queued continuation is resumed

  func test_multipleConcurrentWaiters_allResume() async {
    let state = SessionsState(expectedSubscribers: [.Crashlytics])

    let waiterCount = 8
    let resumed = expectation(description: "all waiters resumed")
    resumed.expectedFulfillmentCount = waiterCount

    for _ in 0 ..< waiterCount {
      Task {
        _ = await state.waitUntilAllRegistered()
        resumed.fulfill()
      }
    }

    // Let the waiters queue their continuations before the gate opens.
    await Self.drainScheduler()
    await state.register(subscriber: MockSubscriber(name: .Crashlytics), name: .Crashlytics)

    await fulfillment(of: [resumed], timeout: Self.timeout)
  }

  // MARK: - Registration is idempotent

  func test_duplicateRegistration_isIgnored() async {
    let state = SessionsState(expectedSubscribers: [.Crashlytics])

    await state.register(subscriber: MockSubscriber(name: .Crashlytics), name: .Crashlytics)
    await state.register(subscriber: MockSubscriber(name: .Crashlytics), name: .Crashlytics)

    let subscribers = await state.currentSubscribers
    XCTAssertEqual(
      subscribers.count, 1,
      "Registering the same subscriber name twice must not duplicate it"
    )
  }

  /// `Sessions.register(subscriber:)` hops onto an unstructured `Task`, so
  /// registrations can arrive concurrently and out of order. The actor must
  /// serialize them without losing the wakeup or duplicating subscribers.
  func test_concurrentRegistrations_areSerializedAndOpenGateExactlyOnce() async {
    let state = SessionsState(expectedSubscribers: [.Crashlytics, .Performance])

    let resumed = expectation(description: "waiter resumed")
    Task {
      _ = await state.waitUntilAllRegistered()
      resumed.fulfill()
    }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 25 {
        group.addTask {
          await state.register(
            subscriber: MockSubscriber(name: .Crashlytics), name: .Crashlytics
          )
        }
        group.addTask {
          await state.register(
            subscriber: MockSubscriber(name: .Performance), name: .Performance
          )
        }
      }
    }

    await fulfillment(of: [resumed], timeout: Self.timeout)

    let subscribers = await state.currentSubscribers
    XCTAssertEqual(
      subscribers.count, 2,
      "Concurrent duplicate registrations must be de-duplicated"
    )
  }
}
