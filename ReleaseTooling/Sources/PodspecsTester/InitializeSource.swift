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

import FirebaseManifest
import Utils

private enum Constants {}

extension Constants {
  static let localSpecRepoName = "specstesting"
  static let specRepo = "https://github.com/firebase/SpecsTesting"
  static let sdkRepo = "https://github.com/firebase/firebase-ios-sdk"
  static let testingTagPrefix = "testing-"
}

struct InitializeSpecTesting {
  static func setupRepo(sdkRepoURL: URL) {
    let manifest = FirebaseManifest.shared
    addSpecRepo(repoURL: Constants.specRepo)
    addTestingTag(path: sdkRepoURL, manifest: manifest)
    updatePodspecs(path: sdkRepoURL, manifest: manifest)
  }

  // The SpecsTesting repo will be added to `${HOME}/.cocoapods/`, and all
  // podspecs under this dir will be the source of the specs testing.
  private static func addSpecRepo(repoURL: String,
                                  podRepoName: String = Constants.localSpecRepoName) {
    let result = Shell.executeCommandFromScript("pod repo remove \(podRepoName)")
    switch result {
    case let .error(code, output):
      print("\(podRepoName) was not properly removed. \(podRepoName) probably" +
        "does not exist in local.\n \(output)")
    case let .success(output):
      print("\(podRepoName) was removed.")
    }
    Shell.executeCommand("pod repo add \(podRepoName) \(repoURL)")
  }

  // Add a testing tag to the head of the branch.
  private static func addTestingTag(path sdkRepoPath: URL, manifest: FirebaseManifest.Manifest) {
    let manifest = FirebaseManifest.shared
    let testingTag = Constants.testingTagPrefix + manifest.version
    // Add or update the testing tag to the local sdk repo.
    Shell.executeCommand("git tag -af \(testingTag) -m 'spectesting'", workingDir: sdkRepoPath)
  }

  // Update the podspec source.
  private static func updatePodspecs(path: URL, manifest: FirebaseManifest.Manifest) {
    for pod in manifest.pods {
      let version = manifest.versionString(pod)
      if !pod.isClosedSource {
        // Replace git and tag in the source of a podspec.
        Shell.executeCommand(
          "sed -i.bak -e \"s|\\(.*\\:git =>[[:space:]]*\\).*|\\1'\(path.path)',| ; " +
            "s|\\(.*\\:tag =>[[:space:]]*\\).*|\\1'\(Constants.testingTagPrefix + manifest.version)',|\" \(pod.name).podspec",
          workingDir: path
        )
      }
    }
  }
}
