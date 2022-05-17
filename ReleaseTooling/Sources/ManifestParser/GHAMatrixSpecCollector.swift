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

/// SDKPodspec is to help generate an array of podspec in json file, e.g.
/// ``` output.json
/// [{"podspec":"FirebaseABTesting.podspec"},{"podspec":"FirebaseAnalytics.podspec.json"}]
/// ```
struct SDKPodspec: Codable {
  let podspec: String
}

struct GHAMatrixSpecCollector {
  var SDKRepoURL: URL
  var outputSpecFileURL: URL
  var excludedSDKs: [String] = []

  func getPodsInManifest(_ manifest: Manifest) -> [String] {
    var podsList: [String] = []
    for pod in manifest.pods {
      podsList.append(pod.name)
    }
    return podsList
  }

  func getAllPodspecs() -> [String] {
    var output: [String] = []
    let fileManager = FileManager.default
    let podsSet = Set(getPodsInManifest(FirebaseManifest.shared))
    do {
      let fileURLs = try fileManager.contentsOfDirectory(
        at: SDKRepoURL,
        includingPropertiesForKeys: nil
      )
      for url in fileURLs {
        let fileNameComponents = url.lastPathComponent.components(separatedBy: ".")
        if fileNameComponents.count > 1, fileNameComponents[1] == "podspec" {
          let specName = fileNameComponents[0]
          podsSet.contains(specName) ? output
            .append(specName) : print("\(specName) is not in manifiest")
        }
      }
    } catch {
      print("Error while enumerating files: \(error.localizedDescription)")
    }
    return output
  }

  func generateMatrixJson(to filePath: URL) throws {
    let testingSpecs = getAllPodspecs()
    var sdkPodspecs: [SDKPodspec] = []
    for spec in testingSpecs {
      sdkPodspecs.append(SDKPodspec(podspec: spec))
    }
    // Trim whitespaces so the GitHub Actions matrix can read.
    let str = try String(
      decoding: JSONEncoder().encode(sdkPodspecs),
      as: UTF8.self
    )
    try str.trimmingCharacters(in: .whitespacesAndNewlines).write(
      to: filePath,
      atomically: true,
      encoding: String.Encoding.utf8
    )
  }
}
