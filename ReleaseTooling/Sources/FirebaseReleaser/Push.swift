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

private enum Destination {
  case staging, trunk
}

enum Push {
  static func pushPodsToStaging(gitRoot: URL) {
    push(to: .staging, gitRoot: gitRoot)
  }

  static func publishPodsToTrunk(gitRoot: URL) {
    push(to: .trunk, gitRoot: gitRoot)
  }

  private static func push(to destination: Destination, gitRoot: URL) {
    let stagingRepo = "git@github.com:firebase/SpecsStaging"
    let stagingLocation = findOrRegisterPrivateCocoaPodsRepo(
      repo: stagingRepo,
      gitRoot: gitRoot,
      defaultRepoName: "spec-staging"
    )
    let manifest = FirebaseManifest.shared

    for pod in manifest.pods.filter({ $0.releasing }) {
      let warningsOK = pod.allowWarnings ? "--allow-warnings" : ""

      let command: String = {
        switch destination {
        case .staging:
          return "pod repo push --skip-tests --use-json \(warningsOK) \(stagingLocation) " +
            pod.skipImportValidation() + " \(pod.podspecName()) " +
            "--sources=\(stagingRepo).git,https://cdn.cocoapods.org"
        case .trunk:
          return "pod trunk push --skip-tests --synchronous \(warningsOK) " +
            pod
            .skipImportValidation() + " ~/.cocoapods/repos/\(stagingLocation)/\(pod.name)/" +
            "\(manifest.versionString(pod))/\(pod.name).podspec.json"
        }
      }()
      Shell.executeCommand(command, workingDir: gitRoot)
    }
  }

  private static func findPrivateCocoaPodsRepo(repo: String, gitRoot: URL) -> String? {
    let command = "pod repo list | grep -B2 \(repo) | head -1"
    let result = Shell.executeCommandFromScript(command, workingDir: gitRoot)
    switch result {
    case let .error(code, output):
      fatalError("""
      `pod --version` failed for \(repo) with exit code \(code)
      Output from `pod repo list`:
      \(output)
      """)
    case let .success(output):
      print(output)
      let repoName = output.trimmingCharacters(in: .whitespacesAndNewlines)
      return repoName.isEmpty ? nil : repoName
    }
  }

  /// @param defaultRepoName The repo name to register if not exists
  private static func findOrRegisterPrivateCocoaPodsRepo(repo: String, gitRoot: URL,
                                                         defaultRepoName: String) -> String {
    if let repoName = findPrivateCocoaPodsRepo(repo: repo, gitRoot: gitRoot) {
      return repoName
    }

    let command = "pod repo add \(defaultRepoName) \(repo)"
    let result = Shell.executeCommandFromScript(command, workingDir: gitRoot)
    switch result {
    case let .error(code, output):
      fatalError("""
      `pod --version` failed for \(repo) with exit code \(code)
      Output from `pod repo list`:
      \(output)
      """)
    case .success:
      return defaultRepoName
    }
  }
}
