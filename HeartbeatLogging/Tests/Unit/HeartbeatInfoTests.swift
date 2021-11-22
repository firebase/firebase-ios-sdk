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

class HeartbeatInfoTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)

  func testAppendingHeartbeatUpdatesCache() throws {
    // Given
    var heartbeatInfo = HeartbeatInfo(capacity: 1)
    let heartbeat = Heartbeat(
      agent: "dummy_agent",
      date: date,
      timePeriods: [.daily]
    )

    // When
    heartbeatInfo.append(heartbeat)

    // Then
    let heartbeatInfoString = heartbeatInfo
      .makeHeartbeatsPayload()
      .headerValue()

    try assertEqualPayloadStrings(
      heartbeatInfoString,
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

    XCTAssertEqual(heartbeatInfo.cache, [.daily: heartbeat.date])
  }

  func testAppendingHeartbeat_WhenCapacityIsZero_UpdatesCache() throws {
    // Given
    var heartbeatInfo = HeartbeatInfo(capacity: 0)

    let heartbeat = Heartbeat(
      agent: #function,
      date: Date(),
      timePeriods: [.daily]
    )

    // When
    heartbeatInfo.append(heartbeat)

    // Then
    let heartbeatInfoString = heartbeatInfo
      .makeHeartbeatsPayload()
      .headerValue()

    try assertEqualPayloadStrings(heartbeatInfoString, "")

    XCTAssertEqual(heartbeatInfo.cache, [.daily: heartbeat.date])
  }

  func testAppendingHeartbeat_AtMaxCapacity_RemovesOverwrittenFromCache() throws {
    // Given
    var heartbeatInfo = HeartbeatInfo(capacity: 1)

    let heartbeat1 = Heartbeat(
      agent: "dummy_agent_1",
      date: Date(),
      timePeriods: [.daily]
    )
    heartbeatInfo.append(heartbeat1)

    XCTAssertEqual(
      heartbeatInfo.cache,
      [.daily: heartbeat1.date]
    )

    let heartbeat2 = Heartbeat(
      agent: "dummy_agent_2",
      date: date,
      timePeriods: [.daily]
    )

    // When
    heartbeatInfo.append(heartbeat2)

    // Then
    let heartbeatInfoString = heartbeatInfo
      .makeHeartbeatsPayload()
      .headerValue()

    try assertEqualPayloadStrings(
      heartbeatInfoString,
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

    XCTAssertEqual(
      heartbeatInfo.cache,
      [.daily: heartbeat2.date]
    )
  }

  func testMakePayload_WithMultipleUserAgents() throws {
    // Given
    var heartbeatInfo = HeartbeatInfo(capacity: 2)

    // When
    let heartbeat1 = Heartbeat(agent: "dummy_agent_1", date: date)
    heartbeatInfo.append(heartbeat1)

    let heartbeat2 = Heartbeat(agent: "dummy_agent_2", date: date)
    heartbeatInfo.append(heartbeat2)

    // Then
    let heartbeatInfoString = heartbeatInfo
      .makeHeartbeatsPayload()
      .headerValue()

    try assertEqualPayloadStrings(
      heartbeatInfoString,
      """
      {
        "version": 2,
        "heartbeats": [
          { "agent": "dummy_agent_1", "dates": ["2021-11-01"] },
          { "agent": "dummy_agent_2", "dates": ["2021-11-01"] }
        ]
      }
      """
    )
  }
}
