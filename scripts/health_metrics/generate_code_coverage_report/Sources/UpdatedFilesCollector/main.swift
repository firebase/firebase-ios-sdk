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
  let podspecs: [String]
  let filePatterns: [String]
}

/// SDKPodspec is to help generate an array of podspec in json file, e.g.
/// ``` output.json
/// [{"podspec":"FirebaseABTesting.podspec"},{"podspec":"FirebaseAnalytics.podspec.json"}]
/// ```
struct SDKPodspec: Codable {
  let podspec: String
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

  @Option(help: "A output file with all Podspecs with related changed files",
          transform: { str in
            print(FileManager.default.currentDirectoryPath)
            let documentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return documentDir.appendingPathComponent(str)
          })
  var outputSDKFileURL: URL?

  /// Exclude pods from spec testings.
  @Option(parsing: .upToNextOption, help: "Podspecs that will be excluded in the testings.")
  var excludePodspecs: [String] = []

  func run() throws {
    var podspecsWithChangedFiles: [SDKPodspec] = []
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
            for podspec in sdkPatterns.podspecs {
              if !excludePodspecs.contains(podspec) {
                podspecsWithChangedFiles.append(SDKPodspec(podspec: podspec))
              } else if let outputPath = outputSDKFileURL {
                print(
                  "\(podspec) was excluded and will not be written in \(outputPath.absoluteString) "
                )
              }
            }
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
    if let outputPath = outputSDKFileURL {
      do {
        // Instead of directly writing Data to a file, trasnferring Data to
        // String can help trimming whitespaces and newlines in advance.
        let str = try String(
          decoding: JSONEncoder().encode(podspecsWithChangedFiles),
          as: UTF8.self
        )
        try str.trimmingCharacters(in: .whitespacesAndNewlines).write(
          to: outputPath,
          atomically: true,
          encoding: String.Encoding.utf8
        )
      } catch {
        fatalError("Error while writting in \(outputPath.path).\n\(error)")
      }
    }
  }
}

UpdatedFilesCollector.main()
