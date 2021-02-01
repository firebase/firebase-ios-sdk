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
  case cpdc, trunk
}

enum Push {
  static func pushPodsToCPDC(gitRoot: URL) {
    push(to: .cpdc, gitRoot: gitRoot)
  }

  static func publishPodsToTrunk(gitRoot: URL) {
    push(to: .trunk, gitRoot: gitRoot)
  }

  private static func push(to destination: Destination, gitRoot: URL) {
    let cpdcRepo = "sso://cpdc-internal/firebase"
    let cpdcLocation = findPrivateCocoaPodsRepo(repo: cpdcRepo, gitRoot: gitRoot)
    let stagingRepo = "git@github.com:firebase/SpecsStaging"
    let stagingLocation = findPrivateCocoaPodsRepo(repo: stagingRepo, gitRoot: gitRoot)
    let manifest = FirebaseManifest.shared

    for pod in manifest.pods.filter({ $0.releasing }) {
      let warningsOK = pod.allowWarnings ? "--allow-warnings" : ""

      let command: String = {
        switch destination {
        case .cpdc:
          var pushCommands = ""
          if pod.isClosedSource {
            // Push closed source pods to SpecsStaging to keep CI working.
            pushCommands =
              "pod repo push --skip-tests --use-json \(warningsOK) \(stagingLocation) " +
              pod.skipImportValidation() + " \(pod.podspecName()) " +
              "--sources=\(stagingRepo).git,https://cdn.cocoapods.org; "
          }
          pushCommands += "pod repo push --skip-tests --use-json \(warningsOK) \(cpdcLocation) " +
            pod.skipImportValidation() + " \(pod.podspecName()) " +
            "--sources=\(cpdcRepo).git,https://cdn.cocoapods.org"
          return pushCommands

        case .trunk:
          return "pod trunk push --skip-tests --synchronous \(warningsOK) " +
            pod.skipImportValidation() + " ~/.cocoapods/repos/\(cpdcLocation)/Specs/\(pod.name)/" +
            "\(manifest.versionString(pod))/\(pod.name).podspec.json"
        }
      }()
      Shell.executeCommand(command, workingDir: gitRoot)
    }
  }

  private static func findPrivateCocoaPodsRepo(repo: String, gitRoot: URL) -> String {
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
      return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }
}
