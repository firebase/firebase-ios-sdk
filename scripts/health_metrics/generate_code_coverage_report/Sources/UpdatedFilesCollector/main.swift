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

struct SDKFilePattern: Codable {
  let sdk: String
  let filePatterns: [String]
}

struct UpdatedFilesCollector: ParsableCommand {
  @Option(help: "A txt File with updated files.",
          transform: { str in
            let url = URL(fileURLWithPath: str)
            let data = try String(contentsOf: url)
            return data.components(separatedBy: .newlines)
          })
  var changedFilePaths: [String]

  @Option(help: "A JSON file path conforming to the struct SDKFilePattern",
          transform: { str in
            let url = URL(fileURLWithPath: str)
            let jsonData = try Data(contentsOf: url)
            return try JSONDecoder().decode([SDKFilePattern].self, from: jsonData)
          })
  var codeCoverageFilePatterns: [SDKFilePattern]

  func run() throws {
    print("=============== list changed files ===============")
    print(changedFilePaths.joined(separator: "\n"))
    // Initiate all run_job flag to false.
    for sdkPatterns in codeCoverageFilePatterns {
      print("::set-output name=\(sdkPatterns.sdk)_run_job::false")
    }
    // Go through patterns of each sdk. Once there is a path of changed file matching
    // any pattern of this sdk, the run_job flag of this sdk will be turned to true.
    for sdkPatterns in codeCoverageFilePatterns {
      var trigger_pod_test_for_coverage_report = false
      for pattern in sdkPatterns.filePatterns {
        let regex = try! NSRegularExpression(pattern: pattern)
        // If one changed file path match one path of this sdk, the run_job flag of
        // the sdk will be turned on.
        for changedFilePath in changedFilePaths {
          let range = NSRange(location: 0, length: changedFilePath.utf16.count)
          if regex.firstMatch(in: changedFilePath, options: [], range: range) != nil {
            print("=============== paths of changed files ===============")
            print("::set-output name=\(sdkPatterns.sdk)_run_job::true")
            print("\(sdkPatterns.sdk): \(changedFilePath) is updated under the pattern, \(pattern)")
            trigger_pod_test_for_coverage_report = true
            // Once this sdk run_job flag is turned to true, then the loop
            // will skip to the next sdk.
            break
          }
          if trigger_pod_test_for_coverage_report { break }
        }
        if trigger_pod_test_for_coverage_report { break }
      }
    }
  }
}

UpdatedFilesCollector.main()
