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
  static let cocoapodsDir =
    "\(ProcessInfo.processInfo.environment["HOME"]!)/.cocoapods/repos/\(localSpecRepoName)"
  static let versionFetchPatterns = [
    "json": "\"version\"[[:space:]]*:[[:space:]]*\"(.*)\"",
    "podspec": "\\.version[[:space:]]*=[[:space:]]*\'([^~=><].*)\'",
  ]
}

enum InitializeSpecTesting {
  enum VersionFetchError: Error {
    case noMatchesCaught
    case multipleMatches
    case noSubgroupCaught
  }

  static func setupRepo(sdkRepoURL: URL) {
    let manifest = FirebaseManifest.shared
    addSpecRepo(repoURL: Constants.specRepo)
    addTestingTag(path: sdkRepoURL, manifest: manifest)
    updatePodspecs(path: sdkRepoURL, manifest: manifest)
    copyPodspecs(from: sdkRepoURL, manifest: manifest)
  }

  // The SpecsTesting repo will be added to `${HOME}/.cocoapods/`, and all
  // podspecs under this dir will be the source of the specs testing.
  private static func addSpecRepo(repoURL: String,
                                  podRepoName: String = Constants.localSpecRepoName) {
    let result = Shell.executeCommandFromScript("pod repo remove \(podRepoName)")
    switch result {
    case let .error(_, output):
      print("\(podRepoName) was not properly removed. \(podRepoName) probably" +
        "does not exist in local.\n \(output)")
    case .success:
      print("\(podRepoName) was removed.")
    }
    Shell.executeCommand("pod repo add \(podRepoName) \(repoURL)")
  }

  // Add a testing tag to the head of the branch.
  private static func addTestingTag(path sdkRepoPath: URL, manifest: FirebaseManifest.Manifest) {
    // Pods could have different versions, like `8.11.0` and `8.11.0-beta`.
    // These versions should be part of tags, so a warning from `pod spec lint`
    // could be avoided.
    // ```
    //   The version should be included in the Git tag.
    // ```
    // The tag should include `s.version`, e.g.
    // If "s.version = '8.11.0-beta'", the tag should include 8.11.0-beta to
    // avoid triggering the warning.
    for pod in manifest.pods {
      let testingTag = Constants.testingTagPrefix + manifest.versionString(pod)
      // Add or update the testing tag to the local sdk repo.
      Shell.executeCommand("git tag -af \(testingTag) -m 'spectesting'", workingDir: sdkRepoPath)
    }
  }

  // Update the podspec source.
  private static func updatePodspecs(path: URL, manifest: FirebaseManifest.Manifest) {
    for pod in manifest.pods {
      let version = manifest.versionString(pod)
      if !pod.isClosedSource {
        // Replace git and tag in the source of a podspec.
        // Before:
        //  s.source           = {
        //    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
        //    :tag => 'CocoaPods-' + s.version.to_s
        //  }
        // After `sed`:
        //  s.source           = {
        //    :git => '\(path.path)',
        //    :tag => 'testing-\(version)',
        //  }
        Shell.executeCommand(
          "sed -i.bak -e \"s|\\(.*\\:git =>[[:space:]]*\\).*|\\1'\(path.path)',| ; " +
            "s|\\(.*\\:tag =>[[:space:]]*\\).*|\\1'\(Constants.testingTagPrefix + version)',|\" \(pod.name).podspec",
          workingDir: path
        )
      }
    }
  }

  // Copy updated specs to the `${HOME}/.cocoapods/` dir.
  private static func copyPodspecs(from specsDir: URL, manifest: FirebaseManifest.Manifest) {
    let path = specsDir.appendingPathComponent("*.podspec").path
    let paths = Shell.executeCommandFromScript("ls \(path)", outputToConsole: false)
    var candidateSpecs: [String]?
    switch paths {
    case let .error(_, output):
      print("specs are not properly read, \(output)")
    case let .success(output):
      candidateSpecs = output.trimmingCharacters(in: .whitespacesAndNewlines)
        .components(separatedBy: "\n")
    }
    guard let specs = candidateSpecs else {
      print("There are no files ending with `podspec` detected.")
      return
    }
    for spec in specs {
      let specInfo = fetchPodVersion(from: URL(fileURLWithPath: spec))
      // Create directories `${HOME}/.cocoapods/${Pod}/${version}`
      let podDirURL = createPodDirectory(
        specRepoPath: Constants.cocoapodsDir,
        podName: specInfo.name,
        version: specInfo.version
      )
      // Copy updated podspecs to directories `${HOME}/.cocoapods/${Pod}/${version}`
      Shell.executeCommand("cp -rf \(spec) \(podDirURL)")
    }
  }

  private static func fetchPodVersion(from path: URL) -> (name: String, version: String) {
    var contents = ""
    var podName = ""
    var version = ""
    do {
      contents = try String(contentsOfFile: path.path, encoding: .utf8)
    } catch {
      fatalError("Could not read the podspec. \(error)")
    }
    // Closed source podspecs, e.g. `GoogleAppMeasurement.podspec`.
    if path.pathExtension == "json" {
      // Remove both extensions of `podspec` and `json`.
      podName = path.deletingPathExtension().deletingPathExtension().lastPathComponent
    } else if path.pathExtension == "podspec" {
      podName = path.deletingPathExtension().lastPathComponent
    }

    guard let versionPattern = Constants.versionFetchPatterns[path.pathExtension] else {
      fatalError("Regex pattern for \(path.pathExtension) is not found.")
    }

    do {
      version = try matchVersion(from: contents, withPattern: versionPattern)
    } catch VersionFetchError.noMatchesCaught {
      fatalError(
        "Podspec from '\(path.path)' cannot find a version with the following regex\n\(versionPattern)"
      )
    } catch VersionFetchError.noSubgroupCaught {
      fatalError(
        "A subgroup of version from Podspec, '\(path.path)', is not caught from the pattern\n\(versionPattern)"
      )
    } catch VersionFetchError.multipleMatches {
      print("found multiple version matches from \(path.path).")
      fatalError(
        "There should have only one version matching the regex pattern, please update the pattern\n\(versionPattern)"
      )
    } catch {
      fatalError("Version is not caught properly. \(error)")
    }
    return (podName, version)
  }

  private static func matchVersion(from content: String,
                                   withPattern regex: String) throws -> String {
    let versionMatches = try content.match(regex: regex)
    if versionMatches.isEmpty {
      throw VersionFetchError.noMatchesCaught
    }
    // One subgroup in the regex should be for the version
    else if versionMatches[0].count < 2 {
      throw VersionFetchError.noSubgroupCaught
    }
    // There are more than one string matching the regex. There should be only
    // one version matching the regex.
    else if versionMatches.count > 1 {
      print(versionMatches)
      throw VersionFetchError.multipleMatches
    }
    return versionMatches[0][1]
  }

  private static func createPodDirectory(specRepoPath: String, podName: String,
                                         version: String) -> URL {
    guard let specRepoURL = URL(string: specRepoPath) else {
      fatalError("\(specRepoPath) does not exist.")
    }
    let podDirPath = specRepoURL.appendingPathComponent(podName).appendingPathComponent(version)
    if !FileManager.default.fileExists(atPath: podDirPath.absoluteString) {
      do {
        print("create path: \(podDirPath.absoluteString)")
        try FileManager.default.createDirectory(atPath: podDirPath.absoluteString,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
      } catch {
        print(error.localizedDescription)
      }
    }
    return podDirPath
  }
}

extension String: Error {
  /// Returns an array of matching groups, which contains matched string and
  /// subgroups.
  ///
  /// - Parameters:
  ///   - regex: A string of regex.
  /// - Returns: An array of array containing each match and its subgroups.
  func match(regex: String) throws -> [[String]] {
    do {
      let regex = try NSRegularExpression(pattern: regex, options: [])
      let nsString = self as NSString
      let results = regex.matches(
        in: self,
        options: [],
        range: NSMakeRange(0, nsString.length)
      )
      return results.map { result in
        (0 ..< result.numberOfRanges).map {
          nsString.substring(with: result.range(at: $0))
        }
      }
    } catch {
      fatalError("regex is invalid\n\(error.localizedDescription)")
    }
  }
}
