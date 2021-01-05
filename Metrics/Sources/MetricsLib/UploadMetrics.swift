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

import Foundation

/// A set of SDK targets for which to collect code coverage.
let TARGETS_TO_COLLECT: Set = [
  "Auth_Example_iOS.app",
  "Core_Example_iOS.app",
  "Database_Example_iOS.app",
  "DynamicLinks_Example_iOS.app",
  "InstanceID_Example_iOS.app",
  "Messaging_Example_iOS.app",
  "Storage_Example_iOS.app",
  // TODO(Corrob): Add support for Firestore, Functions, and InAppMessaging.
]

/// Represents a set of metric table updates to upload to the database.
public struct UploadMetrics: Encodable {
  public var tables: [TableUpdate]

  public init(tables: [TableUpdate]) {
    self.tables = tables
  }

  /// Converts the metric table updates to a JSON format this is compatible with the Java uploader.
  public func json() throws -> String {
    let json = try JSONEncoder().encode(self)
    return String(data: json, encoding: .utf8)!
  }
}

/// An update to a metrics table with the new data to uplaod to the database.
public struct TableUpdate: Encodable {
  public var table_name: String
  public var column_names: [String]
  public var replace_measurements: [[String]]

  public init(table_name: String, column_names: [String], replace_measurements: [[String]]) {
    self.table_name = table_name
    self.column_names = column_names
    self.replace_measurements = replace_measurements
  }

  /// Creates a table update for code coverage by parsing a coverage report from XCov.
  public static func createFrom(coverage: CoverageReport, pullRequest: Int,
                                currentTime: String) -> TableUpdate {
    var metrics = [[String]]()
    for target in coverage.targets {
      if TARGETS_TO_COLLECT.contains(target.name) {
        var row = [String]()
        row.append(target.name.components(separatedBy: "_")[0])
        row.append(String(pullRequest))
        row.append(String(target.coverage))
        row.append(currentTime)
        metrics.append(row)
      } else {
        print(
          "WARNING - target \(target.name) is being filtered out from coverage collection. Skipping..."
        )
      }
    }
    let columnNames = ["product_name", "pull_request_id", "coverage_total", "collection_time"]
    return TableUpdate(table_name: "IosCodeCoverage", column_names: columnNames,
                       replace_measurements: metrics)
  }
}
