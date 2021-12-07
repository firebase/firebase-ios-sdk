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

class HeartbeatControllerTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)

  func testFlushWhenEmpty() throws {
    // Given
    let controller = HeartbeatController(storage: HeartbeatStorageFake())
    // Then
    assertHeartbeatControllerFlushesEmptyPayload(controller)
  }

  func testLogAndFlush() throws {
    // Given
    let controller = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { self.date }
    )

    assertHeartbeatControllerFlushesEmptyPayload(controller)

    // When
    controller.log("dummy_agent")
    let heartbeatPayload = controller.flush()

    // Then
    try assertEqualPayloadStrings(
      heartbeatPayload.headerValue(),
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

    assertHeartbeatControllerFlushesEmptyPayload(controller)
  }

  func testLoggingDifferentAgentsInSameTimePeriodOnlyStoresTheFirst() throws {
    // Given
    let controller = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { self.date }
    )

    assertHeartbeatControllerFlushesEmptyPayload(controller)

    // When
    controller.log("dummy_agent")
    controller.log("some_other_dummy_agent")
    let heartbeatPayload = controller.flush()

    // Then
    try assertEqualPayloadStrings(
      heartbeatPayload.headerValue(),
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

    assertHeartbeatControllerFlushesEmptyPayload(controller)
  }

  func testLogAtEndOfTimePeriodAndAcceptAtStartOfNextOne() throws {
    // Given
    var testDate = date

    let controller = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { testDate }
    )

    assertHeartbeatControllerFlushesEmptyPayload(controller)

    // When
    // - Clock time 2021-11-01 @ 00:00:00 (EST)
    controller.log("dummy_agent")

    // - Advance to 2021-11-01 @ 23:59:59 (EST)
    testDate.addTimeInterval(60 * 60 * 24 - 1)

    controller.log("dummy_agent")

    // - Advance to 2021-11-02 @ 00:00:00 (EST)
    testDate.addTimeInterval(1)

    controller.log("dummy_agent")

    // Then
    let heartbeatPayload = controller.flush()

    try assertEqualPayloadStrings(
      heartbeatPayload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent",
            "dates": ["2021-11-01", "2021-11-02"]
          }
        ]
      }
      """
    )

    assertHeartbeatControllerFlushesEmptyPayload(controller)
  }

  func testDoNotLogDuplicate() throws {
    // Given
    let controller = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { self.date }
    )

    // When
    controller.log("dummy_agent")
    controller.log("dummy_agent")

    // Then
    let heartbeatPayload = controller.flush()

    try assertEqualPayloadStrings(
      heartbeatPayload.headerValue(),
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

  func testDoNotLogDuplicateAfterFlushing() throws {
    // Given
    let controller = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { self.date }
    )

    // When
    controller.log("dummy_agent")
    let heartbeatPayload = controller.flush()
    controller.log("dummy_agent")

    // Then
    try assertEqualPayloadStrings(
      heartbeatPayload.headerValue(),
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

    // Below assertion asserts that duplicate was not logged.
    assertHeartbeatControllerFlushesEmptyPayload(controller)
  }

  func testHeartbeatDatesAreStandardizedForUTC() throws {
    // Given
    let newYorkDate = try XCTUnwrap(
      DateComponents(
        calendar: .current,
        timeZone: TimeZone(identifier: "America/New_York"),
        year: 2021,
        month: 11,
        day: 01,
        hour: 23
      ).date // 2021-11-01 @ 11 PM (New York time zone)
    )
    let heartbeatController = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { newYorkDate }
    )
    // When
    heartbeatController.log("dummy_agent")
    let payload = heartbeatController.flush()
    // Then
    // Note below how the date was intepreted as UTC - 2021-11-02.
    try assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent",
            "dates": ["2021-11-02"]
          }
        ]
      }
      """
    )
  }

  func testHeartbeatsAreLoggedAcrossTimeZones() throws {
    // Given
    let newYorkDate = try XCTUnwrap(
      DateComponents(
        calendar: .current,
        timeZone: TimeZone(identifier: "America/New_York"),
        year: 2021,
        month: 11,
        day: 01,
        hour: 23
      ).date // 2021-11-01 @ 11 PM (New York time zone)
    )

    let tokyoDate = try XCTUnwrap(
      DateComponents(
        calendar: .current,
        timeZone: TimeZone(identifier: "Asia/Tokyo"),
        year: 2021,
        month: 11,
        day: 02,
        hour: 23
      ).date // 2021-11-02 @ 11 PM (Tokyo time zone)
    )

    var testDate = newYorkDate

    let heartbeatController = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { testDate }
    )

    // When
    heartbeatController.log("dummy_agent")
    heartbeatController.flush()

    testDate = tokyoDate
    heartbeatController.log("dummy_agent")
    // Then
    assertHeartbeatControllerFlushesEmptyPayload(heartbeatController)
  }

  func testLoggingDependsOnDateNotUserAgent() throws {
    // Given
    var testDate = date
    let heartbeatController = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { testDate }
    )

    // When
    // - Day 1
    heartbeatController.log("dummy_agent_1")

    // - Day 2
    testDate.addTimeInterval(60 * 60 * 24)
    heartbeatController.log("dummy_agent_2")

    // - Day 3
    testDate.addTimeInterval(60 * 60 * 24)
    heartbeatController.log("dummy_agent_1")

    // Then
    let payload = heartbeatController.flush()
    try assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent_1",
            "dates": [
              "2021-11-01",
              "2021-11-03"
            ]
          },
          {
            "agent": "dummy_agent_2",
            "dates": [
              "2021-11-02"
            ]
          }
        ]
      }
      """
    )
  }
}

// MARK: - Fakes

extension HeartbeatControllerTests {
  class HeartbeatStorageFake: HeartbeatStorageProtocol {
    private var heartbeatInfo: HeartbeatInfo?

    func readAndWriteAsync(using transform: @escaping (HeartbeatInfo?) -> HeartbeatInfo?) {
      heartbeatInfo = transform(heartbeatInfo)
    }

    func getAndSet(using transform: (HeartbeatInfo?) -> HeartbeatInfo?) throws
      -> HeartbeatInfo? {
      let oldHeartbeatInfo = heartbeatInfo
      heartbeatInfo = transform(heartbeatInfo)
      return oldHeartbeatInfo
    }
  }
}

func assertEqualPayloadStrings(_ encoded: String, _ literal: String) throws {
  let encodedData = try XCTUnwrap(Data(base64Encoded: encoded))
  let literalData = try XCTUnwrap(literal.data(using: .utf8))

  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .formatted(HeartbeatsPayload.dateFormatter)

  let payloadFromEncoded = try? decoder.decode(HeartbeatsPayload.self, from: encodedData)

  let payloadFromLiteral = try? decoder.decode(HeartbeatsPayload.self, from: literalData)

  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .formatted(HeartbeatsPayload.dateFormatter)
  encoder.outputFormatting = .prettyPrinted

  let payloadDataFromEncoded = try XCTUnwrap(encoder.encode(payloadFromEncoded))
  let payloadDataFromLiteral = try XCTUnwrap(encoder.encode(payloadFromLiteral))

  XCTAssertEqual(
    payloadFromEncoded,
    payloadFromLiteral,
    """
    Mismatched payloads!

    Payload 1:
    \(String(data: payloadDataFromEncoded, encoding: .utf8) ?? "")

    Payload 2:
    \(String(data: payloadDataFromLiteral, encoding: .utf8) ?? "")

    """
  )
}

func assertHeartbeatControllerFlushesEmptyPayload(_ controller: HeartbeatController) {
  XCTAssertEqual(controller.flush().headerValue(), "")
}
