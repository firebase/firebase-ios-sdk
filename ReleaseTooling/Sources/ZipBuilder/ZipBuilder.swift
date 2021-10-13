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
import FirebaseManifest

/// Misc. constants used in the build tool.
struct Constants {
  /// Constants related to the Xcode project template.
  struct ProjectPath {
    // Required for building.
    static let infoPlist = "Info.plist"
    static let projectFile = "FrameworkMaker.xcodeproj"

    /// All required files for building the Zip file.
    static let requiredFilesForBuilding: [String] = [projectFile, infoPlist]

    // Required for distribution.
    static let readmeName = "README.md"

    // Required from the Firebase pod.
    static let firebaseHeader = "Firebase.h"
    static let modulemap = "module.modulemap"

    /// The dummy Firebase library for Carthage distribution.
    static let dummyFirebaseLib = "dummy_Firebase_lib"

    // Make the struct un-initializable.
    @available(*, unavailable)
    init() { fatalError() }
  }

  /// The text added to the README for a product if it contains Resources. The empty line at the end
  /// is intentional.
  static let resourcesRequiredText = """
  You'll also need to add the resources in the Resources
  directory into your target's main bundle.

  """

  // Make the struct un-initializable.
  @available(*, unavailable)
  init() { fatalError() }
}

/// A zip file builder. The zip file can be built with the `buildAndAssembleReleaseDir()` function.
struct ZipBuilder {
  /// Artifacts from building and assembling the release directory.
  struct ReleaseArtifacts {
    /// The Firebase version.
    let firebaseVersion: String

    /// The directory that contains the properly assembled release artifacts.
    let zipDir: URL

    /// The directory that contains the properly assembled release artifacts for Carthage if building it.
    let carthageDir: URL?
  }

  /// Relevant paths in the filesystem to build the release directory.
  struct FilesystemPaths {
    // MARK: - Required Paths

    /// The root of the `firebase-ios-sdk` git repo.
    let repoDir: URL

    /// The path to the directory containing the blank xcodeproj and Info.plist for building source
    /// based frameworks. Generated based on the `repoDir`.
    var templateDir: URL {
      return type(of: self).templateDir(fromRepoDir: repoDir)
    }

    // MARK: - Optional Paths

    /// The root directory for build artifacts. If `nil`, a temporary directory will be used.
    let buildRoot: URL?

    /// The output directory for any artifacts generated during the build. If `nil`, a temporary
    /// directory will be used.
    let outputDir: URL?

    /// The path to where local podspecs are stored.
    let localPodspecPath: URL?

    /// The path to a directory to move all build logs to. If `nil`, a temporary directory will be
    /// used.
    var logsOutputDir: URL?

    /// Creates the struct containing all properties needed for a build.
    /// - Parameter repoDir: The root of the `firebase-ios-sdk` git repo.
    /// - Parameter buildRoot: The root directory for build artifacts. If `nil`, a temporary
    ///      directory will be used.
    /// - Parameter outputDir: The output directory for any artifacts generated. If `nil`, a
    ///      temporary directory will be used.
    /// - Parameter localPodspecPath: A path to where local podspecs are stored.
    /// - Parameter logsOutputDir: The output directory for any logs. If `nil`, a temporary
    ///      directory will be used.
    init(repoDir: URL,
         buildRoot: URL?,
         outputDir: URL?,
         localPodspecPath: URL?,
         logsOutputDir: URL?) {
      self.repoDir = repoDir
      self.buildRoot = buildRoot
      self.outputDir = outputDir
      self.localPodspecPath = localPodspecPath
      self.logsOutputDir = logsOutputDir
    }

    /// Returns the expected template directory given the repo directory provided.
    static func templateDir(fromRepoDir repoDir: URL) -> URL {
      return repoDir.appendingPathComponents(["ReleaseTooling", "Template"])
    }
  }

  /// Paths needed throughout the process of packaging the Zip file.
  public let paths: FilesystemPaths

  /// The targetPlatforms to target for the builds.
  public let platforms: [Platform]

  /// Specifies if the builder is building dynamic frameworks instead of static frameworks.
  private let dynamicFrameworks: Bool

  /// Custom CocoaPods spec repos to be used. If not provided, the tool will only use the CocoaPods
  /// master repo.
  private let customSpecRepos: [URL]?

  /// Creates a ZipBuilder struct to build and assemble zip files and Carthage builds.
  ///
  /// - Parameters:
  ///   - paths: Paths that are needed throughout the process of packaging the Zip file.
  ///   - platforms: The platforms to target for the builds.
  ///   - dynamicFrameworks: Specifies if dynamic frameworks should be built, otherwise static
  ///         frameworks are built.
  ///   - customSpecRepo: A custom spec repo to be used for fetching CocoaPods from.
  init(paths: FilesystemPaths,
       platforms: [Platform],
       dynamicFrameworks: Bool,
       customSpecRepos: [URL]? = nil) {
    self.paths = paths
    self.platforms = platforms
    self.customSpecRepos = customSpecRepos
    self.dynamicFrameworks = dynamicFrameworks
  }

  /// Builds and assembles the contents for the zip build.
  ///
  /// - Parameter podsToInstall: All pods to install.
  /// - Parameter includeCarthage: Build Carthage distribution as well.
  /// - Parameter includeDependencies: Include dependencies of requested pod in distribution.
  /// - Returns: Arrays of pod install info and the frameworks installed.
  func buildAndAssembleZip(podsToInstall: [CocoaPodUtils.VersionedPod],
                           includeCarthage: Bool,
                           includeDependencies: Bool) ->
    ([String: CocoaPodUtils.PodInfo], [String: [URL]], URL?) {
    // Remove CocoaPods cache so the build gets updates after a version is rebuilt during the
    // release process. Always do this, since it can be the source of subtle failures on rebuilds.
    CocoaPodUtils.cleanPodCache()

    // We need to install all the pods in order to get every single framework that we'll need
    // for the zip file. We can't install each one individually since some pods depend on different
    // subspecs from the same pod (ex: GoogleUtilities, GoogleToolboxForMac, etc). All of the code
    // wouldn't be included so we need to install all of the subspecs to catch the superset of all
    // required frameworks, then use that as the source of frameworks to pull from when including
    // the folders in each product directory.
    let linkage: CocoaPodUtils.LinkageType = dynamicFrameworks ? .dynamic : .standardStatic
    var groupedFrameworks: [String: [URL]] = [:]
    var carthageCoreDiagnosticsFrameworks: [URL] = []
    var podsBuilt: [String: CocoaPodUtils.PodInfo] = [:]
    var xcframeworks: [String: [URL]] = [:]
    var resources: [String: URL] = [:]

    for platform in platforms {
      let projectDir = FileManager.default.temporaryDirectory(withName: "project-" + platform.name)
      CocoaPodUtils.podInstallPrepare(inProjectDir: projectDir, templateDir: paths.templateDir)

      let platformPods = podsToInstall.filter { $0.platforms.contains(platform.name) }

      CocoaPodUtils.installPods(platformPods,
                                inDir: projectDir,
                                platform: platform,
                                customSpecRepos: customSpecRepos,
                                localPodspecPath: paths.localPodspecPath,
                                linkage: linkage)
      // Find out what pods were installed with the above commands.
      let installedPods = CocoaPodUtils.installedPodsInfo(inProjectDir: projectDir,
                                                          localPodspecPath: paths.localPodspecPath)

      // If module maps are needed for static frameworks, build them here to be available to copy
      // into the generated frameworks.
      if !dynamicFrameworks {
        ModuleMapBuilder(customSpecRepos: customSpecRepos,
                         selectedPods: installedPods,
                         platform: platform,
                         paths: paths).build()
      }

      let podsToBuild = includeDependencies ? installedPods : installedPods.filter {
        platformPods.map { $0.name.components(separatedBy: "/").first }.contains($0.key)
      }

      // Build in a sorted order to make the build deterministic and to avoid exposing random
      // build order bugs.
      // Also AppCheck must be built after other pods so that its restricted architecture
      // selection does not restrict any of its dependencies.
      var sortedPods = podsToBuild.keys.sorted()
      sortedPods.removeAll(where: { value in
        value == "FirebaseAppCheck"
      })
      sortedPods.append("FirebaseAppCheck")

      for podName in sortedPods {
        guard let podInfo = podsToBuild[podName] else {
          continue
        }
        if podName == "Firebase" {
          // Don't build the Firebase pod.
        } else if podInfo.isSourcePod {
          let builder = FrameworkBuilder(projectDir: projectDir,
                                         platform: platform,
                                         dynamicFrameworks: dynamicFrameworks)
          let (frameworks, resourceContents) =
            builder.compileFrameworkAndResources(withName: podName,
                                                 logsOutputDir: paths.logsOutputDir,
                                                 setCarthage: false,
                                                 podInfo: podInfo)
          groupedFrameworks[podName] = (groupedFrameworks[podName] ?? []) + frameworks

          if includeCarthage, podName == "FirebaseCoreDiagnostics" {
            let (cdFrameworks, _) = builder.compileFrameworkAndResources(withName: podName,
                                                                         logsOutputDir: paths
                                                                           .logsOutputDir,
                                                                         setCarthage: true,
                                                                         podInfo: podInfo)
            carthageCoreDiagnosticsFrameworks += cdFrameworks
          }
          if resourceContents != nil {
            resources[podName] = resourceContents
          }
        } else if podsBuilt[podName] == nil {
          // Binary pods need to be collected once, since the platforms should already be merged.
          let binaryFrameworks = collectBinaryFrameworks(fromPod: podName, podInfo: podInfo)
          xcframeworks[podName] = binaryFrameworks
        }
        // Union all pods built across platforms.
        // Be conservative and favor iOS if it exists - and workaround
        // bug where Firebase.h doesn't get installed for tvOS and macOS.
        // Fixed in #7284.
        if podsBuilt[podName] == nil {
          podsBuilt[podName] = podInfo
        }
      }
    }

    // Now consolidate the built frameworks for all platforms into a single xcframework.
    let xcframeworksDir = FileManager.default.temporaryDirectory(withName: "xcframeworks")
    do {
      try FileManager.default.createDirectory(at: xcframeworksDir,
                                              withIntermediateDirectories: false)
    } catch {
      fatalError("Could not create XCFrameworks directory: \(error)")
    }

    for groupedFramework in groupedFrameworks {
      let name = groupedFramework.key
      let xcframework = FrameworkBuilder.makeXCFramework(withName: name,
                                                         frameworks: groupedFramework.value,
                                                         xcframeworksDir: xcframeworksDir,
                                                         resourceContents: resources[name])
      xcframeworks[name] = [xcframework]
    }
    for (framework, paths) in xcframeworks {
      print("Frameworks for pod: \(framework) were compiled at \(paths)")
    }
    guard includeCarthage else {
      // No Carthage build necessary, return now.
      return (podsBuilt, xcframeworks, nil)
    }
    let xcframeworksCarthageDir = FileManager.default.temporaryDirectory(withName: "xcf-carthage")
    do {
      try FileManager.default.createDirectory(at: xcframeworksCarthageDir,
                                              withIntermediateDirectories: false)
    } catch {
      fatalError("Could not create XCFrameworks Carthage directory: \(error)")
    }

    let carthageCoreDiagnosticsXcframework = FrameworkBuilder.makeXCFramework(
      withName: "FirebaseCoreDiagnostics",
      frameworks: carthageCoreDiagnosticsFrameworks,
      xcframeworksDir: xcframeworksCarthageDir,
      resourceContents: nil
    )
    return (podsBuilt, xcframeworks, carthageCoreDiagnosticsXcframework)
  }

  /// Try to build and package the contents of the Zip file. This will throw an error as soon as it
  /// encounters an error, or will quit due to a fatal error with the appropriate log.
  ///
  /// - Parameter templateDir: The template project for pod install.
  /// - Throws: One of many errors that could have happened during the build phase.
  func buildAndAssembleFirebaseRelease(templateDir: URL) throws -> ReleaseArtifacts {
    let manifest = FirebaseManifest.shared
    var podsToInstall = manifest.pods.filter { $0.zip }.map {
      CocoaPodUtils.VersionedPod(name: $0.name,
                                 version: manifest.versionString($0),
                                 platforms: $0.platforms)
    }
    guard !podsToInstall.isEmpty else {
      fatalError("Failed to find versions for Firebase release")
    }
    // We don't release Google-Mobile-Ads-SDK and GoogleSignIn, but we include their latest
    // version for convenience in the Zip and Carthage builds.
    podsToInstall.append(CocoaPodUtils.VersionedPod(name: "Google-Mobile-Ads-SDK",
                                                    version: nil,
                                                    platforms: ["ios"]))
    podsToInstall.append(CocoaPodUtils.VersionedPod(name: "GoogleSignIn",
                                                    version: nil,
                                                    platforms: ["ios"]))

    print("Final expected versions for the Zip file: \(podsToInstall)")
    let (installedPods, frameworks, carthageCoreDiagnosticsXcframeworkFirebase) =
      buildAndAssembleZip(podsToInstall: podsToInstall,
                          includeCarthage: true,
                          // Always include dependencies for Firebase zips.
                          includeDependencies: true)

    // We need the Firebase pod to get the version for Carthage and to copy the `Firebase.h` and
    // `module.modulemap` file from it.
    guard let firebasePod = installedPods["Firebase"] else {
      fatalError("Could not get the Firebase pod from list of installed pods. All pods " +
        "installed: \(installedPods)")
    }

    guard let carthageCoreDiagnosticsXcframework = carthageCoreDiagnosticsXcframeworkFirebase else {
      fatalError("CoreDiagnosticsXcframework is missing")
    }

    let zipDir = try assembleDistributions(withPackageKind: "Firebase",
                                           podsToInstall: podsToInstall,
                                           installedPods: installedPods,
                                           frameworksToAssemble: frameworks,
                                           firebasePod: firebasePod)
    // Replace Core Diagnostics
    var carthageFrameworks = frameworks
    carthageFrameworks["FirebaseCoreDiagnostics"] = [carthageCoreDiagnosticsXcframework]
    let carthageDir = try assembleDistributions(withPackageKind: "CarthageFirebase",
                                                podsToInstall: podsToInstall,
                                                installedPods: installedPods,
                                                frameworksToAssemble: carthageFrameworks,
                                                firebasePod: firebasePod)

    return ReleaseArtifacts(firebaseVersion: firebasePod.version,
                            zipDir: zipDir, carthageDir: carthageDir)
  }

  // MARK: - Private

  /// Assemble the folder structure of the Zip file. In order to get the frameworks
  /// required, we will `pod install` only those subspecs and then fetch the information for all
  /// the frameworks that were installed, copying the frameworks from our list of compiled
  /// frameworks. The whole process is:
  /// 1. Copy any required files (headers, modulemap, etc) over beforehand to fail fast if anything
  ///    is misconfigured.
  /// 2. Get the frameworks required for Analytics, copy them to the Analytics folder.
  /// 3. Go through the rest of the subspecs (excluding those included in Analytics) and copy them
  ///    to a folder with the name of the subspec.
  /// 4. Assemble the `README` file based off the template and copy it to the directory.
  /// 5. Return the URL of the folder containing the contents of the Zip file.
  ///
  /// - Returns: Return the URL of the folder containing the contents of the Zip or Carthage distribution.
  /// - Throws: One of many errors that could have happened during the build phase.
  private func assembleDistributions(withPackageKind packageKind: String,
                                     podsToInstall: [CocoaPodUtils.VersionedPod],
                                     installedPods: [String: CocoaPodUtils.PodInfo],
                                     frameworksToAssemble: [String: [URL]],
                                     firebasePod: CocoaPodUtils.PodInfo) throws -> URL {
    // Create the directory that will hold all the contents of the Zip file.
    let fileManager = FileManager.default
    let zipDir = fileManager.temporaryDirectory(withName: packageKind)
    do {
      if fileManager.directoryExists(at: zipDir) {
        try fileManager.removeItem(at: zipDir)
      }

      try fileManager.createDirectory(at: zipDir,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
    }

    // Copy all required files from the Firebase pod. This will cause a fatalError if anything
    // fails.
    copyFirebasePodFiles(fromDir: firebasePod.installedLocation, to: zipDir)

    // Start with installing Analytics, since we'll need to exclude those frameworks from the rest
    // of the folders.
    let analyticsFrameworks: [String]
    let analyticsDir: URL
    do {
      // This returns the Analytics directory and a list of framework names that Analytics requires.
      /// Example: ["FirebaseInstallations, "GoogleAppMeasurement", "nanopb", <...>]
      let (dir, frameworks) = try installAndCopyFrameworks(forPod: "FirebaseAnalytics",
                                                           withInstalledPods: installedPods,
                                                           rootZipDir: zipDir,
                                                           builtFrameworks: frameworksToAssemble)
      analyticsFrameworks = frameworks
      analyticsDir = dir
    } catch {
      fatalError("Could not copy frameworks from Analytics into the zip file: \(error)")
    }

    // Start the README dependencies string with the frameworks built in Analytics.
    var readmeDeps = dependencyString(for: "FirebaseAnalytics",
                                      in: analyticsDir,
                                      frameworks: analyticsFrameworks)

    // Loop through all the other subspecs that aren't Core and Analytics and write them to their
    // final destination, including resources.
    let analyticsPods = analyticsFrameworks.map {
      $0.replacingOccurrences(of: ".framework", with: "")
    }
    // Skip Analytics and the pods bundled with it.
    let remainingPods = installedPods.filter {
      $0.key != "FirebaseAnalytics" &&
        $0.key != "FirebaseCore" &&
        $0.key != "FirebaseCoreDiagnostics" &&
        $0.key != "FirebaseInstallations" &&
        $0.key != "Firebase" &&
        podsToInstall.map { $0.name }.contains($0.key)
    }.sorted { $0.key < $1.key }
    for pod in remainingPods {
      do {
        if frameworksToAssemble[pod.key] == nil {
          // Continue if the pod wasn't built - like Swift frameworks for Carthage.
          continue
        }
        let (productDir, podFrameworks) =
          try installAndCopyFrameworks(forPod: pod.key,
                                       withInstalledPods: installedPods,
                                       rootZipDir: zipDir,
                                       builtFrameworks: frameworksToAssemble,
                                       podsToIgnore: analyticsPods)
        // Update the README.
        readmeDeps += dependencyString(for: pod.key, in: productDir, frameworks: podFrameworks)
      } catch {
        fatalError("Could not copy frameworks from \(pod) into the zip file: \(error)")
      }
      do {
        // Update Resources: For the zip distribution, they get pulled from the xcframework to the
        // top-level product directory. For the Carthage distribution, they propagate to each
        // individual framework.
        // TODO: Investigate changing the zip distro to also have Resources in the .frameworks to
        // enable different platform Resources.
        let productPath = zipDir.appendingPathComponent(pod.key)
        let contents = try fileManager.contentsOfDirectory(atPath: productPath.path)
        for fileOrFolder in contents {
          let xcPath = productPath.appendingPathComponent(fileOrFolder)
          let xcResourceDir = xcPath.appendingPathComponent("Resources")

          // Ignore anything that not an xcframework with Resources
          guard fileManager.isDirectory(at: xcPath),
            xcPath.lastPathComponent.hasSuffix("xcframework"),
            fileManager.directoryExists(at: xcResourceDir) else { continue }

          if packageKind == "Firebase" {
            // Move all the bundles in the frameworks out to a common "Resources" directory to
            // match the existing Zip structure.
            let resourcesDir = productPath.appendingPathComponent("Resources")
            try fileManager.moveItem(at: xcResourceDir, to: resourcesDir)

          } else {
            let xcContents = try fileManager.contentsOfDirectory(atPath: xcPath.path)
            for fileOrFolder in xcContents {
              let platformPath = xcPath.appendingPathComponent(fileOrFolder)
              guard fileManager.isDirectory(at: platformPath) else { continue }

              let platformContents = try fileManager.contentsOfDirectory(atPath: platformPath.path)
              for fileOrFolder in platformContents {
                let frameworkPath = platformPath.appendingPathComponent(fileOrFolder)

                // Ignore anything that not a framework.
                guard fileManager.isDirectory(at: frameworkPath),
                  frameworkPath.lastPathComponent.hasSuffix("framework") else { continue }
                let resourcesDir = frameworkPath.appendingPathComponent("Resources")
                try fileManager.copyItem(at: xcResourceDir, to: resourcesDir)
              }
            }
            try fileManager.removeItem(at: xcResourceDir)
          }
        }
      } catch {
        fatalError("Could not setup Resources for \(pod) for \(packageKind) \(error)")
      }

      // Special case for Crashlytics:
      // Copy additional tools to avoid users from downloading another artifact to upload symbols.
      let crashlyticsPodName = "FirebaseCrashlytics"
      if pod.key == crashlyticsPodName {
        for file in ["upload-symbols", "run"] {
          let source = pod.value.installedLocation.appendingPathComponent(file)

          let target = zipDir.appendingPathComponent(crashlyticsPodName)
            .appendingPathComponent(file)
          do {
            try fileManager.copyItem(at: source, to: target)
          } catch {
            fatalError("Error copying Crashlytics tools from \(source) to \(target): \(error)")
          }
        }
      }
    }

    // Assemble the README. Start with the version text, then use the template to inject the
    // versions and the list of frameworks to include for each pod.
    let readmePath = paths.templateDir.appendingPathComponent(Constants.ProjectPath.readmeName)
    let readmeTemplate: String
    do {
      readmeTemplate = try String(contentsOf: readmePath)
    } catch {
      fatalError("Could not get contents of the README template: \(error)")
    }
    let versionsText = versionsString(for: installedPods)
    let readmeText = readmeTemplate.replacingOccurrences(of: "__INTEGRATION__", with: readmeDeps)
      .replacingOccurrences(of: "__VERSIONS__", with: versionsText)
    do {
      try readmeText.write(to: zipDir.appendingPathComponent(Constants.ProjectPath.readmeName),
                           atomically: true,
                           encoding: .utf8)
    } catch {
      fatalError("Could not write README to Zip directory: \(error)")
    }

    print("Contents of the packaged release were assembled at: \(zipDir)")
    return zipDir
  }

  /// Copies all frameworks from the `InstalledPod` (pulling from the `frameworkLocations`) and copy
  /// them to the destination directory.
  ///
  /// - Parameters:
  ///   - installedPods: Names of all the pods installed, which will be used as a
  ///                    list to find out what frameworks to copy to the destination.
  ///   - dir: Destination directory for all the frameworks.
  ///   - frameworkLocations: A dictionary containing the pod name as the key and a location to
  ///                         the compiled frameworks.
  ///   - ignoreFrameworks: A list of Pod
  /// - Returns: The filenames of the frameworks that were copied.
  /// - Throws: Various FileManager errors in case the copying fails, or an error if the framework
  ///           doesn't exist in `frameworkLocations`.
  @discardableResult
  func copyFrameworks(fromPods installedPods: [String],
                      toDirectory dir: URL,
                      frameworkLocations: [String: [URL]],
                      podsToIgnore: [String] = []) throws -> [String] {
    let fileManager = FileManager.default
    if !fileManager.directoryExists(at: dir) {
      try fileManager.createDirectory(at: dir, withIntermediateDirectories: false, attributes: nil)
    }

    // Keep track of the names of the frameworks copied over.
    var copiedFrameworkNames: [String] = []

    // Loop through each installedPod item and get the name so we can fetch the framework and copy
    // it to the destination directory.
    for podName in installedPods {
      // Skip the Firebase pod and specifically ignored frameworks.
      guard podName != "Firebase",
        !podsToIgnore.contains(podName) else {
        continue
      }

      guard let xcframeworks = frameworkLocations[podName] else {
        let reason = "Unable to find frameworks for \(podName) in cache of frameworks built to " +
          "include in the Zip file for that framework's folder."
        let error = NSError(domain: "com.firebase.zipbuilder",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: reason])
        throw error
      }

      // Copy each of the frameworks over, unless it's explicitly ignored.
      for xcframework in xcframeworks {
        let xcframeworkName = xcframework.lastPathComponent
        let destination = dir.appendingPathComponent(xcframeworkName)
        try fileManager.copyItem(at: xcframework, to: destination)
        copiedFrameworkNames
          .append(xcframeworkName.replacingOccurrences(of: ".xcframework", with: ""))
      }
    }

    return copiedFrameworkNames
  }

  /// Copies required files from the Firebase pod (`Firebase.h`, `module.modulemap`, and `NOTICES`) into
  /// the given `zipDir`. Will cause a fatalError if anything fails since the zip file can't exist
  /// without these files.
  private func copyFirebasePodFiles(fromDir firebasePodDir: URL, to zipDir: URL) {
    let firebasePodFiles = ["NOTICES", "Sources/" + Constants.ProjectPath.firebaseHeader,
                            "Sources/" + Constants.ProjectPath.modulemap]
    let firebaseFiles = firebasePodDir.appendingPathComponent("CoreOnly")
    let firebaseFilesToCopy = firebasePodFiles.map {
      firebaseFiles.appendingPathComponent($0)
    }

    // Copy each Firebase file.
    for file in firebaseFilesToCopy {
      // Each file should be copied to the destination project directory with the same name.
      let destination = zipDir.appendingPathComponent(file.lastPathComponent)
      do {
        if !FileManager.default.fileExists(atPath: destination.path) {
          print("Copying final distribution file \(file) to \(destination)...")
          try FileManager.default.copyItem(at: file, to: destination)
        }
      } catch {
        fatalError("Could not copy final distribution files to temporary directory before " +
          "building. Failed while attempting to copy \(file) to \(destination). \(error)")
      }
    }
  }

  /// Creates the String required for this pod to be added to the README. Creates a header and
  /// lists each framework in alphabetical order with the appropriate indentation, as well as a
  /// message about resources if they exist.
  ///
  /// - Parameters:
  ///   - subspec: The subspec that requires documentation.
  ///   - frameworks: All the frameworks required by the subspec.
  ///   - includesResources: A flag to include or exclude the text for adding Resources.
  /// - Returns: A string with a header for the subspec name, and a list of frameworks required to
  ///            integrate for the product to work. Formatted and ready for insertion into the
  ///            README.
  private func dependencyString(for podName: String, in dir: URL, frameworks: [String]) -> String {
    var result = readmeHeader(podName: podName)
    for framework in frameworks.sorted() {
      // The .xcframework suffix has been stripped. The .framework suffix has not been.
      if framework.hasSuffix(".framework") {
        result += "- \(framework)\n"
      } else {
        result += "- \(framework).xcframework\n"
      }
    }

    result += "\n" // Necessary for Resource message to print properly in markdown.

    // Check if there is a Resources directory, and if so, add the disclaimer to the dependency
    // string.
    do {
      let fileManager = FileManager.default
      let resourceDirs = try fileManager.recursivelySearch(for: .directories(name: "Resources"),
                                                           in: dir)
      if !resourceDirs.isEmpty {
        result += Constants.resourcesRequiredText
        result += "\n" // Separate from next pod in listing for text version.
      }
    } catch {
      fatalError("""
      Tried to find Resources directory for \(podName) in order to build the README, but an error
      occurred: \(error).
      """)
    }

    return result
  }

  /// Describes the dependency on other frameworks for the README file.
  func readmeHeader(podName: String) -> String {
    var header = "## \(podName)"
    if !(podName == "FirebaseAnalytics" || podName == "GoogleSignIn") {
      header += " (~> FirebaseAnalytics)"
    }
    header += "\n"
    return header
  }

  /// Installs a subspec and attempts to copy all the frameworks required for it from
  /// `buildFramework` and puts them into a new directory in the `rootZipDir` matching the
  /// subspec's name.
  ///
  /// - Parameters:
  ///   - subspec: The subspec to install and get the dependencies list.
  ///   - projectDir: Root of the project containing the Podfile.
  ///   - rootZipDir: The root directory to be turned into the Zip file.
  ///   - builtFrameworks: All frameworks that have been built, with the framework name as the key
  ///                      and the framework's location as the value.
  ///   - podsToIgnore: Pods to avoid copying, if any.
  /// - Throws: Throws various errors from copying frameworks.
  /// - Returns: The product directory containing all frameworks and the names of the frameworks
  ///            that were copied for this subspec.
  @discardableResult
  func installAndCopyFrameworks(forPod podName: String,
                                withInstalledPods installedPods: [String: CocoaPodUtils.PodInfo],
                                rootZipDir: URL,
                                builtFrameworks: [String: [URL]],
                                podsToIgnore: [String] = []) throws -> (productDir: URL,
                                                                        frameworks: [String]) {
    let podsToCopy = [podName] +
      CocoaPodUtils.transitiveMasterPodDependencies(for: podName, in: installedPods)
    // Remove any duplicates from the `podsToCopy` array. The easiest way to do this is to wrap it
    // in a set then back to an array.
    let dedupedPods = Array(Set(podsToCopy))

    // Copy the frameworks into the proper product directory.
    let productDir = rootZipDir.appendingPathComponent(podName)
    let namedFrameworks = try copyFrameworks(fromPods: dedupedPods,
                                             toDirectory: productDir,
                                             frameworkLocations: builtFrameworks,
                                             podsToIgnore: podsToIgnore)

    let copiedFrameworks = namedFrameworks.filter {
      // Skip frameworks that aren't contained in the "podsToIgnore" array and the Firebase pod.
      !(podsToIgnore.contains($0) || $0 == "Firebase")
    }

    return (productDir, copiedFrameworks)
  }

  /// Creates the String that displays all the versions of each pod, in alphabetical order.
  ///
  /// - Parameter pods: All pods that were installed, with their versions.
  /// - Returns: A String to be added to the README.
  private func versionsString(for pods: [String: CocoaPodUtils.PodInfo]) -> String {
    // Get the longest name in order to generate padding with spaces so it looks nicer.
    let maxLength: Int = {
      guard let pod = pods.keys.max(by: { $0.count < $1.count }) else {
        // The longest pod as of this writing is 29 characters, if for whatever reason this fails
        // just assume 30 characters long.
        return 30
      }

      // Return room for a space afterwards.
      return pod.count + 1
    }()

    let header: String = {
      // Center the CocoaPods title within the spaces given. If there's an odd number of spaces, add
      // the extra space after the CocoaPods title.
      let cocoaPods = "CocoaPod"
      let spacesToPad = maxLength - cocoaPods.count
      let halfPadding = String(repeating: " ", count: spacesToPad / 2)

      // Start with the spaces padding, then add the CocoaPods title.
      var result = halfPadding + cocoaPods + halfPadding
      if spacesToPad % 2 != 0 {
        // Add an extra space since the padding isn't even
        result += " "
      }

      // Add the versioning text and return.
      result += "| Version\n"

      // Add a line underneath each.
      result += String(repeating: "-", count: maxLength) + "|" + String(repeating: "-", count: 9)
      result += "\n"
      return result
    }()

    // Sort the pods by name for a cleaner display.
    let sortedPods = pods.sorted { $0.key < $1.key }

    // Get the name and version of each pod, padding it along the way.
    var podVersions: String = ""
    for pod in sortedPods {
      // Insert the name and enough spaces to reach the end of the column.
      let podName = pod.key
      podVersions += podName + String(repeating: " ", count: maxLength - podName.count)

      // Add a pipe and the version.
      podVersions += "| " + pod.value.version + "\n"
    }

    return header + podVersions
  }

  // MARK: - Framework Generation

  /// Collects the .framework and .xcframeworks files from the binary pods. This will go through
  /// the contents of the directory and copy the .frameworks to a temporary directory. Returns a
  /// dictionary with the framework name for the key and all information for frameworks to install
  /// EXCLUDING resources, as they are handled later (if not included in the .framework file
  /// already).
  private func collectBinaryFrameworks(fromPod podName: String,
                                       podInfo: CocoaPodUtils.PodInfo) -> [URL] {
    // Verify the Pods folder exists and we can get the contents of it.
    let fileManager = FileManager.default

    // Create the temporary directory we'll be storing the build/assembled frameworks in, and remove
    // the Resources directory if it already exists.
    let binaryZipDir = fileManager.temporaryDirectory(withName: "binary_zip")
    do {
      try fileManager.createDirectory(at: binaryZipDir,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
    } catch {
      fatalError("Cannot create temporary directory to store binary frameworks: \(error)")
    }
    var frameworks: [URL] = []

    // TODO: packageAllResources is disabled for binary frameworks since it's not needed for Firebase
    // and it does not yet support xcframeworks.
    // Package all resources into the frameworks since that's how Carthage needs it packaged.
//    do {
//      // TODO: Figure out if we need to exclude bundles here or not.
//      try ResourcesManager.packageAllResources(containedIn: podInfo.installedLocation)
//    } catch {
//      fatalError("Tried to package resources for \(podName) but it failed: \(error)")
//    }

    // Copy each of the frameworks to a known temporary directory and store the location.
    for framework in podInfo.binaryFrameworks {
      // Copy it to the temporary directory and save it to our list of frameworks.
      let zipLocation = binaryZipDir.appendingPathComponent(framework.lastPathComponent)

      // Remove the framework if it exists since it could be out of date.
      fileManager.removeIfExists(at: zipLocation)
      do {
        try fileManager.copyItem(at: framework, to: zipLocation)
      } catch {
        fatalError("Cannot copy framework at \(framework) while " +
          "attempting to generate frameworks. \(error)")
      }
      frameworks.append(zipLocation)
    }
    return frameworks
  }
}
