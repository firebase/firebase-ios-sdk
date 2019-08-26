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

  /// Returns a Boolean value that indicates whether a directory exists at a specified path.
  func directoryExists(at url: URL) -> Bool
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
    case carthageDir
    case customSpecRepos
    case existingVersions
    case outputDir
    case releasingSDKs
    case rc
    case templateDir
    case updatePodRepo

    /// Usage description for the key.
    var usage: String {
      switch self {
      case .carthageDir:
        return "The directory pointing to all Carthage JSON manifests. Passing this flag enables" +
          "the Carthage build."
      case .customSpecRepos:
        return "A comma separated list of custom CocoaPod Spec repos."
      case .existingVersions:
        return "The file path to a textproto file containing the existing released SDK versions, " +
          "of type `ZipBuilder_FirebaseSDKs`."
      case .outputDir:
        return "The directory to copy the built Zip file to."
      case .rc:
        return "The release candidate number, zero indexed."
      case .releasingSDKs:
        return "The file path to a textproto file containing all the releasing SDKs, of type " +
          "`ZipBuilder_Release`."
      case .templateDir:
        return "The path to the directory containing the blank xcodeproj and Info.plist for " +
          "building source based frameworks"
      case .updatePodRepo:
        return "A flag to run `pod repo update` before building the zip file."
      }
    }
  }

  /// A file URL to a textproto with the contents of a `ZipBuilder_FirebaseSDKs` object. Used to
  /// verify expected version numbers.
  let allSDKsPath: URL?

  /// The directory pointing to all Carthage JSON manifests. Passing this flag enables the Carthage
  /// build.
  let carthageDir: URL?

  /// A file URL to a textproto with the contents of a `ZipBuilder_Release` object. Used to verify
  /// expected version numbers.
  let currentReleasePath: URL?

  /// Custom CocoaPods spec repos to be used. If not provided, the tool will only use the CocoaPods
  /// master repo.
  let customSpecRepos: [URL]?

  /// The directory to copy the built Zip file to. If this is not set, the path to the Zip file will
  /// just be logged to the console.
  let outputDir: URL?

  /// The path to the directory containing the blank xcodeproj and Info.plist for building source
  /// based frameworks.
  let templateDir: URL

  /// The release candidate number, zero indexed.
  let rcNumber: Int?

  /// A flag to update the Pod Repo or not.
  let updatePodRepo: Bool

  /// Initializes with values pulled from the instance of UserDefaults passed in.
  ///
  /// - Parameters:
  ///   - defaults: User defaults containing launch arguments. Defaults to `standard`.
  ///   - fileChecker: An object that can check if a file exists or not. Defaults to
  ///                  `FileManager.default`.
  init(userDefaults defaults: UserDefaults = UserDefaults.standard,
       fileChecker: FileChecker = FileManager.default) {
    // Override default values for specific keys.
    //   - Always run `pod repo update` unless explicitly set to false.
    defaults.register(defaults: [Key.updatePodRepo.rawValue: true])

    // Get the project template directory, and fail if it doesn't exist.
    guard let templatePath = defaults.string(forKey: Key.templateDir.rawValue) else {
      LaunchArgs.exitWithUsageAndLog("Missing required key: `\(Key.templateDir)` for the folder " +
        "containing all required files to build frameworks.")
    }

    templateDir = URL(fileURLWithPath: templatePath)

    // Parse the existing versions key.
    if let existingVersions = defaults.string(forKey: Key.existingVersions.rawValue) {
      let url = URL(fileURLWithPath: existingVersions)
      guard fileChecker.fileExists(atPath: url.path) else {
        LaunchArgs.exitWithUsageAndLog("Could not parse \(Key.existingVersions) key: value " +
          "passed in is not a file URL or the file does not exist. Value: \(existingVersions)")
      }

      allSDKsPath = url.standardizedFileURL
    } else {
      // No argument was passed in.
      allSDKsPath = nil
    }

    // Parse the current releases key.
    if let currentRelease = defaults.string(forKey: Key.releasingSDKs.rawValue) {
      let url = URL(fileURLWithPath: currentRelease)
      guard fileChecker.fileExists(atPath: url.path) else {
        LaunchArgs.exitWithUsageAndLog("Could not parse \(Key.releasingSDKs) key: value passed " +
          "in is not a file URL or the file does not exist. Value: \(currentRelease)")
      }

      currentReleasePath = url.standardizedFileURL
    } else {
      // No argument was passed in.
      currentReleasePath = nil
    }

    // Parse the output directory key.
    if let outputPath = defaults.string(forKey: Key.outputDir.rawValue) {
      let url = URL(fileURLWithPath: outputPath)
      guard fileChecker.directoryExists(at: url) else {
        LaunchArgs.exitWithUsageAndLog("Could not parse \(Key.outputDir) key: value " +
          "passed in is not a file URL or the directory does not exist. Value: \(outputPath)")
      }

      outputDir = url.standardizedFileURL
    } else {
      // No argument was passed in.
      outputDir = nil
    }

    // Parse the release candidate number. This should only be used in conjunction with the other
    // release related flags.
    if let rcFlag = defaults.string(forKey: Key.rc.rawValue) {
      guard let parsedFlag = Int(rcFlag) else {
        LaunchArgs.exitWithUsageAndLog("Could not parse \(Key.rc) key: value passed in is not " +
          "an integer. Value: \(rcFlag)")
      }

      rcNumber = parsedFlag
    } else {
      // TEMPORARY REMOVAL: We don't currently pass in the RC to Kokoro, so ignore the missing flag.
      // Check if we have other release related flags. If so, fail since we need an RC number.
//      guard currentReleasePath == nil else {
//        LaunchArgs.exitWithUsageAndLog("Invalid combination of keys: \(Key.rc) must be passed " +
//          "in when specifiying \(Key.releasingSDKs).")
//      }

      rcNumber = nil
    }

    // Parse the custom specs key.
    if let customSpecs = defaults.string(forKey: Key.customSpecRepos.rawValue) {
      // Custom specs are passed in as a comma separated list of URLs. Split the String by each
      // comma and map it to URLs. If any URL is invalid, fail immediately.
      let specs = customSpecs.split(separator: ",").map { (specStr: Substring) -> URL in
        guard let spec = URL(string: String(specStr)) else {
          LaunchArgs.exitWithUsageAndLog("Error parsing specs: \(specStr) is not a valid URL.")
        }

        return spec
      }

      customSpecRepos = specs
    } else {
      // No argument was passed in.
      customSpecRepos = nil
    }

    // Parse the Carthage directory key.
    if let carthagePath = defaults.string(forKey: Key.carthageDir.rawValue) {
      let url = URL(fileURLWithPath: carthagePath)
      guard fileChecker.directoryExists(at: url) else {
        LaunchArgs.exitWithUsageAndLog("Could not parse \(Key.carthageDir) key: value " +
          "passed in is not a file URL or the directory does not exist. Value: \(carthagePath)")
      }

      carthageDir = url.standardizedFileURL
    } else {
      // No argument was passed in.
      carthageDir = nil
    }

    updatePodRepo = defaults.bool(forKey: Key.updatePodRepo.rawValue)
  }

  /// Prints an error that occurred, the proper usage String, and quits the application.
  private static func exitWithUsageAndLog(_ errorText: String) -> Never {
    print(errorText)

    // Loop over all the possible keys and print their description.
    print("Usage: `swift run ZipBuilder [ARGS]` where args are:")
    for option in Key.allCases {
      print("""
      -\(option.rawValue) <VALUE>
          \(option.usage)
      """)
    }

    fatalError("Invalid arguments. See output above for specific error and usage instructions.")
  }
}
