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

/// CocoaPod related utility functions. The enum type is used as a namespace here instead of having
/// root functions, and no cases should be added to it.
public enum CocoaPodUtils {
  // MARK: - Public API

  /// Information associated with an installed pod.
  public struct PodInfo {
    /// Public name of the pod.
    var name: String

    /// The version of the pod.
    var version: String

    /// The location of the pod on disk.
    var installedLocation: URL

    /// A key that can be generated and used for identifying pods due to binary differences.
    var cacheKey: String?

    /// Default initializer. Explicitly declared to take advantage of default arguments.
    init(name: String, version: String, installedLocation: URL, cacheKey: String? = nil) {
      self.name = name
      self.version = version
      self.installedLocation = installedLocation
      self.cacheKey = cacheKey
    }
  }

  /// Executes the `pod cache clean --all` command to remove any cached CocoaPods.
  public static func cleanPodCache() {
    let result = Shell.executeCommandFromScript("pod cache clean --all", outputToConsole: false)
    switch result {
    case let .error(code):
      fatalError("Could not clean the pod cache, the command exited with \(code). Try running the" +
        "command in Terminal to see what's wrong.")
    case .success:
      // No need to do anything else, continue on.
      print("Successfully cleaned pod cache.")
      return
    }
  }

  /// Executes the `pod cache list` command to get the Pods curerntly cached on your machine.
  ///
  /// - Parameter dir: The directory containing all installed pods.
  /// - Returns: A dictionary keyed by the pod name, then by version number.
  public static func listPodCache(inDir dir: URL) -> [String: [String: PodInfo]] {
    let result = Shell.executeCommandFromScript("pod cache list", outputToConsole: false)
    switch result {
    case let .error(code):
      fatalError("Could not list the pod cache in \(dir), the command exited with \(code). Try " +
        "running in Terminal to see what's wrong.")
    case let .success(output):
      return parsePodsCache(output: output.components(separatedBy: "\n"))
    }
  }

  /// Gets metadata from installed Pods. Reads the `Podfile.lock` file and parses it.
  public static func installedPodsInfo(inProjectDir projectDir: URL) -> [PodInfo] {
    // Read from the Podfile.lock to get the installed versions and names.
    let podfileLock: String
    do {
      podfileLock = try String(contentsOf: projectDir.appendingPathComponent("Podfile.lock"))
    } catch {
      fatalError("Could not read contents of `Podfile.lock` to get installed Pod info in " +
        "\(projectDir): \(error)")
    }

    // Get the versions in the format of [PodName: VersionString].
    let versions = loadVersionsFromPodfileLock(contents: podfileLock)

    // Generate an InstalledPod for each Pod found.
    let podsDir = projectDir.appendingPathComponent("Pods")
    var installedPods: [PodInfo] = []
    for (podName, version) in versions {
      let podDir = podsDir.appendingPathComponent(podName)
      guard FileManager.default.directoryExists(at: podDir) else {
        fatalError("Directory for \(podName) doesn't exist at \(podDir) - failed while getting " +
          "information for installed Pods.")
      }

      // Generate the cache key for this framework. We will use the list of subspecs used in the Pod
      // to generate this, since a Pod like GoogleUtilities could build different sources based on
      // what subspecs are included.
      let cacheKey = self.cacheKey(forPod: podName, fromPodfileLock: podfileLock)
      let podInfo = PodInfo(name: podName,
                            version: version,
                            installedLocation: podDir,
                            cacheKey: cacheKey)
      installedPods.append(podInfo)
    }

    return installedPods
  }

  /// Install an array of pods in a specific directory, returning an array of PodInfo for each pod
  /// that was installed.
  @discardableResult
  public static func installPods(_ pods: [CocoaPod],
                                 inDir directory: URL,
                                 customSpecRepos: [URL]? = nil) -> [PodInfo] {
    let fileManager = FileManager.default
    // Ensure the directory exists, otherwise we can't install all subspecs.
    guard fileManager.directoryExists(at: directory) else {
      fatalError("Attempted to install subpecs (\(pods)) in a directory that doesn't exist: " +
        "\(directory)")
    }

    // Ensure there are actual podspecs to install.
    guard !pods.isEmpty else {
      fatalError("Attempted to install an empty array of subspecs")
    }

    // Attempt to write the Podfile to disk.
    do {
      try writePodfile(for: pods, toDirectory: directory, customSpecRepos: customSpecRepos)
    } catch let FileManager.FileError.directoryNotFound(path) {
      fatalError("Failed to write Podfile with pods \(pods) at path \(path)")
    } catch let FileManager.FileError.writeToFileFailed(path, error) {
      fatalError("Failed to write Podfile for all pods at path: \(path), error: \(error)")
    } catch {
      fatalError("Unspecified error writing Podfile for all pods to disk: \(error)")
    }

    // Run pod install on the directory that contains the Podfile and blank Xcode project.
    let result = Shell.executeCommandFromScript("pod _1.5.3_ install", workingDir: directory)
    switch result {
    case let .error(code, output):
      fatalError("""
      `pod install` failed with exit code \(code) while trying to install pods:
      \(pods)

      Output from `pod install`:
      \(output)
      """)
    case let .success(output):
      // Print the output to the console and return the information for all installed pods.
      print(output)
      return installedPodsInfo(inProjectDir: directory)
    }
  }

  /// Load versions of installed Pods from the contents of a `Podfile.lock` file.
  ///
  /// - Parameter contents: The contents of a `Podfile.lock` file.
  /// - Returns: A dictionary with names of the pod for keys and a string representation of the
  ///            version for values.
  public static func loadVersionsFromPodfileLock(contents: String) -> [String: String] {
    // This pattern matches a framework name with its version (two to three components)
    // Examples:
    //  - FirebaseUI/Google (4.1.1):
    //  - GoogleSignIn (4.0.2):

    // Force unwrap the regular expression since we know it will work, it's a constant being passed
    // in. If any changes are made, be sure to run this script to ensure it works.
    let regex = try! NSRegularExpression(pattern: " - (.+) \\((\\d+\\.\\d+\\.?\\d*)\\)",
                                         options: [])
    let quotes = CharacterSet(charactersIn: "\"")
    var frameworks: [String: String] = [:]
    contents.components(separatedBy: .newlines).forEach { line in
      if let (framework, version) = detectVersion(fromLine: line, matching: regex) {
        let coreFramework = framework.components(separatedBy: "/")[0]
        let key = coreFramework.trimmingCharacters(in: quotes)
        frameworks[key] = version
      }
    }
    return frameworks
  }

  public static func updateRepos() {
    let result = Shell.executeCommandFromScript("pod repo update")
    switch result {
    case let .error(_, output):
      fatalError("Command `pod repo update` failed: \(output)")
    case .success:
      return
    }
  }

  // MARK: - Private Helpers

  // Tests the input to see if it matches a CocoaPod framework and its version.
  // Returns the framework and version or nil if match failed.
  // Used to process entries from Podfile.lock

  /// Tests the input and sees if it matches a CocoaPod framework and its version. This is used to
  /// process entries from Podfile.lock.
  ///
  /// - Parameters:
  ///   - input: A line entry from Podfile.lock.
  ///   - regex: The regex to match compared to the input.
  /// - Returns: A tuple of the framework and version, if it can be parsed.
  private static func detectVersion(fromLine input: String,
                                    matching regex: NSRegularExpression) -> (framework: String, version: String)? {
    let matches = regex.matches(in: input, range: NSRange(location: 0, length: input.utf8.count))
    let nsString = input as NSString

    guard let match = matches.first else {
      return nil
    }

    guard match.numberOfRanges == 3 else {
      print("Version number regex matches: expected 3, but found \(match.numberOfRanges).")
      return nil
    }

    let framework = nsString.substring(with: match.range(at: 1)) as String
    let version = nsString.substring(with: match.range(at: 2)) as String

    return (framework, version)
  }

  /// Generates a key representing the unique combination of all subspecs used for that Pod. This is
  /// necessary for Pods like GoogleUtilities, where we will need to include all subspecs as part of
  /// a build. Otherwise we could accidentally use a cached framework that doesn't include all the
  /// code necessary to function.
  ///
  /// - Parameters:
  ///   - framework: The framework being built.
  ///   - podfileLock: The contents of the Podfile.lock for the project.
  /// - Returns: A key to describe the full set of subspecs used to build the framework, or an empty
  ///            String if there were no specific subspecs used.
  private static func cacheKey(forPod podName: String,
                               fromPodfileLock podfileLock: String) -> String? {
    // Ignore the umbrella Firebase pod, cacheing doesn't make sense.
    guard podName != "Firebase" else { return nil }

    // Get the first section of the Podfile containing only Pods installed, the only thing we care
    // about.
    guard let podsInstalled = podfileLock.components(separatedBy: "DEPENDENCIES:").first else {
      fatalError("""
      Could not generate cache key for \(podName) from Podfile.lock contents - is this a valid
      Podfile.lock?
      ---------- Podfile.lock contents ----------
      \(podfileLock)
      -------------------------------------------
      """)
    }

    // Only get the lines that start with "  - ", and have the framework we're looking for since
    // they are the top level pods that are installed.
    // Example result of a single line: `- GoogleUtilities/Environment (~> 5.2)`.
    let lines = podsInstalled.components(separatedBy: .newlines).filter {
      $0.hasPrefix("  - ") && $0.contains(podName)
    }

    // Get a list of all the subspecs used to build this framework, and use that to generate the
    // cache key.
    var uniqueSubspecs = Set<String>()
    for line in lines.sorted() {
      // Separate the line into readable chunks, using a space and quote as a separator.
      // Example result: `["-", "GoogleUtilities/Environment", "(~>", "5.2)"]`.
      let components = line.components(separatedBy: CharacterSet(charactersIn: " \""))

      // The Pod and subspec will be the only variables we care about, filter out the rest.
      // Example result: 'GoogleUtilities/Environment' or `FirebaseCore`. Only Pods with a subspec
      // should be included here, which are always in the format of `PodName/SubspecName`.
      guard let fullPodName = components.filter({ $0.contains("\(podName)/") }).first else {
        continue
      }

      // The fullPodName will be something like `GoogleUtilities/UserDefaults`, get the subspec
      // name.
      let subspec = fullPodName.replacingOccurrences(of: "\(podName)/", with: "")
      if !subspec.isEmpty {
        uniqueSubspecs.insert(subspec)
      }
    }

    // Return nil if there are no subpsecs used, since no cache key is necessary.
    guard !uniqueSubspecs.isEmpty else {
      return nil
    }

    // Assemble the cache key based on the framework name, and all subspecs (sorted alphabetically
    // for repeatability) separated by a `+` (as was previously used).
    return podName + "+" + uniqueSubspecs.sorted().joined(separator: "+")
  }

  /// Create the contents of a Podfile for an array of subspecs. This assumes the array of subspecs
  /// is not empty.
  private static func generatePodfile(for pods: [CocoaPod],
                                      customSpecsRepos: [URL]? = nil) -> String {
    // Get the largest minimum supported iOS version from the array of subspecs.
    let minVersions = pods.map { $0.minSupportedIOSVersion() }

    // Get the maximum version out of all the minimum versions supported.
    guard let largestMinVersion = minVersions.max() else {
      // This shouldn't happen, but in the interest of completeness quit the script and describe
      // how this could be fixed.
      fatalError("""
      Could not retrieve the largest minimum iOS version for the Podfile - array of subspecs
      to install is likely empty. This is likely a programmer error - no function should be
      calling \(#function) before validating that the subspecs array is not empty.
      """)
    }

    // Start assembling the Podfile.
    var podfile: String = ""

    // If custom Specs repos were passed in, prefix the Podfile with the custom repos followed by
    // the CocoaPods master Specs repo.
    if let customSpecsRepos = customSpecsRepos {
      let reposText = customSpecsRepos.map { "source '\($0)'" }
      podfile += """
      \(reposText.joined(separator: "\n"))
      source 'https://github.com/CocoaPods/Specs.git'

      """ // Explicit newline above to ensure it's included in the String.
    }

    // Include the calculated minimum iOS version.
    podfile += """
    platform :ios, '\(largestMinVersion.podVersion())'
    target 'FrameworkMaker' do\n
    """

    // Loop through the subspecs passed in and use the rawValue (actual Pod name).
    for pod in pods {
      podfile += "  pod '\(pod.podName)'\n"
    }

    podfile += "end"
    return podfile
  }

  /// Parse the output from Pods Cache
  private static func parsePodsCache(output: [String]) -> [String: [String: PodInfo]] {
    var podName: String?
    var podVersion: String?

    var podsCache: [String: [String: PodInfo]] = [:]

    for line in output {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      let parts = trimmedLine.components(separatedBy: ":")
      if trimmedLine.hasSuffix(":") {
        podName = parts[0]
      } else {
        guard parts.count == 2 else { continue }
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts[1].trimmingCharacters(in: .whitespaces)

        switch key {
        case "- Version":
          podVersion = value
        case "Pod":
          let podLocation = URL(fileURLWithPath: value)
          let podInfo = PodInfo(name: podName!, version: podVersion!, installedLocation: podLocation)
          if podsCache[podName!] == nil {
            podsCache[podName!] = [:]
          }
          podsCache[podName!]![podVersion!] = podInfo

        default:
          break
        }
      }
    }

    return podsCache
  }

  /// Write a podfile that contains all the pods passed in to the directory passed in with a name
  /// "Podfile".
  private static func writePodfile(for pods: [CocoaPod],
                                   toDirectory directory: URL,
                                   customSpecRepos: [URL]?) throws {
    guard FileManager.default.directoryExists(at: directory) else {
      // Throw an error so the caller can provide a better error message.
      throw FileManager.FileError.directoryNotFound(path: directory.path)
    }

    // Generate the full path of the Podfile and attempt to write it to disk.
    let path = directory.appendingPathComponent("Podfile")
    let podfile = generatePodfile(for: pods, customSpecsRepos: customSpecRepos)
    do {
      try podfile.write(toFile: path.path, atomically: true, encoding: .utf8)
    } catch {
      throw FileManager.FileError.writeToFileFailed(file: path.path, error: error)
    }
  }
}
