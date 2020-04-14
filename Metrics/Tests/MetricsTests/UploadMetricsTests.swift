/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import MetricsLib
import XCTest

let PULL_REQUEST = 777
let CURRENT_TIME = "2019-06-21 11:11:11"
let TABLE_NAME = "IosCodeCoverage"

final class UploadMetricsTests: XCTestCase {
  func testShouldCreateTableUpdateFromCoverageReport() {
    let target_one = Target(name: "Auth_Example_iOS.app", coverage: 0.1)
    let target_two = Target(name: "Core_Example_iOS.app", coverage: 0.2)
    let report = CoverageReport(targets: [target_one, target_two], coverage: 0.15)
    let metricsUpdate = TableUpdate
      .createFrom(coverage: report, pullRequest: PULL_REQUEST, currentTime: CURRENT_TIME)
    XCTAssertEqual(metricsUpdate.table_name, TABLE_NAME)
    XCTAssertEqual(metricsUpdate.replace_measurements.count, 2)
    XCTAssertEqual(metricsUpdate.replace_measurements[0],
                   ["Auth", String(PULL_REQUEST), String(target_one.coverage), CURRENT_TIME])
    XCTAssertEqual(metricsUpdate.replace_measurements[1],
                   ["Core", String(PULL_REQUEST), String(target_two.coverage), CURRENT_TIME])
  }

  func testShouldIgnoreUnkownTargets() {
    let target = Target(name: "Unknown_Target", coverage: 0.3)
    let report = CoverageReport(targets: [target], coverage: 0.15)
    let metrics = TableUpdate
      .createFrom(coverage: report, pullRequest: PULL_REQUEST, currentTime: CURRENT_TIME)
    XCTAssertEqual(metrics.table_name, TABLE_NAME)
    XCTAssertEqual(metrics.replace_measurements.count, 0)
  }

  func testShouldConvertToJson() throws {
    let table = TableUpdate(table_name: "name",
                            column_names: ["col"],
                            replace_measurements: [["0"], ["test"]])
    let metrics = UploadMetrics(tables: [table])
    let json = try metrics.json()
    XCTAssertEqual(json,
                   "{\"tables\":[{\"replace_measurements\":[[\"0\"],[\"test\"]],\"column_names\":[\"col\"],\"table_name\":\"name\"}]}")
  }
}
