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

enum Push {
  static func pushPodsToCPDC(gitRoot: URL) {
    let cpdcLocation = findCpdc(gitRoot: gitRoot)
    let manifest = FirebaseManifest.shared

    for pod in manifest.pods.filter({ $0.releasing }) {
      let warningsOK = pod.allowWarnings ? " --allow-warnings" : ""

      Shell.executeCommand("pod repo push --skip-tests --use-json \(warningsOK) \(cpdcLocation) " +
        pod.skipImportValidation() + " \(pod.podspecName()) " +
        "--sources=sso://cpdc-internal/firebase.git,https://cdn.cocoapods.org",
        workingDir: gitRoot)
    }
  }

  private static func findCpdc(gitRoot: URL) -> String {
    let command = "pod repo list | grep -B2 sso://cpdc-internal/firebase | head -1"
    let result = Shell.executeCommandFromScript(command, workingDir: gitRoot)
    switch result {
    case let .error(code, output):
      fatalError("""
      `pod --version` failed with exit code \(code)
      Output from `pod repo list`:
      \(output)
      """)
    case let .success(output):
      print(output)
      return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }
}
