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

/// A structure to build a .framework in a given project directory.
struct FrameworkBuilder {
  /// Platforms to be included in the built frameworks.
  private let targetPlatforms: [TargetPlatform]

  /// The directory containing the Xcode project and Pods folder.
  private let projectDir: URL

  /// Flag for building dynamic frameworks instead of static frameworks.
  private let dynamicFrameworks: Bool

  /// Flag for whether or not Carthage artifacts should be built as well.
  private let buildCarthage: Bool

  /// The Pods directory for building the framework.
  private var podsDir: URL {
    return projectDir.appendingPathComponent("Pods", isDirectory: true)
  }

  /// Default initializer.
  init(projectDir: URL, platform: Platform, includeCarthage: Bool,
       dynamicFrameworks: Bool) {
    self.projectDir = projectDir
    targetPlatforms = platform.platformTargets
    buildCarthage = includeCarthage && platform == .iOS
    self.dynamicFrameworks = dynamicFrameworks
  }

  // MARK: - Public Functions

  /// Compiles the specified framework in a temporary directory and writes the build logs to file.
  /// This will compile all architectures for a single platform at a time.
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Parameter logsOutputDir: The path to the directory to place build logs.
  /// - Parameter moduleMapContents: Module map contents for all frameworks in this pod.
  /// - Returns: A path to the newly compiled frameworks, the Carthage frameworks, and Resources.
  func compileFrameworkAndResources(withName framework: String,
                                    logsOutputDir: URL? = nil,
                                    podInfo: CocoaPodUtils.PodInfo) -> ([URL], URL?, URL?) {
    let fileManager = FileManager.default
    let outputDir = fileManager.temporaryDirectory(withName: "frameworks_being_built")
    let logsDir = logsOutputDir ?? fileManager.temporaryDirectory(withName: "build_logs")
    do {
      // Remove the compiled frameworks directory, this isn't the cache we're using.
      if fileManager.directoryExists(at: outputDir) {
        try fileManager.removeItem(at: outputDir)
      }

      try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

      // Create our logs directory if it doesn't exist.
      if !fileManager.directoryExists(at: logsDir) {
        try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
      }
    } catch {
      fatalError("Failure creating temporary directory while building \(framework): \(error)")
    }

    if dynamicFrameworks {
      return (buildDynamicFrameworks(withName: framework, logsDir: logsDir, outputDir: outputDir),
              nil, nil)
    } else {
      return buildStaticFrameworks(withName: framework, logsDir: logsDir, outputDir: outputDir,
                                   podInfo: podInfo)
    }
  }

  // MARK: - Private Helpers

  /// This runs a command and immediately returns a Shell result.
  /// NOTE: This exists in conjunction with the `Shell.execute...` due to issues with different
  ///       `.bash_profile` environment variables. This should be consolidated in the future.
  private static func syncExec(command: String,
                               args: [String] = [],
                               captureOutput: Bool = false) -> Shell
    .Result {
    let task = Process()
    task.launchPath = command
    task.arguments = args

    // If we want to output to the console, create a readabilityHandler and save each line along the
    // way. Otherwise, we can just read the pipe at the end. By disabling outputToConsole, some
    // commands (such as any xcodebuild) can run much, much faster.
    var output = ""
    if captureOutput {
      let pipe = Pipe()
      task.standardOutput = pipe
      let outHandle = pipe.fileHandleForReading

      outHandle.readabilityHandler = { pipe in
        // This will be run any time data is sent to the pipe. We want to print it and store it for
        // later. Ignore any non-valid Strings.
        guard let line = String(data: pipe.availableData, encoding: .utf8) else {
          print("Could not get data from pipe for command \(command): \(pipe.availableData)")
          return
        }
        if !line.isEmpty {
          output += line
        }
      }
      // Also set the termination handler on the task in order to stop the readabilityHandler from
      // parsing any more data from the task.
      task.terminationHandler = { t in
        guard let stdOut = t.standardOutput as? Pipe else { return }

        stdOut.fileHandleForReading.readabilityHandler = nil
      }
    } else {
      // No capturing output, just mark it as complete.
      output = "The task completed"
    }

    task.launch()
    task.waitUntilExit()

    // Normally we'd use a pipe to retrieve the output, but for whatever reason it slows things down
    // tremendously for xcodebuild.
    guard task.terminationStatus == 0 else {
      return .error(code: task.terminationStatus, output: output)
    }

    return .success(output: output)
  }

  /// Build all thin slices for an open source pod.
  /// - Parameter framework: The name of the framework to be built.
  /// - Parameter logsDir: The path to the directory to place build logs.
  /// - Parameter setCarthage: Set Carthage flag in CoreDiagnostics for metrics.
  /// - Returns: A dictionary of URLs to the built thin libraries keyed by platform.
  private func buildFrameworksForAllPlatforms(withName framework: String,
                                              logsDir: URL,
                                              setCarthage: Bool = false) -> [TargetPlatform: URL] {
    // Build every architecture and save the locations in an array to be assembled.
    var slicedFrameworks = [TargetPlatform: URL]()
    for targetPlatform in targetPlatforms {
      let buildDir = projectDir.appendingPathComponent(targetPlatform.buildName)
      let sliced = buildSlicedFramework(withName: framework,
                                        targetPlatform: targetPlatform,
                                        buildDir: buildDir,
                                        logRoot: logsDir,
                                        setCarthage: setCarthage)
      slicedFrameworks[targetPlatform] = sliced
    }
    return slicedFrameworks
  }

  /// Uses `xcodebuild` to build a framework for a specific target platform.
  ///
  /// - Parameters:
  ///   - framework: Name of the framework being built.
  ///   - targetPlatform: The target platform to target for the build.
  ///   - buildDir: Location where the project should be built.
  ///   - logRoot: Root directory where all logs should be written.
  ///   - setCarthage: Set Carthage flag in CoreDiagnostics for metrics.
  /// - Returns: A URL to the framework that was built.
  private func buildSlicedFramework(withName framework: String,
                                    targetPlatform: TargetPlatform,
                                    buildDir: URL,
                                    logRoot: URL,
                                    setCarthage: Bool = false) -> URL {
    let isMacCatalyst = targetPlatform == .catalyst
    let isMacCatalystString = isMacCatalyst ? "YES" : "NO"
    let workspacePath = projectDir.appendingPathComponent("FrameworkMaker.xcworkspace").path
    let distributionFlag = setCarthage ? "-DFIREBASE_BUILD_CARTHAGE" :
      "-DFIREBASE_BUILD_ZIP_FILE"
    let cFlags = "OTHER_CFLAGS=$(value) \(distributionFlag)"
    let archs = targetPlatform.archs.map { $0.rawValue }.joined(separator: " ")

    var args = ["build",
                "-configuration", "release",
                "-workspace", workspacePath,
                "-scheme", framework,
                "GCC_GENERATE_DEBUGGING_SYMBOLS=NO",
                "ARCHS=\(archs)",
                "VALID_ARCHS=\(archs)",
                "ONLY_ACTIVE_ARCH=NO",
                // BUILD_LIBRARY_FOR_DISTRIBUTION=YES is necessary for Swift libraries.
                // See https://forums.developer.apple.com/thread/125646.
                // Unlike the comment there, the option here is sufficient to cause .swiftinterface
                // files to be generated in the .swiftmodule directory. The .swiftinterface files
                // are required for xcodebuild to successfully generate an xcframework.
                "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
                "SUPPORTS_MACCATALYST=\(isMacCatalystString)",
                "BUILD_DIR=\(buildDir.path)",
                "-sdk", targetPlatform.sdkName,
                cFlags]
    // Add bitcode option for platforms that need it.
    if targetPlatform.shouldEnableBitcode {
      args.append("BITCODE_GENERATION_MODE=bitcode")
    }
    // Code signing isn't needed for libraries. Disabling signing is required for
    // Catalyst libs with resources. See
    // https://github.com/CocoaPods/CocoaPods/issues/8891#issuecomment-573301570
    if isMacCatalyst {
      args.append("CODE_SIGN_IDENTITY=-")
    }
    print("""
    Compiling \(framework) for \(targetPlatform.buildName) (\(archs)) with command:
    /usr/bin/xcodebuild \(args.joined(separator: " "))
    """)

    // Regardless if it succeeds or not, we want to write the log to file in case we need to inspect
    // things further.
    let logFileName = "\(framework)-\(targetPlatform.buildName).txt"
    let logFile = logRoot.appendingPathComponent(logFileName)

    let result = FrameworkBuilder.syncExec(command: "/usr/bin/xcodebuild",
                                           args: args,
                                           captureOutput: true)
    switch result {
    case let .error(code, output):
      // Write output to disk and print the location of it. Force unwrapping here since it's going
      // to crash anyways, and at this point the root log directory exists, we know it's UTF8, so it
      // should pass every time. Revisit if that's not the case.
      try! output.write(to: logFile, atomically: true, encoding: .utf8)
      fatalError("Error building \(framework) for \(targetPlatform.buildName). Code: \(code). See " +
        "the build log at \(logFile)")

    case let .success(output):
      // Try to write the output to the log file but if it fails it's not a huge deal since it was
      // a successful build.
      try? output.write(to: logFile, atomically: true, encoding: .utf8)
      print("""
      Successfully built \(framework) for \(targetPlatform.buildName). Build log is at \(logFile).
      """)

      // Use the Xcode-generated path to return the path to the compiled library.
      // The framework name may be different from the pod name if the module is reset in the
      // podspec - like Release-iphonesimulator/BoringSSL-GRPC/openssl_grpc.framework.
      print("buildDir: \(buildDir)")
      let frameworkPath = buildDir.appendingPathComponents([targetPlatform.buildDirName, framework])
      var actualFramework: String
      do {
        let files = try FileManager.default.contentsOfDirectory(at: frameworkPath,
                                                                includingPropertiesForKeys: nil)
          .compactMap { $0.path }
        let frameworkDir = files.filter { $0.contains(".framework") }
        actualFramework = URL(fileURLWithPath: frameworkDir[0]).lastPathComponent
      } catch {
        fatalError("Error while enumerating files \(frameworkPath): \(error.localizedDescription)")
      }
      let libPath = frameworkPath.appendingPathComponent(actualFramework)
      print("buildSliced returns \(libPath)")
      return libPath
    }
  }

  // TODO: Automatically get the right name.
  /// The dynamic framework name is different from the pod name when the module_name
  /// specifier is used in the podspec.
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Returns: The corresponding dynamic framework name.
  private func frameworkBuildName(_ framework: String) -> String {
    if !dynamicFrameworks {
      return framework
    }
    switch framework {
    case "PromisesObjC":
      return "FBLPromises"
    case "Protobuf":
      return "protobuf"
    default:
      return framework
    }
  }

  /// Compiles the specified framework in a temporary directory and writes the build logs to file.
  /// This will compile all architectures and use the -create-xcframework command to create a modern
  /// "fat" framework.
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Parameter logsDir: The path to the directory to place build logs.
  /// - Returns: A path to the newly compiled frameworks (with any included Resources embedded).
  private func buildDynamicFrameworks(withName framework: String,
                                      logsDir: URL,
                                      outputDir: URL) -> [URL] {
    // xcframework doesn't lipo things together but accepts fat frameworks for one target.
    // We group architectures here to deal with this fact.
    var thinFrameworks = [URL]()
    for targetPlatform in TargetPlatform.allCases {
      let buildDir = projectDir.appendingPathComponent(targetPlatform.buildName)
      let slicedFramework = buildSlicedFramework(withName: framework,
                                                 targetPlatform: targetPlatform,
                                                 buildDir: buildDir,
                                                 logRoot: logsDir)
      thinFrameworks.append(slicedFramework)
    }
    return thinFrameworks
  }

  /// Compiles the specified framework in a temporary directory and writes the build logs to file.
  /// This will compile all architectures and use the -create-xcframework command to create a modern
  /// "fat" framework.
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Parameter logsDir: The path to the directory to place build logs.
  /// - Parameter moduleMapContents: Module map contents for all frameworks in this pod.
  /// - Returns: A path to the newly compiled framework, the Carthage version, and the Resource URL.
  private func buildStaticFrameworks(withName framework: String,
                                     logsDir: URL,
                                     outputDir: URL,
                                     podInfo: CocoaPodUtils.PodInfo) -> ([URL], URL?, URL) {
    // Build every architecture and save the locations in an array to be assembled.
    let slicedFrameworks = buildFrameworksForAllPlatforms(withName: framework, logsDir: logsDir)

    // Create the framework directory in the filesystem for the thin archives to go.
    let fileManager = FileManager.default
    let frameworkDir = outputDir.appendingPathComponent("\(framework).framework")
    do {
      try fileManager.createDirectory(at: frameworkDir, withIntermediateDirectories: true)
    } catch {
      fatalError("Could not create framework directory while building framework \(framework). " +
        "\(error)")
    }

    // Find the location of the public headers, any platform will do.
    guard let anyPlatform = targetPlatforms.first,
      let archivePath = slicedFrameworks[anyPlatform] else {
      fatalError("Could not get a path to an archive to fetch headers in \(framework).")
    }

    // Get the framework Headers directory. On macOS, it's a symbolic link.
    let headersDir = archivePath.appendingPathComponent("Headers").resolvingSymlinksInPath()

    // Find CocoaPods generated umbrella header.
    var umbrellaHeader = ""
    if framework == "gRPC-Core" || framework == "TensorFlowLiteObjC" {
      // TODO: Proper handling of podspec-specified module.modulemap files with customized umbrella
      // headers. This is good enough for Firebase since it doesn't need these modules.
      umbrellaHeader = "\(framework)-umbrella.h"
    } else {
      var umbrellaHeaderURL: URL
      do {
        let files = try fileManager.contentsOfDirectory(at: headersDir,
                                                        includingPropertiesForKeys: nil)
          .compactMap { $0.path }
        let umbrellas = files.filter { $0.hasSuffix("umbrella.h") }
        if umbrellas.count != 1 {
          fatalError("Did not find exactly one umbrella header in \(headersDir).")
        }
        guard let firstUmbrella = umbrellas.first else {
          fatalError("Failed to get umbrella header in \(headersDir).")
        }
        umbrellaHeaderURL = URL(fileURLWithPath: firstUmbrella)
      } catch {
        fatalError("Error while enumerating files \(headersDir): \(error.localizedDescription)")
      }
      // Verify Firebase frameworks include an explicit umbrella header for Firebase.h.
      if framework.hasPrefix("Firebase") || framework == "GoogleDataTransport",
        framework != "FirebaseCoreDiagnostics",
        framework != "FirebaseUI",
        !framework.hasSuffix("Swift") {
        // Delete CocoaPods generated umbrella and use pre-generated one.
        do {
          try fileManager.removeItem(at: umbrellaHeaderURL)
        } catch let error as NSError {
          fatalError("Failed to delete: \(umbrellaHeaderURL). Error: \(error.domain)")
        }
        umbrellaHeader = "\(framework).h"
        let frameworkHeader = headersDir.appendingPathComponent(umbrellaHeader)
        guard fileManager.fileExists(atPath: frameworkHeader.path) else {
          fatalError("Missing explicit umbrella header for \(framework).")
        }
      } else {
        umbrellaHeader = umbrellaHeaderURL.lastPathComponent
      }
    }
    // Copy the Headers over.
    let headersDestination = frameworkDir.appendingPathComponent("Headers")
    do {
      try fileManager.copyItem(at: headersDir, to: headersDestination)
    } catch {
      fatalError("Could not copy headers from \(headersDir) to Headers directory in " +
        "\(headersDestination): \(error)")
    }
    // Add an Info.plist. Required by Carthage and SPM binary xcframeworks.
    CarthageUtils.generatePlistContents(forName: framework,
                                        withVersion: podInfo.version,
                                        to: frameworkDir)

    // TODO: copy PrivateHeaders directory as well if it exists. SDWebImage is an example pod.

    // Move all the Resources into .bundle directories in the destination Resources dir. The
    // Resources live are contained within the folder structure:
    // `projectDir/arch/Release-platform/FrameworkName`.
    // The Resources are stored at the top-level of the .framework or .xcframework directory.
    // For Firebase distributions, they are propagated one level higher in the final distribution.
    let resourceContents = projectDir.appendingPathComponents([anyPlatform.buildName,
                                                               anyPlatform.buildDirName,
                                                               framework])

    guard let moduleMapContentsTemplate = podInfo.moduleMapContents else {
      fatalError("Module map contents missing for framework \(framework)")
    }
    let moduleMapContents = moduleMapContentsTemplate.get(umbrellaHeader: umbrellaHeader)
    let frameworks = groupFrameworks(withName: framework,
                                     fromFolder: frameworkDir,
                                     slicedFrameworks: slicedFrameworks,
                                     moduleMapContents: moduleMapContents)

    var carthageFramework: URL?
    if buildCarthage {
      var carthageThinArchives: [TargetPlatform: URL]
      if framework == "FirebaseCoreDiagnostics" {
        // FirebaseCoreDiagnostics needs to be built with a different ifdef for the Carthage distro.
        carthageThinArchives = buildFrameworksForAllPlatforms(withName: framework,
                                                              logsDir: logsDir,
                                                              setCarthage: true)
      } else {
        carthageThinArchives = slicedFrameworks
      }
      carthageFramework = packageCarthageFramework(withName: framework,
                                                   fromFolder: frameworkDir,
                                                   slicedFrameworks: carthageThinArchives,
                                                   resourceContents: resourceContents,
                                                   moduleMapContents: moduleMapContents)
    }
    // Remove the temporary thin archives.
    for slicedFramework in slicedFrameworks.values {
      do {
        try fileManager.removeItem(at: slicedFramework)
      } catch {
        // Just log a warning instead of failing, since this doesn't actually affect the build
        // itself. This should only be shown to help users clean up their disk afterwards.
        print("""
        WARNING: Failed to remove temporary sliced framework at \(slicedFramework.path). This should
        be removed from your system to save disk space. \(error). You should be able to remove the
        archive from Terminal with:
        rm \(slicedFramework.path)
        """)
      }
    }
    return (frameworks, carthageFramework, resourceContents)
  }

  /// Parses CocoaPods config files or uses the passed in `moduleMapContents` to write the
  /// appropriate `moduleMap` to the `destination`.
  private func packageModuleMaps(inFrameworks frameworks: [URL],
                                 moduleMapContents: String,
                                 destination: URL) {
    // CocoaPods does not put dependent frameworks and libraries into the module maps it generates.
    // Instead it use build options to specify them. For the zip build, we need the module maps to
    // include the dependent frameworks and libraries. Therefore we reconstruct them by parsing
    // the CocoaPods config files and add them here.
    // Currently we only to the construction for Objective C since Swift Module directories require
    // several other files. See https://github.com/firebase/firebase-ios-sdk/pull/5040.
    // Therefore, for Swift we do a simple copy of the Modules files from an Xcode build.
    // This is sufficient for the testing done so far, but more testing is required to determine
    // if dependent libraries and frameworks also may need to be added to the Swift module maps in
    // some cases.
    let builtSwiftModules = makeSwiftModuleMap(thinFrameworks: frameworks, destination: destination)
    if !builtSwiftModules {
      // Copy the module map to the destination.
      let moduleDir = destination.appendingPathComponent("Modules")
      do {
        try FileManager.default.createDirectory(at: moduleDir, withIntermediateDirectories: true)
      } catch {
        let frameworkName: String = frameworks.first?.lastPathComponent ?? "<UNKNOWN"
        fatalError("Could not create Modules directory for framework: \(frameworkName). \(error)")
      }
      let modulemap = moduleDir.appendingPathComponent("module.modulemap")
      do {
        try moduleMapContents.write(to: modulemap, atomically: true, encoding: .utf8)
      } catch {
        let frameworkName: String = frameworks.first?.lastPathComponent ?? "<UNKNOWN"
        fatalError("Could not write modulemap to disk for \(frameworkName): \(error)")
      }
    }
  }

  /// URLs pointing to the frameworks containing architecture specific code.
  private func makeSwiftModuleMap(thinFrameworks: [URL], destination: URL) -> Bool {
    let fileManager = FileManager.default

    for thinFramework in thinFrameworks {
      // Get the Modules directory. The Catalyst one is a symbolic link.
      let moduleDir = thinFramework.appendingPathComponent("Modules").resolvingSymlinksInPath()
      do {
        let files = try fileManager.contentsOfDirectory(at: moduleDir,
                                                        includingPropertiesForKeys: nil)
          .compactMap { $0.path }
        let swiftModules = files.filter { $0.hasSuffix(".swiftmodule") }
        if swiftModules.isEmpty {
          return false
        }
        guard let first = swiftModules.first,
          let swiftModule = URL(string: first) else {
          fatalError("Failed to get swiftmodule in \(moduleDir).")
        }
        let destModuleDir = destination.appendingPathComponent("Modules")
        if !fileManager.directoryExists(at: destModuleDir) {
          do {
            try fileManager.copyItem(at: moduleDir, to: destModuleDir)
          } catch {
            fatalError("Could not copy Modules from \(moduleDir) to " +
              "\(destModuleDir): \(error)")
          }
        } else {
          // If the Modules directory is already there, only copy in the architecture specific files
          // from the *.swiftmodule subdirectory.
          do {
            let files = try fileManager.contentsOfDirectory(at: swiftModule,
                                                            includingPropertiesForKeys: nil)
              .compactMap { $0.path }
            let destSwiftModuleDir = destModuleDir
              .appendingPathComponent(swiftModule.lastPathComponent)
            for file in files {
              let fileURL = URL(fileURLWithPath: file)
              let projectDir = swiftModule.appendingPathComponent("Project")
              if fileURL.lastPathComponent == "Project",
                fileManager.directoryExists(at: projectDir) {
                // The Project directory (introduced with Xcode 11.4) already exists, only copy in
                // new contents.
                let projectFiles = try fileManager.contentsOfDirectory(at: projectDir,
                                                                       includingPropertiesForKeys: nil)
                  .compactMap { $0.path }
                let destProjectDir = destSwiftModuleDir.appendingPathComponent("Project")
                for projectFile in projectFiles {
                  let projectFileURL = URL(fileURLWithPath: projectFile)
                  do {
                    try fileManager.copyItem(at: projectFileURL, to:
                      destProjectDir.appendingPathComponent(projectFileURL.lastPathComponent))
                  } catch {
                    fatalError("Could not copy Project file from \(projectFileURL) to " +
                      "\(destProjectDir): \(error)")
                  }
                }
              } else {
                do {
                  try fileManager.copyItem(at: fileURL, to:
                    destSwiftModuleDir
                      .appendingPathComponent(fileURL.lastPathComponent))
                } catch {
                  fatalError("Could not copy Swift module file from \(fileURL) to " +
                    "\(destSwiftModuleDir): \(error)")
                }
              }
            }
          } catch {
            fatalError("Failed to get Modules directory contents - \(moduleDir):" +
              "\(error.localizedDescription)")
          }
        }
      } catch {
        fatalError("Error while enumerating files \(moduleDir): \(error.localizedDescription)")
      }
    }
    return true
  }

  /// Groups slices for each platform into a minimal set of frameworks
  /// - Parameter withName: The framework name.
  /// - Parameter fromFolder: The almost complete framework folder. Includes Headers, Info.plist,
  /// and Resources.
  /// - Parameter slicedFrameworks: All the frameworks sliced by platform.
  /// - Parameter moduleMapContents: Module map contents for all frameworks in this pod.
  private func groupFrameworks(withName framework: String,
                               fromFolder: URL,
                               slicedFrameworks: [TargetPlatform: URL],
                               moduleMapContents: String) -> ([URL]) {
    let fileManager = FileManager.default

    // Create a `.framework` for each of the thinArchives using the `fromFolder` as the base.
    let platformFrameworksDir =
      fileManager.temporaryDirectory(withName: "platform_frameworks")
    if !fileManager.directoryExists(at: platformFrameworksDir) {
      do {
        try fileManager.createDirectory(at: platformFrameworksDir,
                                        withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create a temp directory to store all thin frameworks: \(error)")
      }
    }

    // Group the thin frameworks into three groups: device, simulator, and Catalyst (all represented
    // by the `TargetPlatform` enum. The slices need to be packaged that way with lipo before
    // creating a .framework that works for similar grouped architectures. If built separately,
    // `-create-xcframework` will return an error and fail:
    // `Both ios-arm64 and ios-armv7 represent two equivalent library definitions`
    var frameworksBuilt: [URL] = []
    for (platform, frameworkPath) in slicedFrameworks {
      let platformDir = platformFrameworksDir.appendingPathComponent(platform.buildName)
      do {
        try fileManager.createDirectory(at: platformDir, withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create directory for architecture slices on \(platform) for " +
          "\(framework): \(error)")
      }

      // Package a normal .framework given the `fromFolder` and the binary from `slicedFrameworks`.
      let destination = platformDir.appendingPathComponent(fromFolder.lastPathComponent)
      do {
        try fileManager.copyItem(at: fromFolder, to: destination)
      } catch {
        fatalError("Could not create framework directory needed to build \(framework): \(error)")
      }

      // Copy the binary to the right location.
      let binaryName = frameworkPath.lastPathComponent.replacingOccurrences(of: ".framework",
                                                                            with: "")
      let fatBinary = frameworkPath.appendingPathComponent(binaryName).resolvingSymlinksInPath()
      let fatBinaryDestination = destination.appendingPathComponent(framework)
      do {
        try fileManager.copyItem(at: fatBinary, to: fatBinaryDestination)
      } catch {
        fatalError("Could not copy fat binary to framework directory for \(framework): \(error)")
      }

      // Use the appropriate moduleMaps
      packageModuleMaps(inFrameworks: [frameworkPath],
                        moduleMapContents: moduleMapContents,
                        destination: destination)

      frameworksBuilt.append(destination)
    }
    return frameworksBuilt
  }

  /// Package the built frameworks into an XCFramework.
  /// - Parameter withName: The framework name.
  /// - Parameter frameworks: The grouped frameworks.
  /// - Parameter xcframeworksDir: Location at which to build the xcframework.
  /// - Parameter resourceContents: Location of the resources for this xcframework.
  static func makeXCFramework(withName name: String,
                              frameworks: [URL],
                              xcframeworksDir: URL,
                              resourceContents: URL?) -> URL {
    let xcframework = xcframeworksDir.appendingPathComponent(name + ".xcframework")

    // The arguments for the frameworks need to be separated.
    var frameworkArgs: [String] = []
    for frameworkBuilt in frameworks {
      frameworkArgs.append("-framework")
      frameworkArgs.append(frameworkBuilt.path)
    }

    let outputArgs = ["-output", xcframework.path]
    let args = ["-create-xcframework"] + frameworkArgs + outputArgs
    print("""
    Building \(xcframework) with command:
    /usr/bin/xcodebuild \(args.joined(separator: " "))
    """)
    let result = syncExec(command: "/usr/bin/xcodebuild", args: args, captureOutput: true)
    switch result {
    case let .error(code, output):
      fatalError("Could not build xcframework for \(name) exit code \(code): \(output)")

    case .success:
      print("XCFramework for \(name) built successfully at \(xcframework).")
    }
    // xcframework resources are packaged at top of xcframework.
    if let resourceContents = resourceContents {
      let resourceDir = xcframework.appendingPathComponent("Resources")
      do {
        try ResourcesManager.moveAllBundles(inDirectory: resourceContents, to: resourceDir)
      } catch {
        fatalError("Could not move bundles into Resources directory while building \(name): " +
          "\(error)")
      }
    }
    return xcframework
  }

  /// Packages a Carthage framework. Carthage does not yet support xcframeworks, so we exclude the
  /// Catalyst slice.
  /// - Parameter withName: The framework name.
  /// - Parameter fromFolder: The almost complete framework folder. Includes Headers, Info.plist,
  /// and Resources.
  /// - Parameter slicedFrameworks: All the frameworks sliced by platform.
  /// - Parameter resourceContents: Location of the resources for this Carthage framework.
  /// - Parameter moduleMapContents: Module map contents for all frameworks in this pod.
  private func packageCarthageFramework(withName framework: String,
                                        fromFolder: URL,
                                        slicedFrameworks: [TargetPlatform: URL],
                                        resourceContents: URL,
                                        moduleMapContents: String) -> URL {
    let fileManager = FileManager.default

    // Create a `.framework` for each of the thinArchives using the `fromFolder` as the base.
    let platformFrameworksDir = fileManager.temporaryDirectory(withName: "carthage_frameworks")
    if !fileManager.directoryExists(at: platformFrameworksDir) {
      do {
        try fileManager.createDirectory(at: platformFrameworksDir,
                                        withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create a temp directory to store all thin frameworks: \(error)")
      }
    }

    // The frameworks include the arm64 simulator slice which will conflict with the arm64 device
    // slice. Until Carthage can use XCFrameworks natively, extract the supported thin slices.
    let thinSlices: [Architecture: URL] =
      slicedBinariesForCarthage(fromFrameworks: slicedFrameworks,
                                workingDir: platformFrameworksDir)

    // Build the fat archive using the `lipo` command to make one fat binary that Carthage can use
    // in the framework. We need the full archive path.
    let fatArchive = platformFrameworksDir.appendingPathComponent(framework)
    let result = FrameworkBuilder.syncExec(
      command: "/usr/bin/lipo",
      args: ["-create", "-output", fatArchive.path] + thinSlices.map { $0.value.path }
    )
    switch result {
    case let .error(code, output):
      fatalError("""
      lipo command exited with \(code) when trying to build \(framework). Output:
      \(output)
      """)
    case .success:
      print("lipo command for \(framework) succeeded.")
    }

    // Copy the framework and the fat binary artifact into the appropriate directory structure.
    let frameworkDir = platformFrameworksDir.appendingPathComponent(fromFolder.lastPathComponent)
    let archiveDestination = frameworkDir.appendingPathComponent(framework)
    do {
      try fileManager.copyItem(at: fromFolder, to: frameworkDir)
      try fileManager.copyItem(at: fatArchive, to: archiveDestination)
    } catch {
      fatalError("Could not create .framework needed to build \(framework) for Carthage: \(error)")
    }

    // Package the modulemaps. Special consideration is needed for Swift modules.
    packageModuleMaps(inFrameworks: slicedFrameworks.map { $0.value },
                      moduleMapContents: moduleMapContents,
                      destination: frameworkDir)

    // Carthage Resources are packaged in the framework.
    // Copy them instead of moving them, since they'll still need to be copied into the xcframework.
    let resourceDir = frameworkDir.appendingPathComponent("Resources")
    do {
      try ResourcesManager.moveAllBundles(inDirectory: resourceContents,
                                          to: resourceDir,
                                          keepOriginal: true)
    } catch {
      fatalError("Could not move bundles into Resources directory while building \(framework): " +
        "\(error)")
    }

    // Clean up the fat archive we built.
    do {
      try fileManager.removeItem(at: fatArchive)
    } catch {
      print("""
      Tried to remove fat binary for \(framework) at \(fatArchive.path) but couldn't. This is \
      not a failure, but you may want to remove the file afterwards to save disk space.
      """)
    }

    return frameworkDir
  }

  /// Takes existing fat frameworks (sliced per platform) and returns thin slices, excluding arm64
  /// simulator slices since Carthage can only create a regular framework.
  private func slicedBinariesForCarthage(fromFrameworks frameworks: [TargetPlatform: URL],
                                         workingDir: URL) -> [Architecture: URL] {
    // Exclude Catalyst.
    let platformsToInclude: [TargetPlatform] = frameworks.keys.filter { $0 != .catalyst }
    let builtSlices: [TargetPlatform: URL] = frameworks
      .filter { platformsToInclude.contains($0.key) }
      .mapValues { frameworkURL in
        // Get the path to the sliced binary instead of the framework.
        let frameworkName = frameworkURL.lastPathComponent
        let binaryName = frameworkName.replacingOccurrences(of: ".framework", with: "")
        return frameworkURL.appendingPathComponent(binaryName)
      }

    let fileManager = FileManager.default
    let individualSlices = workingDir.appendingPathComponent("slices")
    if !fileManager.directoryExists(at: individualSlices) {
      do {
        try fileManager.createDirectory(at: individualSlices,
                                        withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create a temp directory to store sliced binaries: \(error)")
      }
    }

    // Loop through and extract the necessary architectures.
    var slices: [Architecture: URL] = [:]
    for (platform, binary) in builtSlices {
      var archs = platform.archs
      if platform == .iOSSimulator {
        // Exclude the arm64 slice for simulator since Carthage can't package as an XCFramework.
        archs.removeAll(where: { $0 == .arm64 })
      }

      // Loop through the architectures and strip out each by using `lipo`.
      for arch in archs {
        // Create the path where the thin slice will reside, ensure it's non-existent.
        let destination = individualSlices.appendingPathComponent("\(arch.rawValue).a")
        fileManager.removeIfExists(at: destination)

        // Use lipo to extract the architecture we're looking for.
        let result = FrameworkBuilder.syncExec(command: "/usr/bin/lipo",
                                               args: [binary.path,
                                                      "-thin", arch.rawValue,
                                                      "-output", destination.path])
        switch result {
        case let .error(code, output):
          fatalError("""
          lipo command exited with \(code) when trying to extract the \(arch.rawValue) slice \
          from \(binary.path). Output:
          \(output)
          """)
        case .success:
          print("lipo successfully extracted the \(arch.rawValue) slice from \(binary.path)")
        }

        slices[arch] = destination
      }
    }

    return slices
  }
}
