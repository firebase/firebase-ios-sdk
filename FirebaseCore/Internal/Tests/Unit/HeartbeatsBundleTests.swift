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

@testable import FirebaseCoreInternal
import XCTest

class HeartbeatsBundleTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)

  func testInitializesWithDefaultCacheProvider() throws {
    // Given
    let heartbeatsBundle = HeartbeatsBundle(capacity: 0)
    // Then
    XCTAssertEqual(
      heartbeatsBundle.lastAddedHeartbeatDates,
      [
        .daily: .distantPast,
      ]
    )
  }

  func testAppendingHeartbeatUpdatesCache() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 1)
    let heartbeat = Heartbeat(agent: "dummy_agent", date: date, timePeriods: [.daily])

    // When
    heartbeatsBundle.append(heartbeat)

    // Then
    let heartbeatsBundleString = heartbeatsBundle
      .makeHeartbeatsPayload()
      .headerValue()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatsBundleString,
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent",
            "dates": ["2021-11-01"]
          }
        ]
      }
      """
    )

    XCTAssertEqual(heartbeatsBundle.lastAddedHeartbeatDates, [.daily: heartbeat.date])
  }

  func testAppendingHeartbeat_WhenCapacityIsZero_DoesNothing() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 0)
    let preAppendCacheSnapshot = heartbeatsBundle.lastAddedHeartbeatDates
    let heartbeat = Heartbeat(agent: "dummy_agent", date: date, timePeriods: [.daily])

    // When
    heartbeatsBundle.append(heartbeat)

    // Then
    let heartbeatsBundleString = heartbeatsBundle
      .makeHeartbeatsPayload()
      .headerValue()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatsBundleString,
      """
      {
        "version": 2,
        "heartbeats": []
      }
      """
    )

    XCTAssertEqual(heartbeatsBundle.lastAddedHeartbeatDates, preAppendCacheSnapshot)
  }

  func testAppendingHeartbeat_AtMaxCapacity_RemovesOverwrittenFromCache() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 1)
    let heartbeat1 = Heartbeat(agent: "dummy_agent_1", date: date, timePeriods: [.daily])
    heartbeatsBundle.append(heartbeat1)

    XCTAssertEqual(heartbeatsBundle.lastAddedHeartbeatDates, [.daily: heartbeat1.date])

    let heartbeat2 = Heartbeat(agent: "dummy_agent_2", date: date, timePeriods: [.daily])

    // When
    heartbeatsBundle.append(heartbeat2)

    // Then
    let heartbeatsBundleString = heartbeatsBundle
      .makeHeartbeatsPayload()
      .headerValue()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatsBundleString,
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent_2",
            "dates": ["2021-11-01"]
          }
        ]
      }
      """
    )

    XCTAssertEqual(heartbeatsBundle.lastAddedHeartbeatDates, [.daily: heartbeat2.date])
  }

  func testRemovingHeartbeatFromDateDoesNotUpdateCache() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 1)
    let heartbeat = Heartbeat(agent: "agent", date: date, timePeriods: [.daily])
    heartbeatsBundle.append(heartbeat)
    // When
    heartbeatsBundle.removeHeartbeat(from: date)
    // Then
    XCTAssertEqual(
      heartbeatsBundle.lastAddedHeartbeatDates,
      [
        .daily: heartbeat.date,
      ]
    )
  }

  func testRemovingHeartbeatFromDate_WhenCapacityIsZero_DoesNothing() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 0)
    let preRemoveCacheSnapshot = heartbeatsBundle.lastAddedHeartbeatDates
    // When
    let removedHeartbeat = heartbeatsBundle.removeHeartbeat(from: date)
    // Then
    XCTAssertNil(removedHeartbeat)

    let heartbeatsBundleString = heartbeatsBundle
      .makeHeartbeatsPayload()
      .headerValue()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatsBundleString,
      """
      {
        "version": 2,
        "heartbeats": []
      }
      """
    )

    XCTAssertEqual(heartbeatsBundle.lastAddedHeartbeatDates, preRemoveCacheSnapshot)
  }

  func testRemovingHeartbeatFromDate_WhenHeartbeatFromDateInBundle_RemovesAndReturnsTheHeartbeat() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 1)
    let heartbeat = Heartbeat(agent: "dummy_agent", date: date, timePeriods: [.daily])
    heartbeatsBundle.append(heartbeat)
    // When
    let removedHeartbeat = heartbeatsBundle.removeHeartbeat(from: date)
    // Then
    XCTAssertEqual(removedHeartbeat, heartbeat)

    let heartbeatsBundleString = heartbeatsBundle
      .makeHeartbeatsPayload()
      .headerValue()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatsBundleString,
      """
      {
        "version": 2,
        "heartbeats": []
      }
      """
    )
  }

  func testRemovingHeartbeatFromDate_WhenHeartbeatFromDateNotInBundle_RemovesNothingAndReturnsNil() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 1)
    let heartbeat = Heartbeat(agent: "dummy_agent", date: date, timePeriods: [.daily])
    heartbeatsBundle.append(heartbeat)
    // When
    let removedHeartbeat = heartbeatsBundle.removeHeartbeat(from: .distantPast)
    // Then
    XCTAssertNil(removedHeartbeat)

    let heartbeatsBundleString = heartbeatsBundle
      .makeHeartbeatsPayload()
      .headerValue()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatsBundleString,
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent",
            "dates": ["2021-11-01"]
          }
        ]
      }
      """
    )
  }

  func testRemovingHeartbeatFromDate_DoesNotAlterOrderingForRemainingHeartbeats() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 3)
    let yesterdayDate = date.addingTimeInterval(-1 * 60 * 60 * 24)
    let heartbeat1 = Heartbeat(agent: "dummy_agent_1", date: .distantPast)
    let heartbeat2 = Heartbeat(agent: "dummy_agent_2", date: yesterdayDate)
    let heartbeat3 = Heartbeat(agent: "dummy_agent_3", date: date)
    heartbeatsBundle.append(heartbeat1) // [heartbeat1, __________, __________]
    heartbeatsBundle.append(heartbeat2) // [heartbeat1, heartbeat1, __________]
    heartbeatsBundle.append(heartbeat3) // [heartbeat1, heartbeat2, heartbeat3]
    // When
    heartbeatsBundle.removeHeartbeat(from: yesterdayDate) // [heartbeat1, heartbeat3, nil]

    // Then
    let heartbeat4 = Heartbeat(agent: "dummy_agent_4", date: date)
    let heartbeat5 = Heartbeat(agent: "dummy_agent_5", date: date)
    heartbeatsBundle.append(heartbeat4) // [heartbeat1, heartbeat3, heartbeat4]
    heartbeatsBundle.append(heartbeat5) // [heartbeat5, heartbeat3, heartbeat4]

    let heartbeatsBundleString = heartbeatsBundle
      .makeHeartbeatsPayload()
      .headerValue()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatsBundleString,
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent_3",
            "dates": ["2021-11-01"]
          },
          {
            "agent": "dummy_agent_4",
            "dates": ["2021-11-01"]
          },
          {
            "agent": "dummy_agent_5",
            "dates": ["2021-11-01"]
          }
        ]
      }
      """
    )
  }

  func testRemovingHeartbeatFromDate_WhenMultipleHeartbeatFromDateExist_RemovesAndReturnsTheLastHeartbeat() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 3)
    let heartbeat1 = Heartbeat(agent: "dummy_agent_1", date: date)
    let heartbeat2 = Heartbeat(agent: "dummy_agent_2", date: date)
    let heartbeat3 = Heartbeat(agent: "dummy_agent_3", date: date)
    heartbeatsBundle.append(heartbeat1) // [heartbeat1, __________, __________]
    heartbeatsBundle.append(heartbeat2) // [heartbeat1, heartbeat2, __________]
    heartbeatsBundle.append(heartbeat3) // [heartbeat1, heartbeat2, heartbeat3]
    // When
    let removed = heartbeatsBundle
      .removeHeartbeat(from: date) // [heartbeat1, heartbeat2, __________]
    // Then
    XCTAssertEqual(removed, heartbeat3)

    let heartbeatsBundleString = heartbeatsBundle
      .makeHeartbeatsPayload()
      .headerValue()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatsBundleString,
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent_1",
            "dates": ["2021-11-01"]
          },
          {
            "agent": "dummy_agent_2",
            "dates": ["2021-11-01"]
          }
        ]
      }
      """
    )
  }

  func testMakePayload_WithMultipleUserAgents() throws {
    // Given
    var heartbeatsBundle = HeartbeatsBundle(capacity: 2)

    // When
    let heartbeat1 = Heartbeat(agent: "dummy_agent_1", date: date)
    heartbeatsBundle.append(heartbeat1)

    let heartbeat2 = Heartbeat(agent: "dummy_agent_2", date: date)
    heartbeatsBundle.append(heartbeat2)

    // Then
    let heartbeatsBundleString = heartbeatsBundle
      .makeHeartbeatsPayload()
      .headerValue()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatsBundleString,
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent_1",
            "dates": ["2021-11-01"]
          },
          {
            "agent": "dummy_agent_2",
            "dates": ["2021-11-01"]
          }
        ]
      }
      """
    )
  }
}
