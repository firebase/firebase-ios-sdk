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
import FirebaseManifest

/// CocoaPod related utility functions. The enum type is used as a namespace here instead of having
/// root functions, and no cases should be added to it.
enum CocoaPodUtils {
  /// The linkage type to specify for CocoaPods installation.
  enum LinkageType {
    /// Forced static libraries. Uses `use_modular_headers!` in the Podfile. Required for module map
    /// generation
    case forcedStatic

    /// Dynamic frameworks. Uses `use_frameworks!` in the Podfile.
    case dynamic

    /// Static frameworks. Uses `use_frameworks! :linkage => :static` in the Podfile. Enum case is
    /// prefixed with `standard` to avoid the `static` keyword.
    case standardStatic
  }

  // MARK: - Public API

  // Codable is required because Decodable does not make CodingKeys available.
  struct VersionedPod: Codable, CustomDebugStringConvertible {
    /// Public name of the pod.
    let name: String

    /// The version of the requested pod.
    let version: String?

    /// Platforms supported
    let platforms: Set<String>

    init(name: String,
         version: String?,
         platforms: Set<String> = ["ios", "macos", "tvos"]) {
      self.name = name
      self.version = version
      self.platforms = platforms
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      name = try container.decode(String.self, forKey: .name)
      if let platforms = try container.decodeIfPresent(Set<String>.self, forKey: .platforms) {
        self.platforms = platforms
      } else {
        platforms = ["ios", "macos", "tvos"]
      }
      if let version = try container.decodeIfPresent(String.self, forKey: .version) {
        self.version = version
      } else {
        version = nil
      }
    }

    /// The debug description as required by `CustomDebugStringConvertible`.
    var debugDescription: String {
      var desc = name
      if let version = version {
        desc.append(" v\(version)")
      }

      return desc
    }
  }

  /// Information associated with an installed pod.
  /// This is a class so that moduleMapContents can be updated via reference.
  class PodInfo {
    /// The version of the generated pod.
    let version: String

    /// The pod dependencies.
    let dependencies: [String]

    /// The location of the pod on disk.
    let installedLocation: URL

    /// Source pod flag.
    let isSourcePod: Bool

    /// Binary frameworks in this pod.
    let binaryFrameworks: [URL]

    /// Subspecs installed for this pod.
    let subspecs: Set<String>

    /// The contents of the module map for all frameworks associated with the pod.
    var moduleMapContents: ModuleMapBuilder.ModuleMapContents?

    init(version: String,
         dependencies: [String],
         installedLocation: URL,
         subspecs: Set<String>,
         localPodspecPath: URL?) {
      self.version = version
      self.dependencies = dependencies
      self.installedLocation = installedLocation
      self.subspecs = subspecs

      // Get all the frameworks contained in this directory.
      var binaryFrameworks: [URL] = []
      if installedLocation != localPodspecPath {
        do {
          binaryFrameworks = try FileManager.default.recursivelySearch(for: .frameworks,
                                                                       in: installedLocation)
        } catch {
          fatalError("Cannot search for .framework files in Pods directory " +
            "\(installedLocation): \(error)")
        }
      }
      self.binaryFrameworks = binaryFrameworks
      isSourcePod = binaryFrameworks == []
    }
  }

  /// Executes the `pod cache clean --all` command to remove any cached CocoaPods.
  static func cleanPodCache() {
    let result = Shell.executeCommandFromScript("pod cache clean --all", outputToConsole: false)
    switch result {
    case let .error(code, _):
      fatalError("Could not clean the pod cache, the command exited with \(code). Try running the" +
        "command in Terminal to see what's wrong.")
    case .success:
      // No need to do anything else, continue on.
      print("Successfully cleaned pod cache.")
      return
    }
  }

  /// Gets metadata from installed Pods. Reads the `Podfile.lock` file and parses it.
  static func installedPodsInfo(inProjectDir projectDir: URL,
                                localPodspecPath: URL?) -> [String: PodInfo] {
    // Read from the Podfile.lock to get the installed versions and names.
    let podfileLock: String
    do {
      podfileLock = try String(contentsOf: projectDir.appendingPathComponent("Podfile.lock"))
    } catch {
      fatalError("Could not read contents of `Podfile.lock` to get installed Pod info in " +
        "\(projectDir): \(error)")
    }

    // Get the pods in the format of [PodInfo].
    return loadPodInfoFromPodfileLock(contents: podfileLock,
                                      inProjectDir: projectDir,
                                      localPodspecPath: localPodspecPath)
  }

  /// Install an array of pods in a specific directory, returning a dictionary of PodInfo for each pod
  /// that was installed.
  /// - Parameters:
  ///   - pods: List of VersionedPods to install
  ///   - directory: Destination directory for the pods.
  ///   - platform: Install for one platform at a time.
  ///   - customSpecRepos: Additional spec repos to check for installation.
  ///   - linkage: Specifies the linkage type. When `forcedStatic` is used, for the module map
  ///        construction, we want pod names not module names in the generated OTHER_LD_FLAGS
  ///        options.
  /// - Returns: A dictionary of PodInfo's keyed by the pod name.
  @discardableResult
  static func installPods(_ pods: [VersionedPod],
                          inDir directory: URL,
                          platform: Platform,
                          customSpecRepos: [URL]?,
                          localPodspecPath: URL?,
                          linkage: LinkageType) -> [String: PodInfo] {
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
      try writePodfile(for: pods,
                       toDirectory: directory,
                       customSpecRepos: customSpecRepos,
                       platform: platform,
                       localPodspecPath: localPodspecPath,
                       linkage: linkage)
    } catch let FileManager.FileError.directoryNotFound(path) {
      fatalError("Failed to write Podfile with pods \(pods) at path \(path)")
    } catch let FileManager.FileError.writeToFileFailed(path, error) {
      fatalError("Failed to write Podfile for all pods at path: \(path), error: \(error)")
    } catch {
      fatalError("Unspecified error writing Podfile for all pods to disk: \(error)")
    }

    // Run pod install on the directory that contains the Podfile and blank Xcode project.
    checkCocoaPodsVersion(directory: directory)
    let result = Shell.executeCommandFromScript("pod install", workingDir: directory)
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
      return installedPodsInfo(inProjectDir: directory, localPodspecPath: localPodspecPath)
    }
  }

  /// Load installed Pods from the contents of a `Podfile.lock` file.
  ///
  /// - Parameter contents: The contents of a `Podfile.lock` file.
  /// - Returns: A dictionary of PodInfo structs keyed by the pod name.
  static func loadPodInfoFromPodfileLock(contents: String,
                                         inProjectDir projectDir: URL,
                                         localPodspecPath: URL?) -> [String: PodInfo] {
    // This pattern matches a pod name with its version (two to three components)
    // Examples:
    //  - FirebaseUI/Google (4.1.1):
    //  - GoogleSignIn (4.0.2):

    // Force unwrap the regular expression since we know it will work, it's a constant being passed
    // in. If any changes are made, be sure to run this script to ensure it works.
    let depRegex: NSRegularExpression = try! NSRegularExpression(pattern: " - (.+).*",
                                                                 options: [])
    let quotes = CharacterSet(charactersIn: "\"")
    var pods: [String: String] = [:]
    var deps: [String: Set<String>] = [:]
    var currentPod: String?
    for line in contents.components(separatedBy: .newlines) {
      if line.starts(with: "DEPENDENCIES:") {
        break
      }
      if let (pod, version) = detectVersion(fromLine: line) {
        currentPod = pod.trimmingCharacters(in: quotes)
        pods[currentPod!] = version
      } else if let currentPod = currentPod {
        let matches = depRegex
          .matches(in: line, range: NSRange(location: 0, length: line.utf8.count))
        // Match something like - GTMSessionFetcher/Full (= 1.3.0)
        if let match = matches.first {
          let depLine = (line as NSString).substring(with: match.range(at: 0)) as String
          // Split spaces and subspecs.
          let dep = depLine.components(separatedBy: [" "])[2].trimmingCharacters(in: quotes)
          if dep != currentPod {
            deps[currentPod, default: Set()].insert(dep)
          }
        }
      }
    }
    // Organize the subspecs
    var versions: [String: String] = [:]
    var subspecs: [String: Set<String>] = [:]

    for (podName, version) in pods {
      let subspecArray = podName.components(separatedBy: "/")
      if subspecArray.count == 1 || subspecArray[0] == "abseil" {
        // Special case for abseil since it has two layers and no external deps.
        versions[subspecArray[0]] = version
      } else if subspecArray.count > 2 {
        fatalError("Multi-layered subspecs are not supported - \(podName)")
      } else {
        if let previousVersion = versions[podName], version != previousVersion {
          fatalError("Different installed versions for \(podName)." +
            "\(version) versus \(previousVersion)")
        } else {
          let basePodName = subspecArray[0]
          versions[basePodName] = version
          subspecs[basePodName, default: Set()].insert(subspecArray[1])
          deps[basePodName] = deps[basePodName, default: Set()].union(deps[podName] ?? Set())
        }
      }
    }

    // Generate an InstalledPod for each Pod found.
    let podsDir = projectDir.appendingPathComponent("Pods")
    var installedPods: [String: PodInfo] = [:]
    for (podName, version) in versions {
      var podDir = podsDir.appendingPathComponent(podName)
      // Make sure that pod got installed if it's not coming from a local podspec.
      if !FileManager.default.directoryExists(at: podDir) {
        guard let repoDir = localPodspecPath else {
          fatalError("Directory for \(podName) doesn't exist at \(podDir) - failed while getting " +
            "information for installed Pods.")
        }
        podDir = repoDir
      }
      let dependencies = [String](deps[podName] ?? [])
      let podInfo = PodInfo(version: version,
                            dependencies: dependencies,
                            installedLocation: podDir,
                            subspecs: subspecs[podName] ?? Set(),
                            localPodspecPath: localPodspecPath)
      installedPods[podName] = podInfo
    }
    return installedPods
  }

  static func updateRepos() {
    let result = Shell.executeCommandFromScript("pod repo update")
    switch result {
    case let .error(_, output):
      fatalError("Command `pod repo update` failed: \(output)")
    case .success:
      return
    }
  }

  static func podInstallPrepare(inProjectDir projectDir: URL, templateDir: URL) {
    do {
      // Create the directory and all intermediate directories.
      try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
    } catch {
      // Use `do/catch` instead of `guard let tempDir = try?` so we can print the error thrown.
      fatalError("Cannot create temporary directory at beginning of script: \(error)")
    }
    // Copy the Xcode project needed in order to be able to install Pods there.
    let templateFiles = Constants.ProjectPath.requiredFilesForBuilding.map {
      templateDir.appendingPathComponent($0)
    }
    for file in templateFiles {
      // Each file should be copied to the temporary project directory with the same name.
      let destination = projectDir.appendingPathComponent(file.lastPathComponent)
      do {
        if !FileManager.default.fileExists(atPath: destination.path) {
          print("Copying template file \(file) to \(destination)...")
          try FileManager.default.copyItem(at: file, to: destination)
        }
      } catch {
        fatalError("Could not copy template project to temporary directory in order to install " +
          "pods. Failed while attempting to copy \(file) to \(destination). \(error)")
      }
    }
  }

  /// Get all transitive pod dependencies for a pod.
  /// - Returns: An array of Strings of pod names.
  static func transitivePodDependencies(for podName: String,
                                        in installedPods: [String: PodInfo]) -> [String] {
    var newDeps = Set([podName])
    var returnDeps = Set<String>()
    repeat {
      var foundDeps = Set<String>()
      for dep in newDeps {
        let childDeps = installedPods[dep]?.dependencies ?? []
        foundDeps.formUnion(Set(childDeps))
      }
      newDeps = foundDeps.subtracting(returnDeps)
      returnDeps.formUnion(newDeps)
    } while newDeps.count > 0
    return Array(returnDeps)
  }

  /// Get all transitive pod dependencies for a pod with subspecs merged.
  /// - Returns: An array of Strings of pod names.
  static func transitiveMasterPodDependencies(for podName: String,
                                              in installedPods: [String: PodInfo]) -> [String] {
    return Array(Set(transitivePodDependencies(for: podName, in: installedPods).map {
      $0.components(separatedBy: "/")[0]
    }))
  }

  /// Get all transitive pod dependencies for a pod.
  /// - Returns: An array of dependencies with versions for a given pod.
  static func transitiveVersionedPodDependencies(for podName: String,
                                                 in installedPods: [String: PodInfo])
    -> [VersionedPod] {
    return transitivePodDependencies(for: podName, in: installedPods).map {
      var podVersion: String?
      if let version = installedPods[$0]?.version {
        podVersion = version
      } else {
        // See if there's a version on the base pod.
        let basePod = String($0.split(separator: "/")[0])
        podVersion = installedPods[basePod]?.version
      }
      return CocoaPodUtils.VersionedPod(name: $0, version: podVersion)
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
  /// - Returns: A tuple of the framework and version, if it can be parsed.
  private static func detectVersion(fromLine input: String)
    -> (framework: String, version: String)? {
    // Get the components of the line to parse them individually. Ignore any whitespace only Strings.
    let components = input.components(separatedBy: " ").filter { !$0.isEmpty }

    // Expect three components: the `-`, the pod name, and the version in parens. This will filter out
    // dependencies that have version requirements like `(~> 3.2.1)` in it.
    guard components.count == 3 else { return nil }

    // The first component is simple, just the `-`.
    guard components.first == "-" else { return nil }

    // The second component is a pod/framework name, which we want to return eventually. Remove any
    // extraneous quotes.
    let framework = components[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))

    // The third component is the version in parentheses, potentially with a `:` at the end. Let's
    // just strip the unused characters (including quotes) and return the version. We don't
    // necesarily have to match against semver since it's a non trivial regex and we don't actually
    // care, `Podfile.lock` has a standard format that we know will be valid. Also strip out any
    // extra quotes.
    let version = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "():\""))

    return (framework, version)
  }

  /// Create the contents of a Podfile for an array of subspecs. This assumes the array of subspecs
  /// is not empty.
  private static func generatePodfile(for pods: [VersionedPod],
                                      customSpecsRepos: [URL]?,
                                      platform: Platform,
                                      localPodspecPath: URL?,
                                      linkage: LinkageType) -> String {
    // Start assembling the Podfile.
    var podfile: String = ""

    // If custom Specs repos were passed in, prefix the Podfile with the custom repos followed by
    // the CocoaPods master Specs repo.
    if let customSpecsRepos = customSpecsRepos {
      let reposText = customSpecsRepos.map { "source '\($0)'" }
      podfile += """
      \(reposText.joined(separator: "\n"))
      source 'https://cdn.cocoapods.org/'

      """ // Explicit newline above to ensure it's included in the String.
    }

    switch linkage {
    case .forcedStatic:
      podfile += "  use_modular_headers!\n"
    case .dynamic:
      podfile += "  use_frameworks!\n"
    case .standardStatic:
      podfile += "  use_frameworks! :linkage => :static\n"
    }

    // Include the platform and its minimum version.
    podfile += """
    platform :\(platform.name), '\(platform.minimumVersion)'
    target 'FrameworkMaker' do\n
    """

    var versionsSpecified = false
    let firebaseVersion = FirebaseManifest.shared.version
    let versionChunks = firebaseVersion.split(separator: ".")
    let minorVersion = "\(versionChunks[0]).\(versionChunks[1]).0"

    // Loop through the subspecs passed in and use the actual Pod name.
    for pod in pods {
      let podspec = String(pod.name.split(separator: "/")[0] + ".podspec")
      // Check if we want to use a local version of the podspec.
      if let localURL = localPodspecPath,
        FileManager.default.fileExists(atPath: localURL.appendingPathComponent(podspec).path) {
        podfile += "  pod '\(pod.name)', :path => '\(localURL.path)'"
      } else if let podVersion = pod.version {
        // To support Firebase patch versions in the Firebase zip distribution, allow patch updates
        // for all pods except Firebase and FirebaseCore. The Firebase Swift pods are not yet in the
        // zip distribution.
        var podfileVersion = podVersion
        if pod.name.starts(with: "Firebase"),
          !pod.name.hasSuffix("Swift"),
          pod.name != "Firebase",
          pod.name != "FirebaseCore" {
          podfileVersion = podfileVersion.replacingOccurrences(
            of: firebaseVersion,
            with: minorVersion
          )
          podfileVersion = "~> \(podfileVersion)"
        }
        podfile += "  pod '\(pod.name)', '\(podfileVersion)'"
      } else if pod.name.starts(with: "Firebase"),
        let localURL = localPodspecPath,
        FileManager.default
        .fileExists(atPath: localURL.appendingPathComponent("Firebase.podspec").path) {
        // Let Firebase.podspec force the right version for unspecified closed Firebase pods.
        let podString = pod.name.replacingOccurrences(of: "Firebase", with: "")
        podfile += "  pod 'Firebase/\(podString)', :path => '\(localURL.path)'"
      } else {
        podfile += "  pod '\(pod.name)'"
      }
      if pod.version != nil {
        // Don't add Google pods if versions were specified or we're doing a secondary install
        // to create module maps.
        versionsSpecified = true
      }
      podfile += "\n"
    }

    // If we're using local pods, explicitly add FirebaseInstallations,
    // and any Google* podspecs if they exist and there are no explicit versions in the Podfile.
    // Note there are versions for local podspecs if we're doing the secondary install for module
    // map building.
    if !versionsSpecified, let localURL = localPodspecPath {
      let podspecs = try! FileManager.default.contentsOfDirectory(atPath: localURL.path)
      for podspec in podspecs {
        if podspec == "FirebaseInstallations.podspec" ||
          podspec == "FirebaseCoreDiagnostics.podspec" ||
          podspec == "FirebaseCore.podspec" ||
          podspec == "FirebaseRemoteConfig.podspec" ||
          podspec == "FirebaseABTesting.podspec" {
          let podName = podspec.replacingOccurrences(of: ".podspec", with: "")
          podfile += "  pod '\(podName)', :path => '\(localURL.path)/\(podspec)'\n"
        }
      }
    }
    podfile += "end"
    return podfile
  }

  /// Write a podfile that contains all the pods passed in to the directory passed in with a name
  /// "Podfile".
  private static func writePodfile(for pods: [VersionedPod],
                                   toDirectory directory: URL,
                                   customSpecRepos: [URL]?,
                                   platform: Platform,
                                   localPodspecPath: URL?,
                                   linkage: LinkageType) throws {
    guard FileManager.default.directoryExists(at: directory) else {
      // Throw an error so the caller can provide a better error message.
      throw FileManager.FileError.directoryNotFound(path: directory.path)
    }

    // Generate the full path of the Podfile and attempt to write it to disk.
    let path = directory.appendingPathComponent("Podfile")
    let podfile = generatePodfile(for: pods,
                                  customSpecsRepos: customSpecRepos,
                                  platform: platform,
                                  localPodspecPath: localPodspecPath,
                                  linkage: linkage)
    do {
      try podfile.write(toFile: path.path, atomically: true, encoding: .utf8)
    } catch {
      throw FileManager.FileError.writeToFileFailed(file: path.path, error: error)
    }
  }

  private static var checkedCocoaPodsVersion = false

  /// At least 1.9.0 is required for `use_frameworks! :linkage => :static`
  /// - Parameters:
  ///   - directory: Destination directory for the pods.
  private static func checkCocoaPodsVersion(directory: URL) {
    if checkedCocoaPodsVersion {
      return
    }
    checkedCocoaPodsVersion = true
    let podVersion = Shell.executeCommandFromScript("pod --version", workingDir: directory)
    switch podVersion {
    case let .error(code, output):
      fatalError("""
      `pod --version` failed with exit code \(code)
      Output from `pod --version`:
      \(output)
      """)
    case let .success(output):
      let version = output.components(separatedBy: ".")
      guard version.count >= 2 else {
        fatalError("Failed to parse CocoaPods version: \(version)")
      }

      let major = Int(version[0])
      guard let minor = Int(version[1]) else {
        fatalError("Failed to parse minor version from \(version)")
      }

      if major == 1, minor < 9 {
        fatalError("CocoaPods version must be at least 1.9.0. Using \(output)")
      }
    }
  }
}
