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

import FirebaseManifest
import Utils

struct InitializeRelease {
  static func setupRepo(gitRoot: URL) {
    let manifest = FirebaseManifest.shared
    createReleaseBranch(path: gitRoot, version: manifest.version)
    updatePodspecs(path: gitRoot, manifest: manifest)
    updateFirebasePodspec(path: gitRoot, manifest: manifest)
    updatePodfiles(path: gitRoot, version: manifest.version)
  }

  private static func createReleaseBranch(path: URL, version: String) {
    // The branch is based on the minor version to represent this is the branch for subsequent
    // patches.
    let versionParts = version.split(separator: ".")
    let minorVersion = "\(versionParts[0]).\(versionParts[1])"
    let branch = "release-\(minorVersion)"
    Shell.executeCommand("git checkout master", workingDir: path)
    Shell.executeCommand("git pull", workingDir: path)
    Shell.executeCommand("git checkout -b \(branch)", workingDir: path)
  }

  private static func updatePodspecs(path: URL, manifest: FirebaseManifest.Manifest) {
    let version = manifest.version
    // Update the Firebase_VERSION preprocessor string.
    Shell.executeCommand("sed -i.bak -e \"s/\\(Firebase_VERSION=\\).*'/\\1\(version)'/\" " +
                         "FirebaseCore.podspec",
                         workingDir: path)

    // Update the versions in the non-Firebase pods.
    for pod in manifest.otherPods {
      if pod.releasing {
        Shell.executeCommand("sed -i.bak -e \"s/\\(\\.version.*=[[:space:]]*'\\).*'/\\1 " +
                            "\(pod.version)'/\" \(pod.name).podspec",
                             workingDir: path)
      }
    }

    // Update the versions in the Firebase pods.
    for pod in manifest.firebasePods {
      Shell.executeCommand("sed -i.bak -e \"s/\\(\\.version.*=[[:space:]]*'\\).*'/\\1 " +
                          "\(version)'/\" \(pod.name).podspec",
                           workingDir: path)
    }
  }

  private static func updateFirebasePodspec(path: URL, manifest: FirebaseManifest.Manifest) {
    let podspecFile = path.appendingPathComponent("Firebase.podspec")
    var contents = ""
    do {
      contents = try String(contentsOfFile: podspecFile.path, encoding: .utf8)
    } catch {
      fatalError("Could not read Firebase podspec. \(error)")
    }
    let version = manifest.version
    for firebasePod in manifest.firebasePods {
      let pod = firebasePod.name
      if pod == "Firebase" {
        // Replace version in string like s.version = '6.9.0'
        guard let range = contents.range(of: "s.version") else {
          fatalError("Could not find version of Firebase pod in podspec at \(podspecFile)")
        }
        var versionStartIndex = contents.index(range.upperBound, offsetBy: 1)
        while contents[versionStartIndex] != "'" {
          versionStartIndex = contents.index(versionStartIndex, offsetBy: 1)
        }
        var versionEndIndex = contents.index(versionStartIndex, offsetBy: 1)
        while contents[versionEndIndex] != "'" {
          versionEndIndex = contents.index(versionEndIndex, offsetBy: 1)
        }
        contents.removeSubrange(versionStartIndex ... versionEndIndex)
        contents.insert(contentsOf: "'" + version + "'", at: versionStartIndex)
      } else {
        // Replace version in string like ss.dependency 'FirebaseCore', '6.3.0'
        guard let range = contents.range(of: pod) else {
          // This pod is not a top-level Firebase pod dependency.
          continue
        }
        var versionStartIndex = contents.index(range.upperBound, offsetBy: 2)
        while !contents[versionStartIndex].isWholeNumber {
          versionStartIndex = contents.index(versionStartIndex, offsetBy: 1)
        }
        var versionEndIndex = contents.index(versionStartIndex, offsetBy: 1)
        while contents[versionEndIndex] != "'" {
          versionEndIndex = contents.index(versionEndIndex, offsetBy: 1)
        }
        contents.removeSubrange(versionStartIndex ... versionEndIndex)
        contents.insert(contentsOf: version + "'", at: versionStartIndex)
      }
    }
    do {
      try contents.write(to: podspecFile, atomically: false, encoding: .utf8)
    } catch {
      fatalError("Failed to write \(podspecFile.path). \(error)")
    }
  }

  private static func updatePodfiles(path: URL, version: String) {
    // Update the Podfiles across the repo.
    let firebasePodfile = path.appendingPathComponent("Example")
    let firestorePodfile = path.appendingPathComponent("Firestore")
      .appendingPathComponent("Example")
    let collisionPodfile = path.appendingPathComponent("SymbolCollisionTest")
    let sedCommand = "sed -i.bak -e \"s#\\(pod " +
                     "'Firebase/CoreOnly',[[:space:]]*'\\).*'#\\1\(version)'#\" Podfile"

    Shell.executeCommand(sedCommand, workingDir: firebasePodfile)
    Shell.executeCommand(sedCommand, workingDir: firestorePodfile)

    let sedCommand2 = "sed -i.bak -e \"s#\\(pod " +
                      "'Firebase',[[:space:]]*'\\).*'#\\1\(version)'#\" Podfile"
    Shell.executeCommand(sedCommand2, workingDir: collisionPodfile)
  }
}

