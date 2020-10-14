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

struct Tags {
  static func create(gitRoot: URL) {
    let manifest = FirebaseManifest.shared
    createTag(gitRoot: gitRoot, tag: "CocoaPods-\(manifest.version)")

    for pod in manifest.pods {
      if pod.isFirebase {
        continue
      }
      if !pod.name.starts(with: "Google") {
        fatalError("Unrecognized Other Pod: \(pod.name). Only Google prefix is recognized")
      }
      guard let version = pod.podVersion else {
        fatalError("Non-Firebase pod \(pod.name) is missing a version")
      }
      let tag = pod.name.replacingOccurrences(of: "Google", with: "") + "-" + version
      createTag(gitRoot: gitRoot, tag: tag)
    }
  }

  static func createTag(gitRoot: URL, tag: String) {
    Shell.executeCommand("git tag \(tag)", workingDir: gitRoot)
    Shell.executeCommand("git push origin \(tag)", workingDir: gitRoot)
  }
}
