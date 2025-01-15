// Copyright 2025 Google LLC
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

import FirebaseABTesting
@testable import FirebaseRemoteConfig
import XCTest

private var experimentStartTimeDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  formatter.locale = Locale(identifier: "en_US_POSIX")
  return formatter
}()

class ConfigExperimentOrigTests: XCTestCase {
  private var dbManager: ConfigDBManagerFake!
  private var experimentController: ExperimentControllerFake!
  var configExperiment: ConfigExperiment!
  let testDate = Date(timeIntervalSinceReferenceDate: 12_345_678) // Use fixed time
  let testTimeInterval: TimeInterval = 12_345_678

  override func setUp() {
    super.setUp()
    dbManager = ConfigDBManagerFake()
    experimentController = ExperimentControllerFake()
    configExperiment = ConfigExperiment(
      DBManager: dbManager,
      experimentController: experimentController
    )
  }

  func testLoadExperimentFromTable() {
    // Setup mock data in the fake
    let payload = ["experimentId": "testID"] // Data doesn't matter in this test
    let payloadData = try! JSONSerialization.data(withJSONObject: payload)
    dbManager.mockExperimentTable = [
      ConfigConstants.experimentTableKeyPayload: [payloadData],
      ConfigConstants.experimentTableKeyMetadata: ["someKey": "someValue"],
      ConfigConstants.experimentTableKeyActivePayload: [payloadData],
    ]

    // Initializer will load experiment from table.
    let configExperiment = ConfigExperiment(
      DBManager: dbManager,
      experimentController: ExperimentController.sharedInstance()
    )

    XCTAssertEqual(configExperiment.experimentPayloads.count, 1)
    XCTAssertFalse(configExperiment.experimentMetadata.isEmpty)
    XCTAssertEqual(configExperiment.activeExperimentPayloads.count, 1)
  }

  func testUpdateExperiment() throws {
    let payload1 = ["experimentId": "exp1"]
    let payload2 = ["experimentId": "exp2"]
    let payload3 = ["experimentId": "exp3"]
    let originalPayloads = [payload1, payload2, payload3]

    configExperiment.updateExperiments(withResponse: originalPayloads)

    XCTAssertEqual(configExperiment.experimentPayloads.count, originalPayloads.count)

    let decodedExperimentPayloads = try configExperiment.experimentPayloads.compactMap {
      try JSONSerialization.jsonObject(with: $0) as? [String: String]
    }

    XCTAssertEqual(decodedExperimentPayloads, originalPayloads)
  }

  func testUpdateLastExperimentStartTime() {
    configExperiment.updateExperimentStartTime()
    XCTAssertEqual(
      configExperiment.experimentMetadata["last_experiment_start_time"] as? TimeInterval,
      0
    )

    let payload = ["experimentStartTime": experimentStartTimeDateFormatter.string(from: testDate)]
    configExperiment.updateExperiments(withResponse: [payload])
    configExperiment.updateExperimentStartTime()

    XCTAssertEqual(
      configExperiment.experimentMetadata["last_experiment_start_time"] as? TimeInterval,
      testTimeInterval
    )
  }

  func testMultipleUpdatesToLastExperimentStartTime() {
    configExperiment.updateExperimentStartTime()
    XCTAssertEqual(
      configExperiment.experimentMetadata["last_experiment_start_time"] as? TimeInterval,
      0
    )

    let payload1 = ["experimentStartTime": experimentStartTimeDateFormatter.string(from: testDate)]
    configExperiment.updateExperiments(withResponse: [payload1])
    configExperiment.updateExperimentStartTime()

    XCTAssertEqual(
      configExperiment.experimentMetadata["last_experiment_start_time"] as? TimeInterval,
      testTimeInterval
    )

    // Update start time again.
    let timeTimeInterval = 2000 as TimeInterval
    let payload2 = [
      "experimentStartTime": experimentStartTimeDateFormatter
        .string(from: Date(timeIntervalSinceReferenceDate: timeTimeInterval)),
    ]
    configExperiment.updateExperiments(withResponse: [payload2])
    configExperiment.updateExperimentStartTime()

    XCTAssertEqual(
      configExperiment.experimentMetadata["last_experiment_start_time"] as? TimeInterval,
      timeTimeInterval
    )
  }

  func testUpdateLastExperimentStartTimeInThePast() {
    let futureDate = Date.distantFuture
    let futurePayload =
      ["experimentStartTime": experimentStartTimeDateFormatter.string(from: futureDate)]

    configExperiment.updateExperiments(withResponse: [futurePayload])
    configExperiment.updateExperimentStartTime()

    XCTAssertEqual(
      configExperiment.experimentMetadata["last_experiment_start_time"] as? TimeInterval,
      futureDate.timeIntervalSinceReferenceDate
    )

    let pastDate = Date.distantPast
    let pastPayload =
      ["experimentStartTime": experimentStartTimeDateFormatter.string(from: pastDate)]
    configExperiment.updateExperiments(withResponse: [pastPayload])
    configExperiment.updateExperimentStartTime()

    XCTAssertEqual(
      configExperiment.experimentMetadata["last_experiment_start_time"] as? TimeInterval,
      pastDate.timeIntervalSinceReferenceDate
    )
  }

  func testUpdateLastExperimentStartTimeInTheFuture() {
    let futureDate = Date.distantFuture
    let payload = ["experimentStartTime": experimentStartTimeDateFormatter.string(from: futureDate)]
    configExperiment.updateExperiments(withResponse: [payload])
    configExperiment.updateExperimentStartTime()

    XCTAssertEqual(
      configExperiment.experimentMetadata["last_experiment_start_time"] as? TimeInterval,
      futureDate.timeIntervalSinceReferenceDate
    )
  }

  // TODO: This proves harder to test in Swift than the ObjC version of the API.
  func SKIPtestUpdateExperiments() throws {
    let mockPayload = ["experimentId": experimentStartTimeDateFormatter.string(from: testDate)]
    let mockPayloadData = try JSONSerialization.data(withJSONObject: mockPayload)
    configExperiment.updateExperiments(withResponse: [mockPayload])
    configExperiment.updateExperimentStartTime()

    let updateExpecation = expectation(description: #function)

    configExperiment.updateExperiments { error in
      XCTAssertNil(error)
      XCTAssertEqual(
        self.configExperiment.experimentMetadata["last_experiment_start_time"] as? TimeInterval,
        self.testTimeInterval
      )
      //  OCMVerify([experiment updateActiveExperimentsInDB]);
      XCTAssertEqual(self.configExperiment.activeExperimentPayloads, [mockPayloadData])
      updateExpecation.fulfill()
    }
    wait(for: [updateExpecation], timeout: 0.5)
  }

  private func payloadData(from fileName: String,
                           withExtension ext: String = "txt") throws -> Data {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: Self.self)
    #endif
    let path = try XCTUnwrap(bundle.path(forResource: fileName, ofType: ext))
    let data = try XCTUnwrap(String(contentsOfFile: path).data(using: .utf8))
    return try XCTUnwrap(JSONSerialization
      .data(withJSONObject: JSONSerialization.jsonObject(with: data)))
  }
}

// MARK: - Testing Fakes

private class ConfigDBManagerFake: ConfigDBManager {
  var mockExperimentTable: [String: Any] = [:]

  override func loadExperiment(completionHandler handler: (
    (Bool, [String: any Sendable]?) -> Void
  )? = nil) {
    handler?(true, mockExperimentTable)
  }

  override func insertExperimentTable(withKey key: String,
                                      value serializedValue: Data,
                                      completionHandler handler: (
                                        (Bool, [String: AnyHashable]?) -> Void
                                      )? = nil) {
    mockExperimentTable[key] = serializedValue
    handler?(true, nil)
  }

  override func deleteExperimentTable(forKey key: String) {
    mockExperimentTable.removeValue(forKey: key)
  }
}

private class ExperimentControllerFake: ExperimentController {
  override func latestExperimentStartTimestampBetweenTimestamp(_ timestamp: TimeInterval,
                                                               andPayloads payloads: [Data])
    -> TimeInterval {
    if let first = payloads.first {
      if let json = try? JSONSerialization.jsonObject(with: first) as? [String: String],
         let dateString = json["experimentStartTime"],
         let date = experimentStartTimeDateFormatter.date(from: dateString) {
        return date.timeIntervalSinceReferenceDate
      }
    }
    return 0
  }

  override func updateExperiments(withServiceOrigin origin: String,
                                  events: LifecycleEvents,
                                  policy: ABTExperimentPayloadExperimentOverflowPolicy,
                                  lastStartTime: TimeInterval,
                                  payloads: [Data],
                                  completionHandler: (((any Error)?) -> Void)? = nil) {
    completionHandler?(nil)
  }
}
