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

class HeartbeatLoggingIntegrationTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)

  override func setUpWithError() throws {
    try HeartbeatLoggingTestUtils.removeUnderlyingHeartbeatStorageContainers()
  }

  override func tearDownWithError() throws {
    try HeartbeatLoggingTestUtils.removeUnderlyingHeartbeatStorageContainers()
  }

  /// This test may flake if it is executed during the transition from one day to the next.
  func testLogAndFlush() throws {
    // Given
    let heartbeatController = HeartbeatController(id: #function)
    let expectedDate = HeartbeatsPayload.dateFormatter.string(from: Date())
    // When
    heartbeatController.log("dummy_agent")
    let payload = heartbeatController.flush()
    // Then
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent",
            "dates": ["\(expectedDate)"]
          }
        ]
      }
      """
    )
  }

  /// This test may flake if it is executed during the transition from one day to the next.
  func testDoNotLogMoreThanOnceInACalendarDay() throws {
    // Given
    let heartbeatController = HeartbeatController(id: #function)
    heartbeatController.log("dummy_agent")
    heartbeatController.flush()
    // When
    heartbeatController.log("dummy_agent")
    // Then
    assertHeartbeatControllerFlushesEmptyPayload(heartbeatController)
  }

  /// This test may flake if it is executed during the transition from one day to the next.
  func testFlushHeartbeatFromToday() throws {
    // Given
    let heartbeatController = HeartbeatController(id: #function)
    let expectedDate = HeartbeatsPayload.dateFormatter.string(from: Date())
    // When
    heartbeatController.log("dummy_agent")
    let payload = heartbeatController.flushHeartbeatFromToday()
    // Then
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent",
            "dates": ["\(expectedDate)"]
          }
        ]
      }
      """
    )
  }

  func testMultipleControllersWithTheSameIDUseTheSameStorageInstance() throws {
    // Given
    let heartbeatController1 = HeartbeatController(id: #function, dateProvider: { self.date })
    let heartbeatController2 = HeartbeatController(id: #function, dateProvider: { self.date })
    // When
    heartbeatController1.log("dummy_agent")
    // Then
    let payload = heartbeatController2.flush()
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
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
    assertHeartbeatControllerFlushesEmptyPayload(heartbeatController1)
  }

  func testLogAndFlushConcurrencyStressTest() throws {
    // Given
    let heartbeatController = HeartbeatController(id: #function, dateProvider: { self.date })

    // When
    DispatchQueue.concurrentPerform(iterations: 100) { _ in
      heartbeatController.log("dummy_agent")
    }

    var payloads: [HeartbeatsPayload] = []

    DispatchQueue.concurrentPerform(iterations: 100) { _ in
      let payload = heartbeatController.flush()
      payloads.append(payload)
    }

    // Then
    let nonEmptyPayloads = payloads.filter { payload in
      // Filter out non-empty payloads.
      !payload.userAgentPayloads.isEmpty
    }

    XCTAssertEqual(nonEmptyPayloads.count, 1)

    let payload = try XCTUnwrap(nonEmptyPayloads.first)
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
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

  func testLogAndFlushHeartbeatFromTodayConcurrencyStressTest() throws {
    // Given
    let heartbeatController = HeartbeatController(id: #function, dateProvider: { self.date })

    // When
    DispatchQueue.concurrentPerform(iterations: 100) { _ in
      heartbeatController.log("dummy_agent")
    }

    var payloads: [HeartbeatsPayload] = []

    DispatchQueue.concurrentPerform(iterations: 100) { _ in
      let payload = heartbeatController.flushHeartbeatFromToday()
      payloads.append(payload)
    }

    // Then
    let nonEmptyPayloads = payloads.filter { payload in
      // Filter out non-empty payloads.
      !payload.userAgentPayloads.isEmpty
    }

    XCTAssertEqual(nonEmptyPayloads.count, 1)

    let payload = try XCTUnwrap(nonEmptyPayloads.first)
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent",
            "dates": ["2021-11-01"],
          }
        ]
      }
      """
    )

    assertHeartbeatControllerFlushesEmptyPayload(heartbeatController)
  }

  func testLogRepeatedly_WithoutFlushing_LimitsOnWrite() throws {
    // Given
    var testdate = date
    let heartbeatController = HeartbeatController(id: #function, dateProvider: { testdate })

    // When
    // Iterate over 35 days and log a heartbeat each day.
    // - 30: The heartbeat logging library can store a max of 30 heartbeats. See
    //   `HeartbeatController`'s `heartbeatsStorageCapacity` property.
    // - 5: Because of the above limit, expect 5 heartbeats to be overwritten.
    for day in 1 ... 35 {
      // A different user agent is logged based on the current iteration. There
      // is no particular reason for when each user agent is used– the goal is
      // to achieve a payload with multiple user agent groupings.
      if day < 5 {
        heartbeatController.log("dummy_agent_1")
      } else if day < 13 {
        heartbeatController.log("dummy_agent_2")
      } else {
        heartbeatController.log("dummy_agent_3")
      }

      testdate.addTimeInterval(60 * 60 * 24) // Advance the test date by 1 day.
    }

    // Then
    let payload = heartbeatController.flush()
    // The first 5 days of heartbeats (associated with `dummy_agent_1`) should
    // have been overwritten.
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "dummy_agent_2",
            "dates": [
              "2021-11-06",
              "2021-11-07",
              "2021-11-08",
              "2021-11-09",
              "2021-11-10",
              "2021-11-11",
              "2021-11-12"
            ]
          },
          {
            "agent": "dummy_agent_3",
            "dates": [
              "2021-12-01",
              "2021-12-02",
              "2021-12-03",
              "2021-12-04",
              "2021-12-05",
              "2021-11-13",
              "2021-11-14",
              "2021-11-15",
              "2021-11-16",
              "2021-11-17",
              "2021-11-18",
              "2021-11-19",
              "2021-11-20",
              "2021-11-21",
              "2021-11-22",
              "2021-11-23",
              "2021-11-24",
              "2021-11-25",
              "2021-11-26",
              "2021-11-27",
              "2021-11-28",
              "2021-11-29",
              "2021-11-30"
            ]
          }
        ]
      }
      """
    )
  }

  func testLogAndFlush_AfterUnderlyingStorageIsDeleted_CreatesNewStorage() throws {
    // Given
    let heartbeatController = HeartbeatController(id: #function, dateProvider: { self.date })
    heartbeatController.log("dummy_agent")
    _ = XCTWaiter.wait(for: [expectation(description: "Wait for async log.")], timeout: 0.1)

    // When
    XCTAssertNoThrow(try HeartbeatLoggingTestUtils.removeUnderlyingHeartbeatStorageContainers())

    // Then
    // 1. Assert controller flushes empty payload.
    assertHeartbeatControllerFlushesEmptyPayload(heartbeatController)
    // 2. Assert controller can log and flush non-empty payload.
    heartbeatController.log("dummy_agent")
    let payload = heartbeatController.flush()
    try HeartbeatLoggingTestUtils.assertEqualPayloadStrings(
      payload.headerValue(),
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

  func testInitializingControllerDoesNotModifyUnderlyingStorage() throws {
    // Given
    let id = #function
    // When
    _ = HeartbeatController(id: id)
    // Then
    #if os(tvOS)
      XCTAssertNil(
        UserDefaults(suiteName: HeartbeatLoggingTestUtils.Constants.heartbeatUserDefaultsSuiteName)?
          .object(forKey: "heartbeats-\(id)"),
        "Specified user defaults suite should be empty."
      )
    #else
      let heartbeatsDirectoryURL = FileManager.default
        .applicationSupportDirectory
        .appendingPathComponent(
          HeartbeatLoggingTestUtils.Constants.heartbeatFileStorageDirectoryPath,
          isDirectory: true
        )
      XCTAssertFalse(
        FileManager.default.fileExists(atPath: heartbeatsDirectoryURL.path),
        "Specified file path should not exist."
      )
    #endif
  }

  func testUnderlyingStorageLocationForRegressions() throws {
    // Given
    let id = #function
    let controller = HeartbeatController(id: id)
    // When
    controller.log("dummy_agent")
    _ = XCTWaiter.wait(for: [expectation(description: "Wait for async log.")], timeout: 0.1)
    // Then
    #if os(tvOS)
      XCTAssertNotNil(
        UserDefaults(suiteName: HeartbeatLoggingTestUtils.Constants.heartbeatUserDefaultsSuiteName)?
          .object(forKey: "heartbeats-\(id)"),
        "Data should not be nil."
      )
    #else
      let heartbeatsFileURL = FileManager.default
        .applicationSupportDirectory
        .appendingPathComponent(
          HeartbeatLoggingTestUtils.Constants.heartbeatFileStorageDirectoryPath,
          isDirectory: true
        )
        .appendingPathComponent(
          "heartbeats-\(id)", isDirectory: false
        )
      XCTAssertNotNil(try Data(contentsOf: heartbeatsFileURL), "Data should not be nil.")
    #endif
  }

  #if !os(tvOS)
    // Do not run on tvOS because tvOS uses UserDefaults to store heartbeats.
    func testControllerCreatesHeartbeatStorageWithSanitizedFileName() throws {
      // Given
      let appID = "1:123456789000:ios:abcdefghijklmnop"
      let sanitizedAppID = appID.replacingOccurrences(of: ":", with: "_")
      let controller = HeartbeatController(id: appID)
      // When
      // - Trigger the controller to write to the file system.
      controller.log("dummy_agent")
      _ = XCTWaiter.wait(for: [expectation(description: "Wait for async log.")], timeout: 0.1)
      // Then
      let heartbeatsDirectoryURL = FileManager.default
        .applicationSupportDirectory
        .appendingPathComponent(
          HeartbeatLoggingTestUtils.Constants.heartbeatFileStorageDirectoryPath,
          isDirectory: true
        )

      let directoryContents = try FileManager.default
        .contentsOfDirectory(atPath: heartbeatsDirectoryURL.path)

      XCTAssertEqual(directoryContents, ["heartbeats-\(sanitizedAppID)"])
    }
  #endif // !os(tvOS)
}
