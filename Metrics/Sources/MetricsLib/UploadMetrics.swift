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

/// A mapping of SDKs to an ID that will represent that SDK in the database.
let TARGET_TO_SDK_INDEX = [
  "Auth_Example_iOS.app": 0.0,
  "Core_Example_iOS.app": 1.0,
  "Database_Example_iOS.app": 2.0,
  "DynamicLinks_Example_iOS.app": 3.0,
  "InstanceID_Example_iOS.app": 4.0,
  "Messaging_Example_iOS.app": 5.0,
  "Storage_Example_iOS.app": 6.0,
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
  public var replace_measurements: [[Double]]

  public init(table_name: String, column_names: [String], replace_measurements: [[Double]]) {
    self.table_name = table_name
    self.column_names = column_names
    self.replace_measurements = replace_measurements
  }

  /// Creates a table update for code coverage by parsing a coverage report from XCov.
  public static func createFrom(coverage: CoverageReport, pullRequest: Int) -> TableUpdate {
    var metrics = [[Double]]()
    for target in coverage.targets {
      let sdkKey = TARGET_TO_SDK_INDEX[target.name]
      if sdkKey == nil {
        print("WARNING - target \(target.name) has no mapping to an SDK id. Skipping...")
      } else {
        var row = [Double]()
        row.append(Double(pullRequest))
        row.append(sdkKey!)
        row.append(target.coverage)
        metrics.append(row)
      }
    }
    let columnNames = ["pull_request_id", "sdk_id", "coverage_percent"]
    return TableUpdate(table_name: "Coverage1", column_names: columnNames, replace_measurements: metrics)
  }
}
