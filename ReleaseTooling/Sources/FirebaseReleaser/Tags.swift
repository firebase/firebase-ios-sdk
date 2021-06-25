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

enum Tags {
  static func createTags(gitRoot: URL, deleteExistingTags: Bool = false) {
    if deleteExistingTags {
      verifyTagsAreSafeToDelete(gitRoot: gitRoot)
    }
    let manifest = FirebaseManifest.shared
    createTag(gitRoot: gitRoot, tag: "CocoaPods-\(manifest.version)",
              deleteExistingTags: deleteExistingTags)
    createTag(gitRoot: gitRoot, tag: "CocoaPods-\(manifest.version)-beta",
              deleteExistingTags: deleteExistingTags)
  }

  static func updateTags(gitRoot: URL) {
    createTags(gitRoot: gitRoot, deleteExistingTags: true)
  }

  private static func createTag(gitRoot: URL, tag: String, deleteExistingTags: Bool) {
    if deleteExistingTags {
      Shell.executeCommand("git tag --delete \(tag)", workingDir: gitRoot)
      Shell.executeCommand("git push --delete origin \(tag)", workingDir: gitRoot)
    } else {
      verifyTagIsSafeToAdd(tag, gitRoot: gitRoot)
    }
    Shell.executeCommand("git tag \(tag)", workingDir: gitRoot)
    Shell.executeCommand("git push origin \(tag)", workingDir: gitRoot)
  }

  /// Check that the Firebase version has not already been published to CocoaPods, so that we don't
  /// delete a tag that is being used in production.
  /// It works by checking for the existence of the corresponding Firebase podspec in the
  /// clone of https://github.com/CocoaPods/Specs
  private static func verifyTagsAreSafeToDelete(gitRoot: URL) {
    var homeDirURL: URL
    if #available(OSX 10.12, *) {
      homeDirURL = FileManager.default.homeDirectoryForCurrentUser
    } else {
      fatalError("Run on at least macOS 10.12")
    }

    // Make sure that local master spec repo is up to date.
    Shell.executeCommand("pod repo update", workingDir: gitRoot)

    let manifest = FirebaseManifest.shared
    let firebasePublicURL = homeDirURL.appendingPathComponents(
      [".cocoapods", "repos", "cocoapods", "Specs", "0", "3", "5", "Firebase"]
    )

    guard FileManager.default.fileExists(atPath: firebasePublicURL.path) else {
      fatalError("You must have the CocoaPods Spec repo installed to retag versions.")
    }

    guard !FileManager.default.fileExists(atPath:
      firebasePublicURL.appendingPathComponent(manifest.version).path) else {
      fatalError("Do not remove tag of a published Firebase version.")
    }
  }

  /// Before trying to add a new tag, make sure that it doesn't already exist locally or in the
  /// git origin. The git commands return an empty string if the tag doesn't exist.
  private static func verifyTagIsSafeToAdd(_ tag: String, gitRoot: URL) {
    if checkTagCommand("git tag -l \(tag)", gitRoot: gitRoot) != "" {
      fatalError("Tag \(tag) already exists locally. Please delete and restart")
    }
    if checkTagCommand("git ls-remote origin refs/tags/\(tag)", gitRoot: gitRoot) != "" {
      fatalError("Tag \(tag) already exists locally. Please delete and restart")
    }
  }

  private static func checkTagCommand(_ command: String, gitRoot: URL) -> String {
    let result = Shell.executeCommandFromScript(command, workingDir: gitRoot)
    switch result {
    case let .error(code, output):
      fatalError("""
      `\(command) failed with exit code \(code)
      Output from `pod repo list`:
      \(output)
      """)
    case let .success(output):
      return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }
}
