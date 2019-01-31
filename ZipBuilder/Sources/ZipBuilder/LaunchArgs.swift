import Foundation

/// Describes an object that can check if a file eists in the filesystem. Used to allow for better
/// testing with FileManager.
protocol FileChecker {
  /// Returns a Boolean value that indicates whether a file or directory exists at a specified path.
  func fileExists(atPath: String) -> Bool
}

// Make FileManager a FileChecker. This is empty since FileManager already provides this function.
extension FileManager: FileChecker {}

// TODO: Evaluate if we should switch to Swift Package Manager's internal `Utility` module that
//       contains `ArgumentParser`. No immediate need, but provides some nice benefits.
/// LaunchArgs reads from UserDefaults to assemble all launch arguments coming from the command line
/// or the Xcode scheme. UserDefaults contains all launch arguments that are in the format of:
/// `-myKey myValue`.
struct LaunchArgs {
  /// Keys associated with the launch args. See `Usage` for descriptions of each flag.
  private enum Key: String {
    case cacheEnabled
    case customSpecRepos
    case coreDiagnosticsDir
    case debugMode
    case deleteCache
    case existingVersions
    case releasingSDKs
    case templateDir
    case updatePodRepo

    /// Usage description for the key.
    var usage: String {
      switch self {
      case .cacheEnabled:
        return "A flag to control using the cache for frameworks."
      case .coreDiagnosticsDir:
        return "The path to the `CoreDiagnostics.framework` file built with the Zip flag enabled."
      case .customSpecRepos:
        return "A comma separated list of custom CocoaPod Spec repos."
      case .debugMode:
        return "A flag to enable debug mode. Pass in `true/false`, `YES/NO`, or `1/0`."
      case .deleteCache:
        return "A flag to empty the cache. Note: if this flag and the `cacheEnabled` flag is " +
        "set, it will fail since that's probably unintended."
      case .existingVersions:
        return "The file path to a textproto file containing the existing released SDK versions, " +
        "of type `ZipBuilder_FirebaseSDKs`."
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

    // TODO: Once we default to Swift 4.2 (in Xcode 10) we can conform to "CaseIterable" protocol to
    //       automatically generate this method.
    /// All the subspecs to parse.
    static func allCases() -> [Key] {
      return [.cacheEnabled,
              .coreDiagnosticsDir,
              .customSpecRepos,
              .debugMode,
              .deleteCache,
              .existingVersions,
              .releasingSDKs,
              .templateDir,
              .updatePodRepo]
    }
  }

  /// A file URL to a textproto with the contents of a `ZipBuilder_FirebaseSDKs` object. Used to
  /// verify expected version numbers.
  let allSDKsPath: URL?

  /// The path to the `CoreDiagnostics.framework` file built with the Zip flag enabled.
  let coreDiagnosticsDir: URL

  /// A file URL to a textproto with the contents of a `ZipBuilder_Release` object. Used to verify
  /// expected version numbers.
  let currentReleasePath: URL?

  /// Custom CocoaPods spec repos to be used. If not provided, the tool will only use the CocoaPods
  /// master repo.
  let customSpecRepos: [URL]?

  /// The path to the directory containing the blank xcodeproj and Info.plist for building source
  /// based frameworks.
  let templateDir: URL

  /// A flag to control using the cache for frameworks.
  let cacheEnabled: Bool

  /// A flag to delete the cache from the cache directory.
  let deleteCache: Bool

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
    // Get the project template directory, and fail if it doesn't exist.
    guard let templatePath = defaults.string(forKey: Key.templateDir.rawValue) else {
      LaunchArgs.exitWithUsageAndLog("Missing required \(Key.templateDir) key for the folder " +
        "containing all required files to build frameworks.")
    }

    templateDir = URL(fileURLWithPath: templatePath)

    // Parse the path to CoreDiagnostics.framework.
    guard let diagnosticsPath = defaults.string(forKey: Key.coreDiagnosticsDir.rawValue) else {
      LaunchArgs.exitWithUsageAndLog("Missing required \(Key.coreDiagnosticsDir) key for the " +
        "path to the CoreDiagnostics framework.")
    }

    coreDiagnosticsDir = URL(fileURLWithPath: diagnosticsPath)

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
      currentReleasePath =  nil
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

    updatePodRepo = defaults.bool(forKey: Key.updatePodRepo.rawValue)

    // Parse the cache keys. If no value is provided for each, it defaults to `false`.
    cacheEnabled = defaults.bool(forKey: Key.cacheEnabled.rawValue)
    deleteCache = defaults.bool(forKey: Key.deleteCache.rawValue)

    if deleteCache && cacheEnabled {
      LaunchArgs.exitWithUsageAndLog("Invalid pair - attempted to delete the cache and enable " +
        "it at the same time. Please remove on of the keys and try " +
        "again.")
    }
  }

  /// Prints an error that occurred, the proper usage String, and quits the application.
  private static func exitWithUsageAndLog(_ errorText: String) -> Never {
    print(errorText)

    // Loop over all the possible keys and print their description.
    print("Usage: `swift run ZipBuilder [ARGS]` where args are:")
    for option in Key.allCases() {
      print("""
        -\(option.rawValue) <VALUE>
            \(option.usage)
        """)
    }

    fatalError("Invalid arguments. See output above for specific error and usage instructions.")
  }
}
