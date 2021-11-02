// Copyright 2021 Google LLC
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
@testable import HeartbeatLogging

// Note to myself:
// A unit test tests a single unit. During a unit test,
// all external dependencies and values are either
// mocked, stubbed, or abstracted using functions —
// and the object’s own APIs (or mocks) are used for verification.

// in this class, that means underlying buffer

class HeartbeatInfoTests: XCTestCase {
  func testOfferWhenEmpty() throws {
    // Given
    let heartbeat = Heartbeat(info: #function)
    var heartbeats = HeartbeatInfo(capacity: 10)
    // When
    let heartbeatWasAccepted = heartbeats.offer(heartbeat)
    // Then
    XCTAssertTrue(heartbeatWasAccepted)
  }

  func testOfferAndAcceptWhenFull() throws {}

  func testOfferAndRejectWhenFull() throws {}

  // MARK: - Date Specific

  func testOfferAndRejectWhenInSameDailyPeriod() throws {}

  func testOfferDailyHeartbeats() throws {
    // Set the system clock to `Nov 01 2021 00:00:00 (EST)`.
    let systemClock = SystemClock(Date(timeIntervalSince1970: 1_635_739_200))

    var heartbeats = HeartbeatInfo(capacity: 5)
    // TODO: Assert that it's empty.

    // Accept the first heartbeat logged today.
    let todayHeartbeat = Heartbeat(info: "today", date: systemClock.date)
    XCTAssertTrue(heartbeats.offer(todayHeartbeat))

    // Advance the system clock by 24 hours (- 1 second).
    // –– Nov 01 2021 23:59:59 (EST)
    systemClock.advance(by: 60 * 60 * 24 - 1)

    // Reject a heartbeat logged later today.
    let eveningHeartbeat = Heartbeat(info: "evening", date: systemClock.date)
    XCTAssertFalse(heartbeats.offer(eveningHeartbeat))

    // Advance the system clock by 1 second.
    // –– Nov 02 2021 00:00:00 (EST)
    systemClock.advance(by: 1)

    // Accept a heartbeat logged tomorrow.
    let tomorrowHeartbeat = Heartbeat(info: "tomorrow", date: systemClock.date)
    XCTAssertTrue(heartbeats.offer(tomorrowHeartbeat))

    // Advance the system clock by ~1 year.
    systemClock.advance(by: 60 * 60 * 24 * 365.24)

    // Accept a heartbeat logged in future.
    let futureHeartbeat = Heartbeat(info: "future", date: systemClock.date)
    XCTAssertTrue(heartbeats.offer(futureHeartbeat))
  }

  func testOfferDailyHeartbeatEdgeCase() throws {
    // What happens if user sets system time forward (and a hb is logged),
    // then the user sets system time backwards?
  }

  // MARK: - HTTPHeaderRepresentable

  // TODO: Add protocol tests.
}

// MARK: - Fakes

/// Simulates the device system time.
class SystemClock {
  private(set) var date: Date

  init(_ date: Date = .init()) {
    self.date = date
  }

  func advance(by timeInterval: TimeInterval) {
    date = date.advanced(by: timeInterval)
  }
}
