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
import Utils

struct FirebasePodUpdater {

  private func updateFirebasePod(newVersions: [String: String]) {
    let podspecFile = URL(fileURLWithPath: "aaa")
    var contents = ""
    do {
      contents = try String(contentsOfFile: podspecFile.path, encoding: .utf8)
    } catch {
      fatalError("Could not read Firebase podspec. \(error)")
    }
    for (pod, version) in newVersions {
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
}
