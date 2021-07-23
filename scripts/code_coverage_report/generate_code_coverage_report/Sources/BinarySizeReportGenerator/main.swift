/*
 * Copyright 2021 Google LLC
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

import ArgumentParser
import Foundation
import Utils

private enum Constants {}

extension Constants {
  static let metric = "BinarySize"
  // Command to get line execution counts of a file in a xcresult bundle.
  static let xcovCommand = "xcrun xccov view --archive --file "
  // The pattern is to match text "line_index: execution_counts" from the
  // outcome of xcresult bundle, e.g. "305 : 0".
  static let lineExecutionCountPattern = "[0-9]+\\s*:\\s*([0-9*]+)"
  // Match to the group of the lineExecutionCountPattern, i.e "([0-9*]+)".
  static let lineExecutionCountPatternGroup = 1
  // A file includes all newly added lines without tests covered.
  static let defaultUncoveredLineReportFileName = "uncovered_file_lines.json"
}

/// Pod Config
struct PodConfigs: Codable {
  let pods: [Pod]
}

struct Pod: Codable {
  let sdk: String
  let path: String
}

/// Cocoapods-size tool report
struct SDKBinaryReport: Codable {
  let combinedPodsExtraSize: Int

  enum CodingKeys: String, CodingKey {
    case combinedPodsExtraSize = "combined_pods_extra_size"
  }
}

/// Metrics Service API request data
struct BinaryMetricsReport: Codable {
  let metric: String
  let results: [Result]
  let log: String
}

struct Result: Codable {
  let sdk, type: String
  let value: Int
}

struct BinarySizeReportGenerator: ParsableCommand {
  @Option(
    help: "Cocoapods-size tool directory from https://github.com/google/cocoapods-size.",
    transform: URL.init(fileURLWithPath:)
  )
  var binarySizeToolDir: URL

  @Option(help: "Local SDK repo.", transform: URL.init(fileURLWithPath:))
  var SDKRepoDir: URL

  @Option(parsing: .upToNextOption, help: "SDKs to be measured.")
  var SDK: [String]

  func CreatePodConfigJSON(of sdks: [String], from sdk_dir: URL) throws {
    var pods: [Pod] = []
    for sdk in sdks {
      let pod: Pod = Pod(sdk: sdk, path: sdk_dir.path)
      pods.append(pod)
    }
    let podConfigs: PodConfigs = PodConfigs(pods: pods)
    try JSONParser.writeJSON(of: podConfigs, to: "./cocoapods_source_config.json")
  }

  func CreateMetricsRequestData(of sdks: [String], type: String, log: String) throws -> Data {
    var reports: [Result] = []
    for sdk in sdks {
      Shell.run(
        "cd cocoapods-size && python3 measure_cocoapod_size.py --cocoapods \(sdk) --cocoapods_source_config ../cocoapods_source_config.json --json binary_report.json",
        stdout: .stdout
      )
      let SDKBinarySize = try JSONParser.readJSON(
        of: SDKBinaryReport.self,
        from: "cocoapods-size/binary_report.json"
      )
      reports.append(Result(sdk: sdk, type: type, value: SDKBinarySize.combinedPodsExtraSize))
    }
    let metricsRequestReport = BinaryMetricsReport(
      metric: Constants.metric,
      results: reports,
      log: log
    )
    let data = try JSONEncoder().encode(metricsRequestReport)
    return data
  }

  func run() throws {
    try CreatePodConfigJSON(of: SDK, from: SDKRepoDir)
    let data = try CreateMetricsRequestData(
      of: SDK,
      type: "firebase-ios-sdk-testing",
      log: "testing.log"
    )
    print(String(decoding: data, as: UTF8.self))
  }
}

BinarySizeReportGenerator.main()
