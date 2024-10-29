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

class HeartbeatControllerTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)

  func testFlush_WhenEmpty_ReturnsEmptyPayload() throws {
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
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
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

  func testLogAndFlushAsync() throws {
    // Given
    let controller = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { self.date }
    )
    let expectation = expectation(description: #function)

    assertHeartbeatControllerFlushesEmptyPayload(controller)

    // When
    controller.log("dummy_agent")
    controller.flushAsync { heartbeatPayload in
      // Then
      do {
        try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
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
        expectation.fulfill()
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
    waitForExpectations(timeout: 1.0)

    assertHeartbeatControllerFlushesEmptyPayload(controller)
  }

  func testLogAtEndOfTimePeriodAndAcceptAtStartOfNextOne() throws {
    // Given
    let testDate = AdjustableDate(date: date)

    let controller = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { testDate.date }
    )

    assertHeartbeatControllerFlushesEmptyPayload(controller)

    // When
    // - Clock time 2021-11-01 @ 00:00:00 (EST)
    controller.log("dummy_agent")

    // - Advance to 2021-11-01 @ 23:59:59 (EST)
    testDate.date.addTimeInterval(60 * 60 * 24 - 1)

    controller.log("dummy_agent")

    // - Advance to 2021-11-02 @ 00:00:00 (EST)
    testDate.date.addTimeInterval(1)

    controller.log("dummy_agent")

    // Then
    let heartbeatPayload = controller.flush()

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      heartbeatPayload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent",
            "dates": [
              "2021-11-01",
              "2021-11-02"
            ]
          }
        ]
      }
      """
    )

    assertHeartbeatControllerFlushesEmptyPayload(controller)
  }

  func testDoNotLogMoreThanOnceInACalendarDay() throws {
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

    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
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

  func testDoNotLogMoreThanOnceInACalendarDay_AfterFlushing() throws {
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
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
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
      ).date // 2021-11-01 @ 11 PM (EST)
    )
    let heartbeatController = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { newYorkDate }
    )

    // When
    heartbeatController.log("dummy_agent")
    let payload = heartbeatController.flush()

    // Then
    // Note below how the date was interpreted as UTC - 2021-11-02.
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
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

  func testDoNotLogMoreThanOnceInACalendarDay_WhenTravelingAcrossTimeZones() throws {
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

    let testDate = AdjustableDate(date: newYorkDate)

    let heartbeatController = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { testDate.date }
    )

    // When
    heartbeatController.log("dummy_agent")

    // Device travels from NYC to Tokyo.
    testDate.date = tokyoDate

    heartbeatController.log("dummy_agent")

    // Then
    let payload = heartbeatController.flush()
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version" : 2,
        "heartbeats" : [
          {
            "agent" : "dummy_agent",
            "dates" : [
              "2021-11-02"
            ]
          }
        ]
      }
      """
    )
  }

  func testLoggingDependsOnDateNotUserAgent() throws {
    // Given
    let testDate = AdjustableDate(date: date)
    let heartbeatController = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { testDate.date }
    )

    // When
    // - Day 1
    heartbeatController.log("dummy_agent")

    // - Day 2
    testDate.date.addTimeInterval(60 * 60 * 24)
    heartbeatController.log("some_other_agent")

    // - Day 3
    testDate.date.addTimeInterval(60 * 60 * 24)
    heartbeatController.log("dummy_agent")

    // Then
    let payload = heartbeatController.flush()
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent",
            "dates": [
              "2021-11-01",
              "2021-11-03"
            ]
          },
          {
            "agent": "some_other_agent",
            "dates": [
              "2021-11-02"
            ]
          }
        ]
      }
      """
    )
  }

  func testFlushHeartbeatFromToday_WhenTodayHasAHeartbeat_ReturnsPayloadWithOnlyTodaysHeartbeat() throws {
    // Given
    let yesterdaysDate = date.addingTimeInterval(-1 * 60 * 60 * 24)
    let todaysDate = date
    let tomorrowsDate = date.addingTimeInterval(60 * 60 * 24)

    let testDate = AdjustableDate(date: yesterdaysDate)

    let heartbeatController = HeartbeatController(
      storage: HeartbeatStorageFake(),
      dateProvider: { testDate.date }
    )

    // When
    heartbeatController.log("yesterdays_dummy_agent")
    testDate.date = todaysDate
    heartbeatController.log("todays_dummy_agent")
    testDate.date = tomorrowsDate
    heartbeatController.log("tomorrows_dummy_agent")
    testDate.date = todaysDate

    // Then
    let payload = heartbeatController.flushHeartbeatFromToday()
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "todays_dummy_agent",
            "dates": ["2021-11-01"]
          }
        ]
      }
      """
    )

    let remainingPayload = heartbeatController.flush()
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      remainingPayload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "tomorrows_dummy_agent",
            "dates": ["2021-11-02"]
          },
          {
            "agent": "yesterdays_dummy_agent",
            "dates": ["2021-10-31"]
          }
        ]
      }
      """
    )

    assertHeartbeatControllerFlushesEmptyPayload(heartbeatController)
  }

  func testFlushHeartbeatFromToday_WhenTodayDoesNotHaveAHeartbeat_ReturnsEmptyPayload() throws {
    // Given
    let heartbeatController = HeartbeatController(id: #function, dateProvider: { self.date })
    // When
    heartbeatController.flushHeartbeatFromToday()
    // Then
    assertHeartbeatControllerFlushesEmptyPayload(heartbeatController)
  }
}

// MARK: - Fakes

private final class HeartbeatStorageFake: HeartbeatStorageProtocol, @unchecked Sendable {
  // The unchecked Sendable conformance is used to prevent warnings for the below var, which
  // violates the class's Sendable conformance. Ignoring this violation should be okay for
  // testing purposes.
  private var heartbeatsBundle: HeartbeatsBundle?

  func readAndWriteSync(using transform: (HeartbeatsBundle?) -> HeartbeatsBundle?) {
    heartbeatsBundle = transform(heartbeatsBundle)
  }

  func readAndWriteAsync(using transform: @escaping (HeartbeatsBundle?) -> HeartbeatsBundle?) {
    heartbeatsBundle = transform(heartbeatsBundle)
  }

  func getAndSet(using transform: (HeartbeatsBundle?) -> HeartbeatsBundle?) throws
    -> HeartbeatsBundle? {
    let oldHeartbeatsBundle = heartbeatsBundle
    heartbeatsBundle = transform(heartbeatsBundle)
    return oldHeartbeatsBundle
  }

  func getAndSetAsync(using transform: @escaping (FirebaseCoreInternal.HeartbeatsBundle?)
    -> FirebaseCoreInternal.HeartbeatsBundle?,
    completion: @escaping (Result<
      FirebaseCoreInternal.HeartbeatsBundle?,
      any Error
    >) -> Void) {
    let oldHeartbeatsBundle = heartbeatsBundle
    heartbeatsBundle = transform(heartbeatsBundle)
    completion(.success(oldHeartbeatsBundle))
  }
}
