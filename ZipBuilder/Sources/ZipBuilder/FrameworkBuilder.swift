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
public enum Architecture: String, CaseIterable {
  /// The target platform that the framework is built for.
  enum TargetPlatform: String {
    case device = "iphoneos"
    case simulator = "iphonesimulator"

    /// Extra C flags that should be included as part of the build process for each target platform.
    func otherCFlags() -> [String] {
      switch self {
      case .device:
        // For device, we want to enable bitcode.
        return ["-fembed-bitcode"]
      case .simulator:
        // No extra arguments are required for simulator builds.
        return []
      }
    }
  }

  case arm64
  case arm64e
  case armv7
  case i386
  case x86_64

  /// The platform associated with the architecture.
  var platform: TargetPlatform {
    switch self {
    case .arm64, .arm64e, .armv7: return .device
    case .i386, .x86_64: return .simulator
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
  /// - Returns: A URL to the framework that was built (or pulled from the cache).
  public func buildFramework(withName podName: String,
                             version: String,
                             logsOutputDir: URL? = nil) -> URL {
    print("Building \(podName)")

    // Get (or create) the cache directory for storing built frameworks.
    let fileManager = FileManager.default
    var cachedFrameworkRoot: URL
    do {
      let subDir = carthageBuild ? "carthage" : ""
      let cacheDir = try fileManager.sourcePodCacheDirectory(withSubdir: subDir)
      cachedFrameworkRoot = cacheDir.appendingPathComponents([podName, version])
    } catch {
      fatalError("Could not create caches directory for building frameworks: \(error)")
    }

    // Build the full cached framework path.
    let cachedFrameworkDir = cachedFrameworkRoot.appendingPathComponent("\(podName).framework")
    let frameworkDir = compileFrameworkAndResources(withName: podName)
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
                         arch: Architecture,
                         buildDir: URL,
                         logRoot: URL) -> URL {
    let platform = arch.platform
    let workspacePath = projectDir.appendingPathComponent("FrameworkMaker.xcworkspace").path
    let distributionFlag = carthageBuild ? "-DFIREBASE_BUILD_CARTHAGE" : "-DFIREBASE_BUILD_ZIP_FILE"
    let platformSpecificFlags = platform.otherCFlags().joined(separator: " ")
    let cFlags = "OTHER_CFLAGS=$(value) \(distributionFlag) \(platformSpecificFlags)"
    let args = ["build",
                "-configuration", "release",
                "-workspace", workspacePath,
                "-scheme", framework,
                "GCC_GENERATE_DEBUGGING_SYMBOLS=No",
                "ARCHS=\(arch.rawValue)",
                "BUILD_DIR=\(buildDir.path)",
                "-sdk", platform.rawValue,
                cFlags]
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
      let libPath = buildDir.appendingPathComponents(["Release-\(platform.rawValue)",
                                                      framework,
                                                      "lib\(framework).a"])
      return libPath
    }
  }

  /// Compiles the specified framework in a temporary directory and writes the build logs to file.
  /// This will compile all architectures and use the lipo command to create a "fat" archive.
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Parameter logsOutputDir: The path to the directory to place build logs.
  /// - Returns: A path to the newly compiled framework (with any included Resources embedded).
  private func compileFrameworkAndResources(withName framework: String,
                                            logsOutputDir: URL? = nil) -> URL {
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

    // Build every architecture and save the locations in an array to be assembled.
    // TODO: Pass in supported architectures here, for those open source SDKs that don't support
    // individual architectures.
    var thinArchives = [URL]()
    for arch in LaunchArgs.shared.archs {
      let buildDir = projectDir.appendingPathComponent(arch.rawValue)
      let thinArchive = buildThin(framework: framework,
                                  arch: arch,
                                  buildDir: buildDir,
                                  logRoot: logsDir)
      thinArchives.append(thinArchive)
      // TODO DElete next line before merge
      break
    }

    // Create the framework directory in the filesystem for the thin archives to go.
    let frameworkDir = outputDir.appendingPathComponent("\(framework).framework")
    do {
      try fileManager.createDirectory(at: frameworkDir, withIntermediateDirectories: true)
    } catch {
      fatalError("Could not create framework directory while building framework \(framework). " +
        "\(error)")
    }

    // Build the fat archive using the `lipo` command. We need the full archive path and the list of
    // thin paths (as Strings, not URLs).
    let thinPaths = thinArchives.map { $0.path }
    let fatArchive = frameworkDir.appendingPathComponent(framework)
    let result = syncExec(command: "/usr/bin/lipo", args: ["-create", "-output", fatArchive.path] + thinPaths)
    switch result {
    case let .error(code, output):
      fatalError("""
      lipo command exited with \(code) when trying to build \(framework). Output:
      \(output)
      """)
    case .success:
      print("lipo command for \(framework) succeeded.")
    }

    // Remove the temporary thin archives.
    for thinArchive in thinArchives {
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

    // Verify Firebase headers include an explicit umbrella header for Firebase.h.
    let headersDir = podsDir.appendingPathComponents(["Headers", "Public", framework])
    if framework.hasPrefix("Firebase"), framework != "FirebaseCoreDiagnostics" {
      let frameworkHeader = headersDir.appendingPathComponent("\(framework).h")
      guard fileManager.fileExists(atPath: frameworkHeader.path) else {
        fatalError("Missing explicit umbrella header for \(framework).")
      }
    }

    // Copy the Headers over. Pass in the prefix to remove in order to generate the relative paths
    // for some frameworks that have nested folders in their public headers.
    let headersDestination = frameworkDir.appendingPathComponent("Headers")
    do {
      try recursivelyCopyHeaders(from: headersDir, to: headersDestination)
    } catch {
      fatalError("Could not copy headers from \(headersDir) to Headers directory in " +
        "\(headersDestination): \(error)")
    }

    // Move all the Resources into .bundle directories in the destination Resources dir. The
    // Resources live are contained within the folder structure:
    // `projectDir/arch/Release-platform/FrameworkName`
    let arch = Architecture.arm64
    let contentsDir = projectDir.appendingPathComponents([arch.rawValue,
                                                          "Release-\(arch.platform.rawValue)",
                                                          framework])
    let resourceDir = frameworkDir.appendingPathComponent("Resources")
    do {
      try ResourcesManager.moveAllBundles(inDirectory: contentsDir, to: resourceDir)
    } catch {
      fatalError("Could not move bundles into Resources directory while building \(framework): " +
        "\(error)")
    }

    return frameworkDir
  }

  /// Recrusively copies headers from the given directory to the destination directory. This does a
  /// deep copy and resolves and symlinks (which CocoaPods uses in the Public headers folder).
  /// Throws FileManager errors if something goes wrong during the operations.
  /// Note: This is only needed now because the `cp` command has a flag that did this for us, but
  /// FileManager does not.
  private func recursivelyCopyHeaders(from headersDir: URL,
                                      to destinationDir: URL,
                                      fileManager: FileManager = FileManager.default) throws {
    // Copy the public headers into the new framework. Unfortunately we can't just copy the
    // `Headers` directory since it uses aliases, so we'll recursively search the public Headers
    // directory from CocoaPods and resolve all the aliases manually.
    let fileManager = FileManager.default

    // Create the Headers directory if it doesn't exist.
    try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)

    // Get all the header aliases from the CocoaPods directory and get their real path as well as
    // their relative path to the Headers directory they are in. This is needed to preserve proper
    // imports for nested folders.
    let aliasedHeaders = try fileManager.recursivelySearch(for: .headers, in: headersDir)
    let mappedHeaders: [(relativePath: String, resolvedLocation: URL)] = aliasedHeaders.map {
      // The `headersDir` and `aliasedHeader` prefixes may be different, but they both should have
      // `Pods/Headers/` in the path. Ignore everything up until that, then strip the remainder of
      // the `headersDir` from the `aliasedHeader` in order to get path relative to the headers
      // directory.
      let trimmedHeader = removeHeaderPathPrefix(from: $0)
      let trimmedDir = removeHeaderPathPrefix(from: headersDir)
      var relativePath = trimmedHeader.replacingOccurrences(of: trimmedDir, with: "")

      // Remove any leading `/` for the relative path.
      if relativePath.starts(with: "/") {
        _ = relativePath.removeFirst()
      }

      // Standardize the URL because the aliasedHeaders could be at `/private/var` or `/var` which
      // are symlinked to each other on macOS.
      let resolvedLocation = $0.standardizedFileURL.resolvingSymlinksInPath()
      return (relativePath, resolvedLocation)
    }

    // Copy all the headers into the Headers directory created above.
    for (relativePath, location) in mappedHeaders {
      // Append the proper filename to our Headers directory, then try copying it over.
      let finalPath = destinationDir.appendingPathComponent(relativePath)

      // Create the destination folder if it doesn't exist.
      let parentDir = finalPath.deletingLastPathComponent()
      if !fileManager.directoryExists(at: parentDir) {
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
      }

      try fileManager.copyItem(at: location, to: finalPath)
    }
  }

  private func removeHeaderPathPrefix(from url: URL) -> String {
    let fullPath = url.standardizedFileURL.path
    guard let foundRange = fullPath.range(of: "Pods/Headers/") else {
      fatalError("Could not copy headers for framework: full path do not contain `Pods/Headers`:" +
        fullPath)
    }

    // Replace everything from the start of the string until the end of the `Pods/Headers/`.
    let toRemove = fullPath.startIndex ..< foundRange.upperBound
    return fullPath.replacingCharacters(in: toRemove, with: "")
  }
}
