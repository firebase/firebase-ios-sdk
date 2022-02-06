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

  /// Set this option to only update the podspecs on SpecsStaging.
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
    let startDate = Date()
    print("Started at: \(startDate.dateTimeString())")

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
      Push.pushPodsToStaging(gitRoot: gitRoot)
    } else if updateTagsOnly {
      Tags.updateTags(gitRoot: gitRoot)
    } else if pushOnly {
      Push.pushPodsToStaging(gitRoot: gitRoot)
    } else if publish {
      Push.publishPodsToTrunk(gitRoot: gitRoot)
    }

    let finishDate = Date()
    print("Finished at: \(finishDate.dateTimeString()). " +
      "Duration: \(startDate.formattedDurationSince(finishDate))")
  }
}

// Start the parsing and run the tool.
FirebaseReleaser.main()
