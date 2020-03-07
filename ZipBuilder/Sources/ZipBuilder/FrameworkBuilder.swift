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

/// Different architectures to build frameworks for.
enum Architecture: String, CaseIterable {
  /// The target platform that the framework is built for.
  enum TargetPlatform: String, CaseIterable {
    case device = "iphoneos"
    case simulator = "iphonesimulator"
    case catalyst = "macosx"

    /// Extra C flags that should be included as part of the build process for each target platform.
    func otherCFlags() -> [String] {
      switch self {
      case .device:
        // For device, we want to enable bitcode.
        return ["-fembed-bitcode"]
      default:
        // No extra arguments are required for simulator builds.
        return []
      }
    }

    /// Arguments that should be included as part of the build process for each target platform.
    func extraArguments() -> [String] {
      let base = ["-sdk", rawValue]
      switch self {
      case .catalyst:
        return ["SKIP_INSTALL=NO",
                "BUILD_LIBRARIES_FOR_DISTRIBUTION=YES",
                "SUPPORTS_UIKITFORMAC=YES"]
      case .simulator, .device:
        // No extra arguments are required for simulator or device builds.
        return base
      }
    }
  }

  case arm64
  case armv7
  case i386
  case x86_64
  case x86_64h // x86_64h, Haswell, used for Mac Catalyst

  /// The platform associated with the architecture.
  var platform: TargetPlatform {
    switch self {
    case .armv7, .arm64: return .device
    case .i386, .x86_64: return .simulator
    case .x86_64h: return .catalyst
    }
  }
}

/// A structure to build a .framework in a given project directory.
struct FrameworkBuilder {
  /// The directory containing the Xcode project and Pods folder.
  private let projectDir: URL

  /// A flag to indicate this build is for carthage. This is primarily used for CoreDiagnostics.
  private let carthageBuild: Bool

  /// The Pods directory for building the framework.
  private var podsDir: URL {
    return projectDir.appendingPathComponent("Pods", isDirectory: true)
  }

  /// Default initializer.
  init(projectDir: URL, carthageBuild: Bool = false) {
    self.projectDir = projectDir
    self.carthageBuild = carthageBuild
  }

  // MARK: - Public Functions

  /// Build a fat library framework file for a given framework name.
  ///
  /// - Parameters:
  ///   - framework: The name of the Framework being built.
  ///   - version: String representation of the version.
  /// - Parameter logsOutputDir: The path to the directory to place build logs.
  /// - Parameter moduleMapContents: Module map contents for all frameworks in this pod.
  /// - Returns: A URL to the framework that was built (or pulled from the cache).
  func buildFramework(withName podName: String,
                      podInfo: CocoaPodUtils.PodInfo,
                      logsOutputDir: URL? = nil) -> URL {
    print("Building \(podName)")

    // Get (or create) the cache directory for storing built frameworks.
    let fileManager = FileManager.default
    var cachedFrameworkRoot: URL
    do {
      let subDir = carthageBuild ? "carthage" : ""
      let cacheDir = try fileManager.sourcePodCacheDirectory(withSubdir: subDir)
      cachedFrameworkRoot = cacheDir.appendingPathComponents([podName, podInfo.version])
    } catch {
      fatalError("Could not create caches directory for building frameworks: \(error)")
    }

    // Build the full cached framework path.
    let realFramework = frameworkBuildName(podName)
    let cachedFrameworkDir = cachedFrameworkRoot.appendingPathComponent("\(realFramework).xcframework")
    let frameworkDir = compileFrameworkAndResources(withName: podName, podInfo: podInfo)
    do {
      // Remove the previously cached framework if it exists, otherwise the `moveItem` call will
      // fail.
      fileManager.removeIfExists(at: cachedFrameworkDir)

      // Create the root cache directory if it doesn't exist.
      if !fileManager.directoryExists(at: cachedFrameworkRoot) {
        // If the root directory doesn't exist, create it so the `moveItem` will succeed.
        try fileManager.createDirectory(at: cachedFrameworkRoot,
                                        withIntermediateDirectories: true)
      }

      // Move the newly built framework to the cache directory.
      try fileManager.moveItem(at: frameworkDir, to: cachedFrameworkDir)
      return cachedFrameworkDir
    } catch {
      fatalError("Could not move built frameworks into the cached frameworks directory: \(error)")
    }
  }

  // MARK: - Private Helpers

  /// This runs a command and immediately returns a Shell result.
  /// NOTE: This exists in conjunction with the `Shell.execute...` due to issues with different
  ///       `.bash_profile` environment variables. This should be consolidated in the future.
  private func syncExec(command: String, args: [String] = [], captureOutput: Bool = false) -> Shell.Result {
    let task = Process()
    task.launchPath = command
    task.arguments = args

    // If we want to output to the console, create a readabilityHandler and save each line along the
    // way. Otherwise, we can just read the pipe at the end. By disabling outputToConsole, some
    // commands (such as any xcodebuild) can run much, much faster.
    var output: [String] = []
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
        output.append(line)
      }
      // Also set the termination handler on the task in order to stop the readabilityHandler from
      // parsing any more data from the task.
      task.terminationHandler = { t in
        guard let stdOut = t.standardOutput as? Pipe else { return }

        stdOut.fileHandleForReading.readabilityHandler = nil
      }
    } else {
      // No capturing output, just mark it as complete.
      output = ["The task completed"]
    }

    task.launch()
    task.waitUntilExit()

    let fullOutput = output.joined(separator: "\n")

    // Normally we'd use a pipe to retrieve the output, but for whatever reason it slows things down
    // tremendously for xcodebuild.
    guard task.terminationStatus == 0 else {
      return .error(code: task.terminationStatus, output: fullOutput)
    }

    return .success(output: fullOutput)
  }

  /// Uses `xcodebuild` to build a framework for a specific architecture slice.
  ///
  /// - Parameters:
  ///   - framework: Name of the framework being built.
  ///   - arch: Architecture slice to build.
  ///   - buildDir: Location where the project should be built.
  ///   - logRoot: Root directory where all logs should be written.
  /// - Returns: A URL to the thin library that was built.
  private func buildThin(framework: String,
                         archs: [Architecture],
                         buildDir: URL,
                         logRoot: URL) -> URL {
    let arch = archs[0]
    let isMacCatalyst = arch == Architecture.x86_64h
    let isMacCatalystString = isMacCatalyst ? "YES" : "NO"
    let platform = arch.platform
    let platformFolder = isMacCatalyst ? "maccatalyst" : platform.rawValue
    let workspacePath = projectDir.appendingPathComponent("FrameworkMaker.xcworkspace").path
    let distributionFlag = carthageBuild ? "-DFIREBASE_BUILD_CARTHAGE" : "-DFIREBASE_BUILD_ZIP_FILE"
    let platformSpecificFlags = platform.otherCFlags().joined(separator: " ")
    let cFlags = "OTHER_CFLAGS=$(value) \(distributionFlag) \(platformSpecificFlags)"
    let cleanArch = isMacCatalyst ? Architecture.x86_64.rawValue : archs.map { $0.rawValue }.joined(separator: " ")

    var args = ["build",
                "-configuration", "release",
                "-workspace", workspacePath,
                "-scheme", framework,
                "GCC_GENERATE_DEBUGGING_SYMBOLS=NO",
                "ARCHS=\(cleanArch)",
                "VALID_ARCHS=\(cleanArch)",
                "ONLY_ACTIVE_ARCH=NO",
                // BUILD_LIBRARY_FOR_DISTRIBUTION=YES is necessary for Swift libraries.
                // See https://forums.developer.apple.com/thread/125646.
                // Unlike the comment there, the option here is sufficient to cause .swiftinterface
                // files to be generated in the .swiftmodule directory. The .swiftinterface files
                // are required for xcodebuild to successfully generate an xcframework.
                "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
                "SUPPORTS_MACCATALYST=\(isMacCatalystString)",
                "BUILD_DIR=\(buildDir.path)",
                "-sdk", platform.rawValue,
                cFlags]
    // Code signing isn't needed for libraries. Disabling signing is required for
    // Catalyst libs with resources. See
    // https://github.com/CocoaPods/CocoaPods/issues/8891#issuecomment-573301570
    if isMacCatalyst {
      args.append("CODE_SIGN_IDENTITY=-")
    }
    print("""
    Compiling \(framework) for \(arch.rawValue) with command:
    /usr/bin/xcodebuild \(args.joined(separator: " "))
    """)

    // Regardless if it succeeds or not, we want to write the log to file in case we need to inspect
    // things further.
    let logFileName = "\(framework)-\(arch.rawValue)-\(platform.rawValue).txt"
    let logFile = logRoot.appendingPathComponent(logFileName)

    let result = syncExec(command: "/usr/bin/xcodebuild", args: args, captureOutput: true)
    switch result {
    case let .error(code, output):
      // Write output to disk and print the location of it. Force unwrapping here since it's going
      // to crash anyways, and at this point the root log directory exists, we know it's UTF8, so it
      // should pass every time. Revisit if that's not the case.
      try! output.write(to: logFile, atomically: true, encoding: .utf8)
      fatalError("Error building \(framework) for \(arch.rawValue). Code: \(code). See the build " +
        "log at \(logFile)")

    case let .success(output):
      // Try to write the output to the log file but if it fails it's not a huge deal since it was
      // a successful build.
      try? output.write(to: logFile, atomically: true, encoding: .utf8)
      print("""
      Successfully built \(framework) for \(arch.rawValue). Build log can be found at \(logFile)
      """)

      // Use the Xcode-generated path to return the path to the compiled library.
      // The framework name may be different from the pod name if the module is reset in the
      // podspec - like Release-iphonesimulator/BoringSSL-GRPC/openssl_grpc.framework.
      let frameworkPath = buildDir.appendingPathComponents(["Release-\(platformFolder)", framework])
      var actualFramework: String
      do {
        let files = try FileManager.default.contentsOfDirectory(at: frameworkPath,
                                                                includingPropertiesForKeys: nil).compactMap { $0.path }
        let frameworkDir = files.filter { $0.contains(".framework") }
        actualFramework = URL(fileURLWithPath: frameworkDir[0]).lastPathComponent
      } catch {
        fatalError("Error while enumerating files \(frameworkPath): \(error.localizedDescription)")
      }
      var libPath = frameworkPath.appendingPathComponent(actualFramework)
      if !LaunchArgs.shared.dynamic {
        libPath = libPath.appendingPathComponent(actualFramework.replacingOccurrences(of: ".framework", with: ""))
      }
      print("buildThin returns \(libPath)")
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
    if !LaunchArgs.shared.dynamic {
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
  /// This will compile all architectures and use the -create-xcframework command to create a modern "fat" framework.
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Parameter logsOutputDir: The path to the directory to place build logs.
  /// - Parameter moduleMapContents: Module map contents for all frameworks in this pod.
  /// - Returns: A path to the newly compiled framework (with any included Resources embedded).
  private func compileFrameworkAndResources(withName framework: String,
                                            logsOutputDir: URL? = nil,
                                            podInfo: CocoaPodUtils.PodInfo) -> URL {
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

    if LaunchArgs.shared.dynamic {
      return buildDynamicXCFramework(withName: framework, logsDir: logsDir, outputDir: outputDir)
    } else {
      return buildStaticXCFramework(withName: framework, logsDir: logsDir, outputDir: outputDir,
                                    podInfo: podInfo)
    }
  }

  /// Compiles the specified framework in a temporary directory and writes the build logs to file.
  /// This will compile all architectures and use the -create-xcframework command to create a modern "fat" framework.
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Parameter logsDir: The path to the directory to place build logs.
  /// - Returns: A path to the newly compiled framework (with any included Resources embedded).
  private func buildDynamicXCFramework(withName framework: String,
                                       logsDir: URL,
                                       outputDir: URL) -> URL {
    // xcframework doesn't lipo things together but accepts fat frameworks for one target.
    // We group architectures here to deal with this fact.
    let archs = LaunchArgs.shared.archs
    var groupedArchs: [[Architecture]] = []

    for platform in Architecture.TargetPlatform.allCases {
      groupedArchs.append(archs.filter { $0.platform == platform })
    }
    var thinArchives = [URL]()
    for archs in groupedArchs {
      let buildDir = projectDir.appendingPathComponent(archs[0].rawValue)
      let thinArchive = buildThin(framework: framework,
                                  archs: archs,
                                  buildDir: buildDir,
                                  logRoot: logsDir)
      thinArchives.append(thinArchive)
    }

    let frameworkDir = outputDir.appendingPathComponent("\(framework).xcframework")

    let inputArgs = thinArchives.flatMap { url -> [String] in
      ["-framework", url.path]
    }

    print("About to create xcframework for \(frameworkDir.path) with \(inputArgs)")

    let result = syncExec(command: "/usr/bin/xcodebuild", args: ["-create-xcframework", "-output", frameworkDir.path] + inputArgs)
    switch result {
    case let .error(code, output):
      fatalError("""
      xcodebuild -create-xcframework command exited with \(code) when trying to build \(framework). Output:
      \(output)
      """)
    case .success:
      print("xcodebuild -create-xcframework command for \(framework) succeeded.")
    }

    return frameworkDir
  }

  /// Compiles the specified framework in a temporary directory and writes the build logs to file.
  /// This will compile all architectures and use the -create-xcframework command to create a modern "fat" framework.
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Parameter logsDir: The path to the directory to place build logs.
  /// - Parameter moduleMapContents: Module map contents for all frameworks in this pod.
  /// - Returns: A path to the newly compiled framework (with any included Resources embedded).
  private func buildStaticXCFramework(withName framework: String,
                                      logsDir: URL,
                                      outputDir: URL,
                                      podInfo: CocoaPodUtils.PodInfo) -> URL {
    // Build every architecture and save the locations in an array to be assembled.
    var thinArchives = [Architecture: URL]()
    for arch in LaunchArgs.shared.archs {
      let buildDir = projectDir.appendingPathComponent(arch.rawValue)
      let thinArchive = buildThin(framework: framework,
                                  archs: [arch],
                                  buildDir: buildDir,
                                  logRoot: logsDir)
      thinArchives[arch] = thinArchive
    }

    // Create the framework directory in the filesystem for the thin archives to go.
    let fileManager = FileManager.default
    let frameworkDir = outputDir.appendingPathComponent("\(framework).framework")
    do {
      try fileManager.createDirectory(at: frameworkDir, withIntermediateDirectories: true)
    } catch {
      fatalError("Could not create framework directory while building framework \(framework). " +
        "\(error)")
    }

    // Find the location of the public headers.
    let anyArch = LaunchArgs.shared.archs[0] // any arch is ok, but need to make sure we're building it
    let archivePath = thinArchives[anyArch]!
    let headersDir = archivePath.deletingLastPathComponent().appendingPathComponent("Headers")

    // Find CocoaPods generated umbrella header.
    var umbrellaHeader = ""
    if framework == "gRPC-Core" {
      // TODO: Proper handling of podspec-specified module.modulemap files with customized umbrella
      // headers. This is good enough for Firebase since it doesn't need these modules.
      umbrellaHeader = "\(framework)-umbrella.h"
    } else {
      var umbrellaHeaderURL: URL
      do {
        let files = try fileManager.contentsOfDirectory(at: headersDir,
                                                        includingPropertiesForKeys: nil).compactMap { $0.path }
        let umbrellas = files.filter { $0.hasSuffix("umbrella.h") }
        if umbrellas.count != 1 {
          fatalError("Did not find exactly one umbrella header in \(headersDir).")
        }
        guard let firstUmbrella = umbrellas.first,
          let foundHeader = URL(string: firstUmbrella) else {
          fatalError("Failed to get umbrella header in \(headersDir).")
        }
        umbrellaHeaderURL = foundHeader
      } catch {
        fatalError("Error while enumerating files \(headersDir): \(error.localizedDescription)")
      }
      // Verify Firebase frameworks include an explicit umbrella header for Firebase.h.
      if framework.hasPrefix("Firebase"),
        framework != "FirebaseCoreDiagnostics",
        framework != "FirebaseUI",
        !framework.hasSuffix("Swift") {
        // Delete CocoaPods generated umbrella and use pre-generated one.
        do {
          try fileManager.removeItem(at: umbrellaHeaderURL)
        } catch let error as NSError {
          print("Failed to delete: \(umbrellaHeaderURL). Error: \(error.domain)")
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

    // TODO: copy PrivateHeaders directory as well if it exists. SDWebImage is an example pod.

    // Move all the Resources into .bundle directories in the destination Resources dir. The
    // Resources live are contained within the folder structure:
    // `projectDir/arch/Release-platform/FrameworkName`

    let contentsDir = projectDir.appendingPathComponents([anyArch.rawValue,
                                                          "Release-\(anyArch.platform.rawValue)",
                                                          framework])
    let resourceDir = frameworkDir.appendingPathComponent("Resources")
    do {
      try ResourcesManager.moveAllBundles(inDirectory: contentsDir, to: resourceDir)
    } catch {
      fatalError("Could not move bundles into Resources directory while building \(framework): " +
        "\(error)")
    }

    guard let moduleMapContents = podInfo.moduleMapContents else {
      fatalError("Module map contents missing for framework \(framework)")
    }
    let xcframework = packageXCFramework(withName: framework,
                                         fromFolder: frameworkDir,
                                         thinArchives: thinArchives,
                                         moduleMapContents:
                                         moduleMapContents.get(umbrellaHeader: umbrellaHeader))

    // Remove the temporary thin archives.
    for thinArchive in thinArchives.values {
      do {
        try fileManager.removeItem(at: thinArchive)
      } catch {
        // Just log a warning instead of failing, since this doesn't actually affect the build
        // itself. This should only be shown to help users clean up their disk afterwards.
        print("""
        WARNING: Failed to remove temporary thin archive at \(thinArchive.path). This should be
        removed from your system to save disk space. \(error). You should be able to remove the
        archive from Terminal with:
        rm \(thinArchive.path)
        """)
      }
    }

    return xcframework
  }

  private func packageFramework(withName framework: String,
                                fromFolder: URL,
                                thinArchives: [Architecture: URL],
                                destination: URL,
                                moduleMapContents: String) {
    // Store all fat archives in a temporary directory that includes all architectures included as
    // the parent folder.
    let fatArchivesDir: URL = {
      let allArchivesDir = FileManager.default.temporaryDirectory(withName: "fat_archives")
      let architectures = thinArchives.keys.map { $0.rawValue }.sorted()
      return allArchivesDir.appendingPathComponent(architectures.joined(separator: "_"))
    }()

    do {
      let fileManager = FileManager.default
      try fileManager.createDirectory(at: fatArchivesDir, withIntermediateDirectories: true)
      // Remove any previously built fat archives.
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }

      try FileManager.default.copyItem(at: fromFolder, to: destination)
    } catch {
      fatalError("Could not create directories needed to build \(framework): \(error)")
    }

    // Build the fat archive using the `lipo` command. We need the full archive path.
    let fatArchive = fatArchivesDir.appendingPathComponent(framework)
    let result = syncExec(command: "/usr/bin/lipo", args: ["-create", "-output", fatArchive.path] +
      thinArchives.map { $0.value.path })
    switch result {
    case let .error(code, output):
      fatalError("""
      lipo command exited with \(code) when trying to build \(framework). Output:
      \(output)
      """)
    case .success:
      print("lipo command for \(framework) succeeded.")
    }

    // Copy the built binary to the destination.
    let archiveDestination = destination.appendingPathComponent(framework)
    do {
      try FileManager.default.copyItem(at: fatArchive, to: archiveDestination)
    } catch {
      fatalError("Could not copy \(framework) to destination: \(error)")
    }

    // For Swift modules, we use the modulemap from the xcodebuild. For Objective C modules,
    // We use the constructed module map that includes required framework and library
    // dependencies.
    if !makeSwiftModuleMap(thinArchives: thinArchives, destination: destination) {
      // Copy the module map to the destination.
      let moduleDir = destination.appendingPathComponent("Modules")
      do {
        try FileManager.default.createDirectory(at: moduleDir, withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create Modules directory for framework: \(framework). \(error)")
      }
      let modulemap = moduleDir.appendingPathComponent("module.modulemap")
      do {
        try moduleMapContents.write(to: modulemap, atomically: true, encoding: .utf8)
      } catch {
        fatalError("Could not write modulemap to disk for \(framework): \(error)")
      }
    }
  }

  private func makeSwiftModuleMap(thinArchives: [Architecture: URL], destination: URL) -> Bool {
    let fileManager = FileManager.default
    for archive in thinArchives {
      let frameworkDir = archive.value.deletingLastPathComponent()
      // Get the Modules directory. The Catalyst one is a symbolic link.
      let moduleDir = frameworkDir.appendingPathComponent("Modules").resolvingSymlinksInPath()
      do {
        let files = try fileManager.contentsOfDirectory(at: moduleDir,
                                                        includingPropertiesForKeys: nil).compactMap { $0.path }
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
            fatalError("Could not copy Modules from \(moduleDir) to " + "\(destModuleDir): \(error)")
          }
        } else {
          // If the Modules directory is already there, only copy in the architecture specific files
          // from the *.swiftmodule subdirectory.
          do {
            let files = try fileManager.contentsOfDirectory(at: swiftModule,
                                                            includingPropertiesForKeys: nil).compactMap { $0.path }
            let destSwiftModuleDir = destModuleDir.appendingPathComponent(swiftModule.lastPathComponent)
            for file in files {
              let fileURL = URL(fileURLWithPath: file)
              do {
                try fileManager.copyItem(at: fileURL, to:
                  destSwiftModuleDir.appendingPathComponent(fileURL.lastPathComponent))
              } catch {
                fatalError("Could not copy Swift module file from \(fileURL) to " + "\(destSwiftModuleDir): \(error)")
              }
            }
          } catch {
            fatalError("Failed to get Modules directory contents - \(moduleDir): \(error.localizedDescription)")
          }
        }
      } catch {
        fatalError("Error while enumerating files \(moduleDir): \(error.localizedDescription)")
      }
    }
    return true
  }

  /// Packages an XCFramework based on an almost complete framework folder (missing the binary but includes everything else needed)
  /// and thin archives for each architecture slice.
  /// - Parameter withName: The framework name.
  /// - Parameter fromFolder: The almost complete framework folder. Includes everything but the binary.
  /// - Parameter thinArchives: All the thin archives.
  /// - Parameter moduleMapContents: Module map contents for all frameworks in this pod.
  private func packageXCFramework(withName framework: String,
                                  fromFolder: URL,
                                  thinArchives: [Architecture: URL],
                                  moduleMapContents: String) -> URL {
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
    for platform in Architecture.TargetPlatform.allCases {
      // Get all the slices that belong to the specific platform in order to lipo them together.
      let slices = thinArchives.filter { $0.key.platform == platform }
      if slices.isEmpty {
        continue
      }
      let platformDir = platformFrameworksDir.appendingPathComponent(platform.rawValue)
      do {
        try fileManager.createDirectory(at: platformDir, withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create directory for architecture slices on \(platform) for " +
          "\(framework): \(error)")
      }

      // Package a normal .framework with the given slices.
      let destination = platformDir.appendingPathComponent(fromFolder.lastPathComponent)
      packageFramework(withName: framework,
                       fromFolder: fromFolder,
                       thinArchives: slices,
                       destination: destination,
                       moduleMapContents: moduleMapContents)

      frameworksBuilt.append(destination)
    }

    // We now need to package those built frameworks into an XCFramework.
    let xcframeworksDir = projectDir.appendingPathComponent("xcframeworks")
    if !fileManager.directoryExists(at: xcframeworksDir) {
      do {
        try fileManager.createDirectory(at: xcframeworksDir,
                                        withIntermediateDirectories: true)
      } catch {
        fatalError("Could not create XCFrameworks directory: \(error)")
      }
    }

    let xcframework = xcframeworksDir.appendingPathComponent(framework + ".xcframework")
    if fileManager.fileExists(atPath: xcframework.path) {
      try! fileManager.removeItem(at: xcframework)
    }

    // The arguments for the frameworks need to be separated.
    var frameworkArgs: [String] = []
    for frameworkBuilt in frameworksBuilt {
      frameworkArgs.append("-framework")
      frameworkArgs.append(frameworkBuilt.path)
    }

    let outputArgs = ["-output", xcframework.path]
    let result = syncExec(command: "/usr/bin/xcodebuild",
                          args: ["-create-xcframework"] + frameworkArgs + outputArgs,
                          captureOutput: true)
    switch result {
    case let .error(code, output):
      fatalError("Could not build xcframework for \(framework) exit code \(code): \(output)")

    case .success:
      print("XCFramework for \(framework) built successfully at \(xcframework).")
    }

    return xcframework
  }
}
