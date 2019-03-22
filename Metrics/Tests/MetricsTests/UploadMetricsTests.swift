import XCTest
import MetricsLib

let PULL_REQUEST = 777

final class UploadMetricsTests: XCTestCase {
    func testShouldCreateTableFromCoverageReport() {
      let target_one = Target(name: "Auth_Example_iOS.app", coverage:0.1)
      let target_two = Target(name: "Core_Example_iOS.app", coverage:0.2)
      let report = CoverageReport(targets:[target_one, target_two], coverage:0.15)
      let metrics = Table.createFrom(coverage:report, pullRequest:PULL_REQUEST)
      XCTAssertEqual(metrics.table_name, "Coverage1")
      XCTAssertEqual(metrics.replace_measurements.count, 2)
      XCTAssertEqual(metrics.replace_measurements[0], [Double(PULL_REQUEST), 0, target_one.coverage])
      XCTAssertEqual(metrics.replace_measurements[1], [Double(PULL_REQUEST), 1, target_two.coverage])
    }

    func testShouldIgnoreUnkownTargets() {
      let target = Target(name: "Unknown_Target", coverage:0.3)
      let report = CoverageReport(targets:[target], coverage:0.15)
      let metrics = Table.createFrom(coverage:report, pullRequest:PULL_REQUEST)
      XCTAssertEqual(metrics.table_name, "Coverage1")
      XCTAssertEqual(metrics.replace_measurements.count, 0)
    }

    func testShouldConvertToJson() throws {
      let table = Table(table_name: "name", column_names: ["col"], replace_measurements: [[0], [2]])
      let metrics = UploadMetrics(tables: [table])
      let json = try metrics.json()
      XCTAssertEqual(json, "{\"tables\":[{\"replace_measurements\":[[0],[2]],\"column_names\":[\"col\"],\"table_name\":\"name\"}]}")
    }
}
