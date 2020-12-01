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
extension TargetPlatform: ExpressibleByArgument {
  public init?(argument: String) {
    // Look for a match in SDK name.
    for platform in TargetPlatform.allCases {
      if argument == platform.sdkName {
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

  /// Flag to also build Carthage artifacts.
  @Flag(default: false,
        inversion: .prefixedEnableDisable,
        help: ArgumentHelp("A flag specifying to build Carthage artifacts."))
  var carthageBuild: Bool

  /// Flag to enable or disable Carthage version checks. Skipping the check can speed up dev
  /// iterations.
  @Flag(default: true,
        // Allows `enableCarthageVersionCheck` and `disableCarthageVersionCheck`.
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
          A list of custom CocoaPod Spec repos.  If not provided, the tool will only use the \
          CocoaPods master repo.
          """))
  var customSpecRepos: [URL]

  // MARK: - Platform Arguments

  /// The minimum iOS Version to build for.
  @Option(default: "10.0",
          help: ArgumentHelp("The minimum supported iOS version. The default is 10.0."))
  var minimumIOSVersion: String

  /// The list of architectures to build for.
  @Option(parsing: .upToNextOption,
          help: ArgumentHelp("""
          The list of platforms to build for. The default list is \
          \(TargetPlatform.allCases.map { $0.sdkName }).
          """))
  var platforms: [TargetPlatform]

  // MARK: - Zip Pods

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

  /// The path to the root of the firebase-ios-sdk repo.
  @Option(help: ArgumentHelp("""
  The path to the repo from which the Firebase distribution is being built.
  """),
  transform: URL.init(fileURLWithPath:))
  var repoDir: URL

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
    // Validate the repoDir exists, as well as the templateDir.
    guard FileManager.default.directoryExists(at: repoDir) else {
      throw ValidationError("Included a repo-dir that doesn't exist.")
    }

    // Validate the templateDir exists.
    let templateDir = ZipBuilder.FilesystemPaths.templateDir(fromRepoDir: repoDir)
    guard FileManager.default.directoryExists(at: templateDir) else {
      throw ValidationError("Missing template inside of the repo. \(templateDir) does not exist.")
    }

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
    if !buildDependencies, zipPods == nil {
      throw ValidationError("""
      The `enable-build-dependencies` option cannot be false unless a list of pods is \
      specified with the `zip-pods` option.
      """)
    }
  }

  // MARK: - Running the tool

  func run() throws {
    // Keep timing for how long it takes to build the zip file for information purposes.
    let buildStart = Date()
    var cocoaPodsUpdateMessage: String = ""

    // Do a `pod update`` if requested.
    if updatePodRepo {
      CocoaPodUtils.updateRepos()
      cocoaPodsUpdateMessage =
        "CocoaPods took \(-buildStart.timeIntervalSinceNow) seconds to update."
    }

    // Register the build root if it was passed in.
    if let buildRoot = buildRoot {
      FileManager.registerBuildRoot(buildRoot: buildRoot.standardizedFileURL)
    }

    let paths = ZipBuilder.FilesystemPaths(repoDir: repoDir,
                                           buildRoot: buildRoot,
                                           outputDir: outputDir,
                                           localPodspecPath: localPodspecPath,
                                           logsOutputDir: outputDir?
                                             .appendingPathComponent("build_logs"))

    // Populate the platforms list if it's empty. This isn't a great spot, but the argument parser
    // can't specify a default for arrays.
    let platformsToBuild = !platforms.isEmpty ? platforms : TargetPlatform.allCases
    let builder = ZipBuilder(paths: paths,
                             platforms: platformsToBuild,
                             dynamicFrameworks: dynamic,
                             customSpecRepos: customSpecRepos)
    let projectDir = FileManager.default.temporaryDirectory(withName: "project")

    // If it exists, remove it before we re-create it. This is simpler than removing all objects.
    if FileManager.default.directoryExists(at: projectDir) {
      try FileManager.default.removeItem(at: projectDir)
    }

    CocoaPodUtils.podInstallPrepare(inProjectDir: projectDir, paths: paths)

    if let outputDir = outputDir {
      do {
        // Clear out the output directory if it exists.
        FileManager.default.removeIfExists(at: outputDir)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
      }
    }

    if let zipPods = zipPods {
      let (installedPods, frameworks, _) = builder.buildAndAssembleZip(podsToInstall: zipPods,
                                                                       inProjectDir: projectDir,
                                                                       minimumIOSVersion: minimumIOSVersion,
                                                                       includeDependencies: buildDependencies)
      let staging = FileManager.default.temporaryDirectory(withName: "staging")
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
      var carthageOptions: CarthageBuildOptions?
      if carthageBuild {
        let jsonDir = paths.repoDir.appendingPathComponents(["ReleaseTooling", "CarthageJSON"])
        carthageOptions = CarthageBuildOptions(jsonDir: jsonDir,
                                               isVersionCheckEnabled: carthageVersionCheck)
      }

      FirebaseBuilder(zipBuilder: builder).build(in: projectDir,
                                                 minimumIOSVersion: minimumIOSVersion,
                                                 carthageBuildOptions: carthageOptions)
    }

    if !keepBuildArtifacts {
      FileManager.default.removeIfExists(at: projectDir.deletingLastPathComponent())
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
