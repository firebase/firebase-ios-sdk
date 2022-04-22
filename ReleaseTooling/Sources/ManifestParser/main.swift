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

struct ManifestParser: ParsableCommand {
  /// Path of a text file for Firebase Pods' names.
  @Option(help: "Output path of a generated file with all Firebase Pods' names.",
          transform: URL.init(fileURLWithPath:))
  var podNameOutputFilePath: URL

  func parsePodNames(_ manifest: Manifest) throws {
    var output: [String] = []
    for pod in manifest.pods {
      output.append(pod.name)
    }
    do {
      try output.joined(separator: ", ")
        .write(to: podNameOutputFilePath, atomically: true,
               encoding: String.Encoding.utf8)
      print("\(output) is written in \n \(podNameOutputFilePath).")
    } catch {
      throw error
    }
  }

  func run() throws {
    let manifest = FirebaseManifest.shared
    try parsePodNames(manifest)
  }
}

// Start the parsing and run the tool.
ManifestParser.main()
