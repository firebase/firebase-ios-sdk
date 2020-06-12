/*
 * Copyright 2020 Google LLC
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
          help: "The file path to a textproto file containing all the releasing Pods, of type `ZipBuilder_Release`.",
          transform: URL.init(fileURLWithPath:))
  var currentRelease: URL

  @Option(help: "The file path to a textproto file containing all existing Pods, of type `ZipBuilder_FirebaseSDKs.",
          transform: URL.init(fileURLWithPath:))
  var existingVersions: URL

  mutating func validate() throws {
    guard FileManager.default.fileExists(atPath: gitRoot.path) else {
      throw ValidationError("git-root does not exist: \(gitRoot.path)")
    }

    guard FileManager.default.fileExists(atPath: currentRelease.path) else {
      throw ValidationError("current-release does not exist: \(currentRelease.path). Do you need " +
        "to run `gcert`?")
    }

    guard FileManager.default.fileExists(atPath: existingVersions.path) else {
      throw ValidationError("existing-versions does not exist: \(existingVersions.path). Do you need " +
        "to run `gcert`?")
    }
  }

  func run() throws {
    // Guard for the `.withoutEscapingSlashes` API.
    guard #available(OSX 10.15, *) else { fatalError("Run on macOS 10.15 or above.") }

    let newVersions: [String: String] = getReleasingOSSVersions()

    guard let firebaseVersion = newVersions["Firebase"] else {
      fatalError("Could not determine Firebase version from versions: \(newVersions)")
    }

    // Catch the error specifically in a do/catch so we can re-print an appropriate message.
    let jsonData: Data
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
      jsonData = try encoder.encode(newVersions)
    } catch {
      fatalError("""
      Could not encode new versions to JSON. Error:
      \(error)
      New versions:
      \(newVersions)
      """)
    }

    // Write the JSON data to file.
    let manifestPath = gitRoot.appendingPathComponent("Releases/Manifests/\(firebaseVersion).json")
    try jsonData.write(to: manifestPath)
    print("Successfully wrote the OSS manifest to \(manifestPath).")
  }

  /// Assembles the releasing versions based on the release manifest passed in.
  /// Returns an array with the pod name as the key and version as the value,
  private func getReleasingOSSVersions() -> [String: String] {
    // Merge the versions from the current release and the known public versions.
    var releasingVersions: [String: String] = [:]

    // Load the current release and keep it in a dictionary format.
    let allSDKs = ManifestReader.loadAllReleasedSDKs(fromTextproto: existingVersions)
    let loadedRelease = ManifestReader.loadCurrentRelease(fromTextproto: currentRelease)
    for pod in loadedRelease.sdk {
      // We need to look at the full list of released SDKs to determine if a pod is open source or not.
      guard let existingPod = allSDKs.sdk.filter({ $0.name == pod.sdkName }).first else {
        fatalError("Found unexpected pod \(pod.sdkName) that isn't in list of all released SDKs.")
      }

      // Skip any closed source pods.
      guard existingPod.openSource else { continue }

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
}

// Start the parsing and run the tool.
OSSManifestGenerator.main()
