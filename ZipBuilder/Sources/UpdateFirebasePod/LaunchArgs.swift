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

/// Describes an object that can check if a file eists in the filesystem. Used to allow for better
/// testing with FileManager.
protocol FileChecker {
  /// Returns a Boolean value that indicates whether a file or directory exists at a specified path.
  /// This matches the `FileManager` API.
  func fileExists(atPath: String) -> Bool
}

// Make FileManager a FileChecker. This is empty since FileManager already provides this
// functionality (natively and through our extensions).
extension FileManager: FileChecker {}

// TODO: Evaluate if we should switch to Swift Package Manager's internal `Utility` module that
//       contains `ArgumentParser`. No immediate need, but provides some nice benefits.
/// LaunchArgs reads from UserDefaults to assemble all launch arguments coming from the command line
/// or the Xcode scheme. UserDefaults contains all launch arguments that are in the format of:
/// `-myKey myValue`.
struct LaunchArgs {
  /// Keys associated with the launch args. See `Usage` for descriptions of each flag.
  private enum Key: String, CaseIterable {
    case gitRoot
    case releasingPods

    /// Usage description for the key.
    var usage: String {
      switch self {
      case .gitRoot:
        return "The root of the firebase-ios-sdk checked out git repo."
      case .releasingPods:
        return "The file path to a textproto file containing all the releasing Pods, of type."
      }
    }
  }

  /// A file URL to a textproto with the contents of a `FirebasePod_Release` object. Used to verify
  /// expected version numbers.
  let currentReleasePath: URL

  /// A file URL to the checked out gitRepo to update
  let gitRootPath: String

  /// The shared instance for processing launch args using default arguments.
  static let shared: LaunchArgs = LaunchArgs()

  /// Initializes with values pulled from the instance of UserDefaults passed in.
  ///
  /// - Parameters:
  ///   - defaults: User defaults containing launch arguments. Defaults to `standard`.
  ///   - fileChecker: An object that can check if a file exists or not. Defaults to
  ///                  `FileManager.default`.
  init(userDefaults defaults: UserDefaults = UserDefaults.standard,
       fileChecker: FileChecker = FileManager.default) {
    // Parse the current releases key.
    guard let currentRelease = defaults.string(forKey: Key.releasingPods.rawValue) else {
      LaunchArgs.exitWithUsageAndLog("Missing required key: `\(Key.releasingPods)` for the file " +
        "containing the list of releasing pods and versions.")
    }
    let url = URL(fileURLWithPath: currentRelease)
    guard fileChecker.fileExists(atPath: url.path) else {
      LaunchArgs.exitWithUsageAndLog("Could not parse \(Key.releasingPods) key: value passed " +
        "in is not a file URL or the file does not exist. Value: \(currentRelease)." +
        " Do you need to run prodaccess?")
    }
    currentReleasePath = url.standardizedFileURL

    // Parse the gitRoot key.
    guard let gitRoot = defaults.string(forKey: Key.gitRoot.rawValue) else {
      LaunchArgs.exitWithUsageAndLog("Missing required key: `\(Key.gitRoot)` for the path " +
        "of the checked out git repo.")
    }

    let gitUrl = URL(fileURLWithPath: gitRoot)
    guard fileChecker.fileExists(atPath: gitUrl.path) else {
      LaunchArgs.exitWithUsageAndLog("Could not parse \(Key.gitRoot) key: value passed " +
        "in is not a file URL or the file does not exist. Value: \(gitRoot)")
    }
    gitRootPath = gitRoot
  }

  /// Prints an error that occurred, the proper usage String, and quits the application.
  private static func exitWithUsageAndLog(_ errorText: String) -> Never {
    print(errorText)

    // Loop over all the possible keys and print their description.
    print("Usage: `swift run FirebasePod [ARGS]` where args are:")
    for option in Key.allCases {
      print("""
      -\(option.rawValue) <VALUE>
          \(option.usage)
      """)
    }
    fatalError("Invalid arguments. See output above for specific error and usage instructions.")
  }
}
