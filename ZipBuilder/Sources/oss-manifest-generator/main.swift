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

import ArgumentParser
import ManifestReader

struct OSSManifestGenerator: ParsableCommand {
  /// The root of the Firebase git repo.
  @Option(help: "The root of the firebase-ios-sdk checked out git repo.",
          transform: URL.init(fileURLWithPath:))
  var gitRoot: URL

  /// A file URL to a textproto with the contents of a `FirebasePod_Release` object. Used to verify
  /// expected version numbers.
  @Option(name: .customLong("releasing-pods"),
          help: "The file path to a textproto file containing all the releasing Pods, of type `FirebasePod_Release`.",
          transform: URL.init(fileURLWithPath:))
  var currentRelease: URL

  mutating func validate() throws {
    guard FileManager.default.fileExists(atPath: gitRoot.path) else {
      throw ValidationError("git-root does not exist: \(gitRoot.path)")
    }

    guard FileManager.default.fileExists(atPath: currentRelease.path) else {
      throw ValidationError("current-release does not exist: \(currentRelease.path). Do you need " +
        "to run `prodaccess`?")
    }
  }

  func run() throws {
    // Keep timing for how long it takes to change the Firebase pod versions.
    let buildStart = Date()

    let newVersions = getExpectedVersions()

    print("Updating Firebase pod for version \(String(describing: newVersions["Firebase"]!))")

    // Get the time since the tool start.
    let secondsSinceStart = -Int(buildStart.timeIntervalSinceNow)
    print("""
    Time profile:
      It took \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m) to update the Firebase pod.
    """)
  }

  /// Assembles the expected versions based on the release manifest passed in.
  /// Returns an array with the pod name as the key and version as the value,
  private func getExpectedVersions() -> [String: String] {
    // Merge the versions from the current release and the known public versions.
    var releasingVersions: [String: String] = [:]

    // Load the current release and keep it in a dictionary format.
    let loadedRelease = ManifestReader.loadCurrentRelease(fromTextproto: currentRelease)
    for pod in loadedRelease.sdk {
      releasingVersions[pod.sdkName] = pod.sdkVersion
      print("\(pod.sdkName): \(pod.sdkVersion)")
    }

    if !releasingVersions.isEmpty {
      print("""
        Generating OSS Manifest in git installation at \(gitRoot.path) with the following \
        versions:
        \(releasingVersions)
        """)
    }

    return releasingVersions
  }

  /// Generates the contents of the OSS manifest
  /// - Parameter versions: <#versions description#>
  /// - Returns: <#description#>
  private func generateOSSManifest(from versions: [String: String]) -> String {

  }
}

// Start the parsing and run the tool.
OSSManifestGenerator.main()
