/*
 * Copyright 2022 Google LLC
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
import FirebaseManifest
import Foundation
import Utils

enum ParsingMode: String, EnumerableFlag {
  case forNoticesGeneration
  case forGHAMatrixGeneration
}

struct ManifestParser: ParsableCommand {
  @Option(help: "The path of the SDK repo.",
          transform: { str in
            if NSString(string: str).isAbsolutePath { return URL(fileURLWithPath: str) }
            let documentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return documentDir.appendingPathComponent(str)
          })
  var SDKRepoURL: URL?

  /// Path of a text file for Firebase Pods' names.
  @Option(help: "An output file with Podspecs",
          transform: { str in
            if NSString(string: str).isAbsolutePath { return URL(fileURLWithPath: str) }
            let documentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return documentDir.appendingPathComponent(str)
          })
  var outputFilePath: URL

  @Option(parsing: .upToNextOption, help: "Podspec files that will not be included.")
  var excludedSpecs: [String]

  @Flag(help: "Parsing mode for manifest")
  var mode: ParsingMode

  func parsePodNames(_ manifest: Manifest) throws {
    var output: [String] = []
    for pod in manifest.pods {
      output.append(pod.name)
    }
    do {
      try output.joined(separator: ",")
        .write(to: outputFilePath, atomically: true,
               encoding: String.Encoding.utf8)
      print("\(output) is written in \n \(outputFilePath).")
    } catch {
      throw error
    }
  }

  func run() throws {
    switch mode {
    case .forNoticesGeneration:
      try parsePodNames(FirebaseManifest.shared)
    case .forGHAMatrixGeneration:
      guard let sdkRepoURL = SDKRepoURL else {
        throw fatalError(
          "--sdk-repo-url should be specified when --for-gha-matrix-generation is on."
        )
      }
      let specCollector = GHAMatrixSpecCollector(
        SDKRepoURL: sdkRepoURL,
        outputSpecFileURL: outputFilePath
      )
      try specCollector.generateMatrixJson(to: outputFilePath)
    }
  }
}

// Start the parsing and run the tool.
ManifestParser.main()
