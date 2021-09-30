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

import Foundation
import Utils

// This will contain code coverage result from a xcresult bundle.
struct CoverageReportSource: Codable {
  let coveredLines: Int
  let lineCoverage: Double
  let targets: [Target]

  struct Target: Codable {
    let name: String
    let lineCoverage: Double
    let files: [File]
    struct File: Codable {
      let coveredLines: Int
      let lineCoverage: Double
      let path: String
      let name: String
    }
  }
}

// This will contains data that will be eventually transferred to a json file
// sent to the Metrics Service.
struct CoverageReportRequestData: Codable {
  var metric: String
  var results: [FileCoverage]
  var log: String

  struct FileCoverage: Codable {
    let sdk: String
    let type: String
    let value: Double
  }
}

// In the tool here, this will contain add all CoverageReportSource objects from
// different xcresult bundles.
extension CoverageReportRequestData {
  init() {
    metric = "Coverage"
    results = []
    log = ""
  }

  mutating func addCoverageData(from source: CoverageReportSource, resultBundle: String) {
    for target in source.targets {
      // Get sdk name. resultBundle is like ${SDK}-${platform}. E.g. FirebaseDatabase-ios.
      // To display only sdk related tests and exclude non related testing, e.g.
      // FirebaseDatabase-ios-GoogleDataTransport.framework,
      // FirebaseDatabase-ios-FirebaseCore-Unit-unit.xctest,
      // FirebaseDatabase-ios-FirebaseCore.framework, a regex pattern will be
      // used to exclude results that are not related in terms of the target names.
      let sdk_name = resultBundle.components(separatedBy: "-")[0]
      let range = NSRange(location: 0, length: target.name.utf16.count)
      let target_pattern = ".*\(sdk_name).*framework"
      let sdk_related_coverage_file_pattern = try! NSRegularExpression(
        pattern: target_pattern,
        options: NSRegularExpression.Options(rawValue: 0)
      )
      print("Target: \(target.name) is detected.")

      if sdk_related_coverage_file_pattern.firstMatch(in: target.name, range: range) != nil {
        print(
          "Target, \(target.name), fit the pattern, \(target_pattern), and will be involved in the report."
        )
        results
          .append(FileCoverage(sdk: resultBundle + "-" + target.name, type: "",
                               value: target.lineCoverage))
        for file in target.files {
          results
            .append(FileCoverage(sdk: resultBundle + "-" + target.name, type: file.name,
                                 value: file.lineCoverage))
        }
      }
    }
  }

  mutating func addLogLink(_ logLink: String) {
    log = logLink
  }

  func toData() -> Data {
    let jsonData = try! JSONEncoder().encode(self)
    return jsonData
  }
}

// Read json file and transfer to CoverageReportSource.
func readLocalFile(forName name: String) -> CoverageReportSource? {
  do {
    let fileURL = URL(fileURLWithPath: FileManager().currentDirectoryPath)
      .appendingPathComponent(name)
    let data = try Data(contentsOf: fileURL)
    let coverageReportSource = try JSONDecoder().decode(CoverageReportSource.self, from: data)
    return coverageReportSource
  } catch {
    print("CoverageReportSource is not able to be generated. \(error)")
  }

  return nil
}

// Get in the dir, xcresultDirPathURL, which contains all xcresult bundles, and
// create CoverageReportRequestData which will have all coverage data for in
// the dir.
func combineCodeCoverageResultBundles(from xcresultDirPathURL: URL,
                                      log: String) throws -> CoverageReportRequestData? {
  let fileManager = FileManager.default
  do {
    var coverageReportRequestData = CoverageReportRequestData()
    coverageReportRequestData.addLogLink(log)
    let fileURLs = try fileManager.contentsOfDirectory(
      at: xcresultDirPathURL,
      includingPropertiesForKeys: nil
    )
    let xcresultURLs = fileURLs.filter { $0.pathExtension == "xcresult" }
    for xcresultURL in xcresultURLs {
      let resultBundleName = xcresultURL.deletingPathExtension().lastPathComponent
      let coverageSourceJSONFile = "\(resultBundleName).json"
      try? fileManager.removeItem(atPath: coverageSourceJSONFile)
      Shell
        .run("xcrun xccov view --report --json \(xcresultURL.path) >> \(coverageSourceJSONFile)")
      if let coverageReportSource = readLocalFile(forName: "\(coverageSourceJSONFile)") {
        coverageReportRequestData.addCoverageData(
          from: coverageReportSource,
          resultBundle: resultBundleName
        )
      }
    }
    return coverageReportRequestData
  } catch {
    print(
      "Error while enuermating files \(xcresultDirPathURL): \(error.localizedDescription)"
    )
  }
  return nil
}
