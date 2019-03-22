import Foundation

let TARGET_TO_SDK_INDEX = ["Auth_Example_iOS.app" : 0.0,
  "Core_Example_iOS.app" : 1.0,
  "Database_Example_iOS.app" : 2.0,
  "DynamicLinks_Example_iOS.app" : 3.0,
  "InstanceID_Example_iOS.app" : 4.0,
  "Messaging_Example_iOS.app" : 5.0,
  "Storage_Example_iOS.app" : 6.0]

public struct UploadMetrics : Encodable {
  public var tables: [Table]

  public init(tables: [Table]) {
    self.tables = tables
  }

  public func json() throws -> String {
    let json = try JSONEncoder().encode(self)
    return String(data: json, encoding: .utf8)!
  }
}

public struct Table : Encodable {
  public var table_name: String
  public var column_names: [String]
  public var replace_measurements: [[Double]]

  public init(table_name: String, column_names: [String], replace_measurements: [[Double]]) {
    self.table_name = table_name
    self.column_names = column_names
    self.replace_measurements = replace_measurements
  }

  public static func createFrom(coverage: CoverageReport, pullRequest: Int) -> Table {
    var metrics = [[Double]]()
    for target in coverage.targets {
      let sdkKey = TARGET_TO_SDK_INDEX[target.name]
      if (sdkKey != nil) {
        var row = [Double]()
        row.append(Double(pullRequest))
        row.append(sdkKey!)
        row.append(target.coverage)
        metrics.append(row)
      }
    }
    let columnNames = ["pull_request_id", "sdk_id", "coverage_percent"]
    return Table(table_name: "Coverage1", column_names: columnNames, replace_measurements:metrics)
  }
}

