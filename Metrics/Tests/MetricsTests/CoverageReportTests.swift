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

let EXAMPLE_REPORT = "Tests/MetricsTests/new_report.json"

final class CoverageReportTests: XCTestCase {
  func testShouldParseTotalCoverage() throws {
    let report = try CoverageReport.load(path: EXAMPLE_REPORT)
    XCTAssertEqual(report.lineCoverage, 0.6008475906451106)
  }

  func testShouldParseTargets() throws {
    let report = try CoverageReport.load(path: EXAMPLE_REPORT)
    XCTAssertEqual(report.targets.count, 3)
    XCTAssertEqual(report.targets[0].name, "leveldb.framework")
    XCTAssertEqual(report.targets[0].lineCoverage, 0.5040833234702332)
    XCTAssertEqual(report.targets[0].files.count, 73)
  }

  func testShouldFailOnMissingFile() throws {
    XCTAssertThrowsError(try CoverageReport.load(path: "IDontExist"))
  }
}
