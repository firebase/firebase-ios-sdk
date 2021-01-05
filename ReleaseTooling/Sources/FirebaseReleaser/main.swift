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
import FirebaseManifest
import Utils

struct FirebaseReleaser: ParsableCommand {
  /// The root of the Firebase git repo.
  // TODO: Add a default that sets the current repo - ['git', 'rev-parse', '--show-toplevel']
  @Option(help: "The root of the firebase-ios-sdk checked out git repo.",
          transform: URL.init(fileURLWithPath:))
  var gitRoot: URL

  /// Log commands only and do not make any repository or source changes.
  /// Useful for testing and for generating the list of push commands.
  @Option(default: false,
          help: "Log without executing the shell commands")
  var logOnly: Bool

  /// Set this option when starting a release.
  @Option(default: false,
          help: "Initialize the release branch")
  var initBranch: Bool

  /// Set this option to output the commands to generate the ordered `pod trunk push` commands.
  @Option(default: false,
          help: "Publish the podspecs to the CocoaPodsTrunk")
  var publish: Bool

  /// Set this option to only update the podspecs on cpdc.
  @Option(default: false,
          help: "Update the podspecs only")
  var pushOnly: Bool

  /// Set this option to update tags only.
  @Option(default: false,
          help: "Update the tags only")
  var updateTagsOnly: Bool

  mutating func validate() throws {
    guard FileManager.default.fileExists(atPath: gitRoot.path) else {
      throw ValidationError("git-root does not exist: \(gitRoot.path)")
    }
  }

  func run() throws {
    if logOnly {
      Shell.setLogOnly()
    }
    if initBranch {
      let branch = InitializeRelease.setupRepo(gitRoot: gitRoot)
      let version = FirebaseManifest.shared.version
      Shell.executeCommand("git commit -am \"Update versions for Release \(version)\"",
                           workingDir: gitRoot)
      Shell.executeCommand("git push origin \(branch)", workingDir: gitRoot)
      Shell.executeCommand("git branch --set-upstream-to=origin/\(branch) \(branch)",
                           workingDir: gitRoot)
      Tags.createTags(gitRoot: gitRoot)
      Push.pushPodsToCPDC(gitRoot: gitRoot)
    } else if updateTagsOnly {
      Tags.updateTags(gitRoot: gitRoot)
    } else if pushOnly {
      Push.pushPodsToCPDC(gitRoot: gitRoot)
    } else if publish {
      Push.publishPodsToTrunk(gitRoot: gitRoot)
    }
  }

  private func updateFirebasePod(newVersions: [String: String]) {
    let podspecFile = gitRoot.appendingPathComponent("Firebase.podspec")
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

// Start the parsing and run the tool.
FirebaseReleaser.main()
