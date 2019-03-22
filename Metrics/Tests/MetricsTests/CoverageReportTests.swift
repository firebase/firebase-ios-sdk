import XCTest
import MetricsLib

let EXAMPLE_REPORT = "example_report.json"

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
