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

import ArgumentParser
import Foundation

// Enables parsing of URLs as command line arguments.
extension URL: ExpressibleByArgument {
  public init?(argument: String) {
    self.init(string: argument)
  }
}

// Enables parsing of platforms as a command line argument.
extension Platform: ExpressibleByArgument {
  public init?(argument: String) {
    // Look for a match in SDK name.
    for platform in Platform.allCases {
      if argument == platform.name {
        self = platform
        return
      }
    }
    return nil
  }
}

struct ZipBuilderTool: ParsableCommand {
  // MARK: - Boolean Flags

  /// Enables or disables building arm64 slices for Apple silicon (simulator, etc).
  @Flag(default: true,
        inversion: .prefixedEnableDisable,
        help: ArgumentHelp("Enables or disables building arm64 slices for Apple silicon Macs."))
  var appleSiliconSupport: Bool

  /// Enables or disables building dependencies of pods.
  @Flag(default: true,
        inversion: .prefixedEnableDisable,
        help: ArgumentHelp("Whether or not to build dependencies of requested pods."))
  var buildDependencies: Bool

  /// Flag to enable or disable Carthage version checks. Skipping the check can speed up dev
  /// iterations.
  @Flag(default: true,
        // Allows `--enable-carthage-version-check` and `--disable-carthage-version-check`.
        inversion: FlagInversion.prefixedEnableDisable,
        help: ArgumentHelp("A flag for enabling or disabling versions checks for Carthage builds."))
  var carthageVersionCheck: Bool

  /// A flag that indicates to build dynamic library frameworks. The default is false and static
  /// linkage.
  @Flag(default: false,
        inversion: .prefixedNo,
        help: ArgumentHelp("A flag specifying to build dynamic library frameworks."))
  var dynamic: Bool

  @Flag(default: false,
        inversion: .prefixedNo,
        help: ArgumentHelp("A flag to indicate keeping (not deleting) the build artifacts."))
  var keepBuildArtifacts: Bool

  /// Flag to skip building the Catalyst slices.
  @Flag(default: true,
        inversion: .prefixedNo,
        help: ArgumentHelp("A flag to indicate skip building the Catalyst slice."))
  var includeCatalyst: Bool

  /// Flag to run `pod repo update` and `pod cache clean --all`.
  @Flag(default: true,
        inversion: .prefixedNo,
        help: ArgumentHelp("""
        A flag to run `pod repo update` and `pod cache clean -all` before building the "zip file".
        """))
  var updatePodRepo: Bool

  // MARK: - CocoaPods Arguments

  /// Custom CocoaPods spec repos to be used.
  @Option(parsing: .upToNextOption,
          help: ArgumentHelp("""
          A list of private CocoaPod Spec repos. If not provided, the tool will only use the \
          CocoaPods master repo.
          """))
  var customSpecRepos: [URL]

  // MARK: - Platform Arguments

  /// The minimum iOS Version to build for.
  @Option(default: "10.0", help: ArgumentHelp("The minimum supported iOS version."))
  var minimumIOSVersion: String

  /// The minimum macOS Version to build for.
  @Option(default: "10.12", help: ArgumentHelp("The minimum supported macOS version."))
  var minimumMacOSVersion: String

  /// The minimum tvOS Version to build for.
  @Option(default: "10.0", help: ArgumentHelp("The minimum supported tvOS version."))
  var minimumTVOSVersion: String

  /// The list of platforms to build for.
  @Option(parsing: .upToNextOption,
          help: ArgumentHelp("""
          The list of platforms to build for. The default list is \
          \(Platform.allCases.map { $0.name }).
          """))
  var platforms: [Platform]

  // MARK: - Specify Pods

  @Option(parsing: .upToNextOption,
          help: ArgumentHelp("List of pods to build."))
  var pods: [String]

  @Option(help: ArgumentHelp("""
  The path to a JSON file of the pods (with optional version) to package into a zip.
  """),
  transform: { str in
    // Get pods, with optional version, from the JSON file specified
    let url = URL(fileURLWithPath: str)
    let jsonData = try Data(contentsOf: url)
    return try JSONDecoder().decode([CocoaPodUtils.VersionedPod].self, from: jsonData)
  })
  var zipPods: [CocoaPodUtils.VersionedPod]?

  // MARK: - Filesystem Paths

  /// Path to override podspec search with local podspec.
  @Option(help: ArgumentHelp("Path to override podspec search with local podspec."),
          transform: URL.init(fileURLWithPath:))
  var localPodspecPath: URL?

  /// The path to the directory containing the blank xcodeproj and Info.plist for building source
  /// based frameworks.
  @Option(help: ArgumentHelp("""
  The root directory for build artifacts. If `nil`, a temporary directory will be used.
  """),
  transform: URL.init(fileURLWithPath:))
  var buildRoot: URL?

  /// The directory to copy the built Zip file to. If this is not set, the path to the Zip file will
  /// be logged to the console.
  @Option(help: ArgumentHelp("""
  The directory to copy the built Zip file to. If this is not set, the path to the Zip \
  file will be logged to the console.
  """),
  transform: URL.init(fileURLWithPath:))
  var outputDir: URL?

  // MARK: - Validation

  mutating func validate() throws {
    // Validate the output directory if provided.
    if let outputDir = outputDir, !FileManager.default.directoryExists(at: outputDir) {
      throw ValidationError("`output-dir` passed in does not exist. Value: \(outputDir)")
    }

    // Validate the buildRoot directory if provided.
    if let buildRoot = buildRoot, !FileManager.default.directoryExists(at: buildRoot) {
      throw ValidationError("`build-root` passed in does not exist. Value: \(buildRoot)")
    }

    if let localPodspecPath = localPodspecPath,
       !FileManager.default.directoryExists(at: localPodspecPath) {
      throw ValidationError("""
      `local-podspec-path` pass in does not exist. Value: \(localPodspecPath)
      """)
    }

    // Validate that Firebase builds are including dependencies.
    if !buildDependencies, zipPods == nil, pods.count == 0 {
      throw ValidationError("""
      The `enable-build-dependencies` option cannot be false unless a list of pods is \
      specified with the `zip-pods` or the `pods` option.
      """)
    }
  }

  // MARK: - Running the tool

  func run() throws {
    // Keep timing for how long it takes to build the zip file for information purposes.
    let buildStart = Date()
    var cocoaPodsUpdateMessage = ""

    // Do a `pod update` if requested.
    if updatePodRepo {
      CocoaPodUtils.updateRepos()
      cocoaPodsUpdateMessage =
        "CocoaPods took \(-buildStart.timeIntervalSinceNow) seconds to update."
    }

    // Register the build root if it was passed in.
    if let buildRoot = buildRoot {
      FileManager.registerBuildRoot(buildRoot: buildRoot.standardizedFileURL)
    }

    // Get the repoDir by deleting four path components from this file to the repo root.
    let repoDir = URL(fileURLWithPath: #file)
      .deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()

    // Validate the repoDir exists, as well as the templateDir.
    guard FileManager.default.directoryExists(at: repoDir) else {
      fatalError("Failed to find the repo root at \(repoDir).")
    }

    // Validate the templateDir exists.
    let templateDir = ZipBuilder.FilesystemPaths.templateDir(fromRepoDir: repoDir)
    guard FileManager.default.directoryExists(at: templateDir) else {
      fatalError("Missing template inside of the repo. \(templateDir) does not exist.")
    }

    // Update iOS target platforms if `--include-catalyst` was specified.
    if !includeCatalyst {
      SkipCatalyst.set()
    }

    // 32 bit iOS slices should only be built if the minimum iOS version is less than 11.
    guard let minVersion = Float(minimumIOSVersion) else {
      fatalError("Invalid minimum iOS version: \(minimumIOSVersion)")
    }
    if minVersion < 11.0 {
      Included32BitIOS.set()
    }

    let paths = ZipBuilder.FilesystemPaths(repoDir: repoDir,
                                           buildRoot: buildRoot,
                                           outputDir: outputDir,
                                           localPodspecPath: localPodspecPath,
                                           logsOutputDir: outputDir?
                                             .appendingPathComponent("build_logs"))

    // Populate the platforms list if it's empty. This isn't a great spot, but the argument parser
    // can't specify a default for arrays.
    let platformsToBuild = !platforms.isEmpty ? platforms : Platform.allCases
    let builder = ZipBuilder(paths: paths,
                             platforms: platformsToBuild,
                             dynamicFrameworks: dynamic,
                             customSpecRepos: customSpecRepos)

    if let outputDir = outputDir {
      do {
        // Clear out the output directory if it exists.
        FileManager.default.removeIfExists(at: outputDir)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
      }
    }

    var podsToBuild = zipPods
    if pods.count > 0 {
      guard podsToBuild == nil else {
        fatalError("Only one of `--zipPods` or `--pods` can be specified.")
      }
      podsToBuild = pods.map { CocoaPodUtils.VersionedPod(name: $0, version: nil) }
    }

    if let podsToBuild = podsToBuild {
      // Set the platform minimum versions.
      PlatformMinimum.initialize(ios: minimumIOSVersion,
                                 macos: minimumMacOSVersion,
                                 tvos: minimumTVOSVersion)

      let (installedPods, frameworks, _) =
        builder.buildAndAssembleZip(podsToInstall: podsToBuild,
                                    includeCarthage: false,
                                    includeDependencies: buildDependencies)
      let staging = FileManager.default.temporaryDirectory(withName: "Binaries")
      try builder.copyFrameworks(fromPods: Array(installedPods.keys), toDirectory: staging,
                                 frameworkLocations: frameworks)
      let zipped = Zip.zipContents(ofDir: staging, name: "Frameworks.zip")
      print(zipped.absoluteString)
      if let outputDir = outputDir {
        let outputFile = outputDir.appendingPathComponent("Frameworks.zip")
        try FileManager.default.copyItem(at: zipped, to: outputFile)
        print("Success! Zip file can be found at \(outputFile.path)")
      } else {
        // Move zip to parent directory so it doesn't get removed with other artifacts.
        let parentLocation =
          zipped.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(zipped.lastPathComponent)
        // Clear out the output file if it exists.
        FileManager.default.removeIfExists(at: parentLocation)
        do {
          try FileManager.default.moveItem(at: zipped, to: parentLocation)
        } catch {
          fatalError("Could not move Zip file to output directory: \(error)")
        }
        print("Success! Zip file can be found at \(parentLocation.path)")
      }
    } else {
      // Do a Firebase Zip Release package build.

      // For the Firebase zip distribution, we disable version checking at install time by
      // setting a high version to install. The minimum versions are controlled by each individual
      // pod's podspec options.
      PlatformMinimum.useRecentVersions()

      let jsonDir = paths.repoDir.appendingPathComponents(["ReleaseTooling", "CarthageJSON"])
      let carthageOptions = CarthageBuildOptions(jsonDir: jsonDir,
                                                 isVersionCheckEnabled: carthageVersionCheck)

      FirebaseBuilder(zipBuilder: builder).build(templateDir: paths.templateDir,
                                                 carthageBuildOptions: carthageOptions)
    }

    if !keepBuildArtifacts {
      let tempDir = FileManager.default.temporaryDirectory(withName: "placeholder")
      FileManager.default.removeIfExists(at: tempDir.deletingLastPathComponent())
    }

    // Get the time since the start of the build to get the full time.
    let secondsSinceStart = -Int(buildStart.timeIntervalSinceNow)
    print("""
    Time profile:
      It took \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m) to build the zip file.
      \(cocoaPodsUpdateMessage)
    """)
  }
}

ZipBuilderTool.main()
