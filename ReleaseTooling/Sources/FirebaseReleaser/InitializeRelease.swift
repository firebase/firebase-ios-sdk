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

import FirebaseManifest
import Utils

struct InitializeRelease {
  static func setupRepo(gitRoot: URL) -> String {
    let manifest = FirebaseManifest.shared
    let branch = createVersionBranch(path: gitRoot, version: manifest.version)
    updatePodspecs(path: gitRoot, manifest: manifest)
    updatePodfiles(path: gitRoot, version: manifest.version)
    updateSwiftPackageVersion(path: gitRoot, version: manifest.version)
    return branch
  }

  /// The branch is based on the minor version to represent this is the branch for subsequent
  /// patches.
  private static func createVersionBranch(path: URL, version: String) -> String {
    let versionParts = version.split(separator: ".")
    let minorVersion = "\(versionParts[0]).\(versionParts[1])"
    let branch = "version-\(minorVersion)"
    Shell.executeCommand("git checkout master", workingDir: path)
    Shell.executeCommand("git pull", workingDir: path)
    Shell.executeCommand("git checkout -b \(branch)", workingDir: path)
    return branch
  }

  /// Update the podspec versions.
  private static func updatePodspecs(path: URL, manifest: FirebaseManifest.Manifest) {
    for pod in manifest.pods {
      let version = manifest.versionString(pod)
      if !pod.isClosedSource {
        if pod.name == "Firebase" {
          updateFirebasePodspec(path: path, manifest: manifest)
        } else {
          // Patch the new version to the podspec's version attribute.
          Shell.executeCommand("sed -i.bak -e \"s/\\(\\.version.*=[[:space:]]*'\\).*'/\\1" +
            "\(version)'/\" \(pod.name).podspec", workingDir: path)
        }
      } else {
        let fileName = "\(pod.name).podspec.json"

        // These are the keys in the `*.podspec.json` files that map to a
        // semantic version that needs to be bumped.
        let versionedKeys = [
          "GoogleAppMeasurement",
          "GoogleAppMeasurement/WithoutAdIdSupport",
          "version",
        ]

        let scripts: [String] = versionedKeys.map { key in
          let pattern = #""\#(key)": ".*""#
          let replace = #""\#(key)": "\#(version)""#
          let script = "-e 's|\(pattern)|\(replace)|'"
          return script
        }

        let command = "sed -i.bak \(scripts.joined(separator: " ")) \(fileName)"
        Shell.executeCommand(command, workingDir: path)
      }
    }
  }

  // This function patches the versions in the Firebase.podspec. It uses Swift instead of sed
  // like the other version patching.
  // TODO: Choose one or the other mechanism.
  // TODO: If we keep Swift, consider using Scanner.
  private static func updateFirebasePodspec(path: URL, manifest: FirebaseManifest.Manifest) {
    let podspecFile = path.appendingPathComponent("Firebase.podspec")
    var contents = ""
    do {
      contents = try String(contentsOfFile: podspecFile.path, encoding: .utf8)
    } catch {
      fatalError("Could not read Firebase podspec. \(error)")
    }
    let firebaseVersion = manifest.version
    for firebasePod in manifest.pods {
      let pod = firebasePod.name
      let version = firebasePod.isBeta ? firebaseVersion + "-beta" : firebaseVersion
      if pod == "Firebase" {
        // TODO: This block is redundant with `updatePodspecs`. Decide to go with Swift or sed.
        guard let range = contents.range(of: "s.version") else {
          fatalError("Could not find version of Firebase pod in podspec at \(podspecFile)")
        }
        // Replace version in string like s.version = '6.9.0'
        updateVersion(&contents, in: range, to: version)

      } else {
        // Iterate through all the ranges of `pod`'s occurrences.
        for range in contents.ranges(of: pod) {
          // Replace version in string like ss.dependency 'FirebaseCore', '6.3.0'.
          updateVersion(&contents, in: range, to: version)
        }
      }
    }
    do {
      try contents.write(to: podspecFile, atomically: false, encoding: .utf8)
    } catch {
      fatalError("Failed to write \(podspecFile.path). \(error)")
    }
  }

  /// Update the existing version to the given version by writing to a given string using the provided range.
  /// - Parameters:
  ///   - contents: A reference to a String containing a version that will be updated.
  ///   - range: The range containing a version substring that will be updated.
  ///   - version: The version string to update to.
  private static func updateVersion(_ contents: inout String, in range: Range<String.Index>,
                                    to version: String) {
    var versionStartIndex = contents.index(after: range.upperBound)
    while !contents[versionStartIndex].isWholeNumber {
      versionStartIndex = contents.index(after: versionStartIndex)
    }
    var versionEndIndex = contents.index(after: versionStartIndex)
    while contents[versionEndIndex] != "'" {
      versionEndIndex = contents.index(after: versionEndIndex)
    }
    contents.replaceSubrange(versionStartIndex ..< versionEndIndex, with: version)
  }

  private static func updatePodfiles(path: URL, version: String) {
    // Update the Podfiles across the repo.
    let firestorePodfile = path.appendingPathComponent("Firestore")
      .appendingPathComponent("Example")
    let collisionPodfile = path.appendingPathComponent("SymbolCollisionTest")
    let sedCommand = "sed -i.bak -e \"s#\\(pod " +
      "'Firebase/CoreOnly',[[:space:]]*'\\).*'#\\1\(version)'#\" Podfile"
    Shell.executeCommand(sedCommand, workingDir: firestorePodfile)

    let sedCommand2 = "sed -i.bak -e \"s#\\(pod " +
      "'Firebase',[[:space:]]*'\\).*'#\\1\(version)'#\" Podfile"
    Shell.executeCommand(sedCommand2, workingDir: collisionPodfile)
  }

  private static func updateSwiftPackageVersion(path: URL, version: String) {
    // Match strings like `let firebaseVersion = "7.7.0"` and update the version.
    Shell.executeCommand("sed -i.bak -e \"s/\\(let firebaseVersion.*=[[:space:]]*\\).*/\\1" +
      "\\\"\(version)\\\"/\" Package.swift", workingDir: path)
  }
}
