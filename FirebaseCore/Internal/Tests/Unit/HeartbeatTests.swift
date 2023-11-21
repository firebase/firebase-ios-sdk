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

class TimePeriodTests: XCTestCase {
  override func setUpWithError() throws {
    XCTAssertEqual(TimePeriod.allCases, [.daily])
  }

  func testTimeIntervals() throws {
    TimePeriod.allCases.forEach { period in
      XCTAssertEqual(period.timeInterval, Double(period.rawValue) * 86400)
    }
  }

  func testTimePeriodRawValues() throws {
    let dailyTimePeriod = TimePeriod.daily
    XCTAssertEqual(dailyTimePeriod.rawValue, 1)
  }
}

class HeartbeatTests: XCTestCase {
  var heartbeat: Heartbeat!
  var heartbeatData: Data!

  override func setUpWithError() throws {
    heartbeat = Heartbeat(
      agent: "dummy_agent",
      date: Date(timeIntervalSince1970: 1_635_739_200), // 2021-11-01
      timePeriods: [.daily],
      version: 100
    )
    heartbeatData = try JSONEncoder().encode(heartbeat)
  }

  func testHeartbeatCurrentVersion() throws {
    XCTAssertEqual(Heartbeat(agent: #function, date: Date()).version, 0)
  }

  func testDecodeAndEncode() throws {
    // Given
    let json = """
    {
      "agent": "dummy_agent",
      "date": 657432000,
      "timePeriods": [1],
      "version": 100
    }
    """

    let data = try XCTUnwrap(json.data(using: .utf8))

    // When
    let decodedHeartbeat = try JSONDecoder()
      .decode(Heartbeat.self, from: data)

    let encodedHeartbeat = try JSONEncoder()
      .encode(decodedHeartbeat)

    // Then
    XCTAssertEqual(decodedHeartbeat.agent, heartbeat.agent)
    XCTAssertEqual(decodedHeartbeat.date, heartbeat.date)
    XCTAssertEqual(decodedHeartbeat.timePeriods, heartbeat.timePeriods)
    XCTAssertEqual(decodedHeartbeat.version, heartbeat.version)

    XCTAssertEqual(encodedHeartbeat, heartbeatData)
  }
}
