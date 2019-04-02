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

let EXAMPLE_REPORT = "Tests/MetricsTests/example_report.json"

final class CoverageReportTests: XCTestCase {
  func testShouldParseTotalCoverage() throws {
    let report = try CoverageReport.load(path: EXAMPLE_REPORT)
    XCTAssertEqual(report.coverage, 0.5490569575543673)
  }

  func testShouldParseTargets() throws {
    let report = try CoverageReport.load(path: EXAMPLE_REPORT)
    XCTAssertEqual(report.targets.count, 14)
    XCTAssertEqual(report.targets[0].name, "Auth_Example_iOS.app")
    XCTAssertEqual(report.targets[0].coverage, 0.8241201927002532)
    XCTAssertEqual(report.targets[0].files.count, 97)
  }

  func testShouldFailOnMissingFile() throws {
    XCTAssertThrowsError(try CoverageReport.load(path: "IDontExist"))
  }
}
