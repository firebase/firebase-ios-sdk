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

/// Extra URL utilities.
fileprivate extension URL {
  func appendingPathComponents(_ components: [String]) -> URL {
    // Append multiple path components in a single call to prevent long lines of multiple calls.
    var result = self
    components.forEach({ result.appendPathComponent($0) })
    return result
  }
}

/// Different architectures to build frameworks for.
fileprivate enum Architecture : String {
  /// The target platform that the framework is built for.
  enum TargetPlatform : String {
    case device = "iphoneos"
    case simulator = "iphonesimulator"

    /// Arguments that should be included as part of the build process for each target platform.
    func extraArguments() -> [String] {
      switch self {
      case .device:
        // For device, we want to enable bitcode.
        return ["OTHER_CFLAGS=$(value) " + "-fembed-bitcode"]
      case .simulator:
        // No extra arguments are required for simulator builds.
        return []
      }
    }
  }

  case arm64
  case armv7
  case i386
  case x86_64

  /// The platform associated with the architecture.
  var platform: TargetPlatform {
    switch self {
    case .arm64, .armv7: return .device
    case .i386, .x86_64: return .simulator
    }
  }

  // TODO: Once we default to Swift 4.2 (in Xcode 10) we can conform to "CaseIterable" protocol to
  //       automatically generate this method.
  /// All the architectures to parse.
  public static func allCases() -> [Architecture] { return [.arm64, .armv7, .i386, .x86_64] }
}

/// A structure to build a .framework in a given project directory.
struct FrameworkBuilder {

  /// The directory containing the Xcode project and Pods folder.
  private let projectDir: URL

  /// The Pods directory for building the framework.
  private var podsDir: URL {
    return self.projectDir.appendingPathComponent("Pods", isDirectory: true)
  }

  /// Default initializer.
  init(projectDir: URL) {
    self.projectDir = projectDir
  }

  // MARK: - Public Functions

  /// Build a fat library framework file for a given framework name.
  ///
  /// - Parameters:
  ///   - framework: The name of the Framework being built.
  ///   - version: String representation of the version.
  ///   - cacheKey: The key used for caching this framework build. If nil, the framework name will
  ///               be used.
  ///   - cacheEnabled: Flag for enabling the cache. Defaults to false.
  /// - Returns: A URL to the framework that was built (or pulled from the cache).
  public func buildFramework(withName framework: String, version: String, cacheKey: String?, cacheEnabled: Bool = false) -> URL {
    print("Building \(framework)")

    // Get the CocoaPods cache to see if we can pull from any frameworks already built.
    let podsCache = CocoaPodUtils.listPodCache(inDir: projectDir)

    guard let cachedVersions = podsCache[framework] else {
      fatalError("Cannot find a pod cache for framework \(framework).")
    }

    guard let podInfo = cachedVersions[version] else {
      fatalError("Cannot find a pod cache for framework \(framework) at version \(version).")
    }

    // TODO: Figure out if we need the MD5 at all.
    let md5 = Shell.calculateMD5(for: podInfo.installedLocation)

    // Get (or create) the cache directory for storing built frameworks.
    let fileManager = FileManager.default
    var cachedFrameworkRoot: URL
    do {
      let cacheDir = try fileManager.firebaseCacheDirectory()
      cachedFrameworkRoot = cacheDir.appendingPathComponents([framework, version, md5])
      if let cacheKey = cacheKey {
        cachedFrameworkRoot.appendPathComponent(cacheKey)
      }
    } catch {
      fatalError("Could not create caches directory for building frameworks: \(error)")
    }

    // Build the full cached framework path.
    let cachedFrameworkDir = cachedFrameworkRoot.appendingPathComponent("\(framework).framework")
    let cachedFrameworkExists = fileManager.directoryExists(at: cachedFrameworkDir)
    if cachedFrameworkExists && cacheEnabled {
      print("Framework \(framework) version \(version) has already been built and cached at " +
            "\(cachedFrameworkDir)")
      return cachedFrameworkDir
    } else {
      let frameworkDir = compileFramework(withName: framework)
      do {
        // Remove the previously cached framework, if it exists, otherwise the `moveItem` call will
        // fail.
        if cachedFrameworkExists {
          try fileManager.removeItem(at: cachedFrameworkDir)
        } else if !fileManager.directoryExists(at: cachedFrameworkRoot) {
          // If the root directory doesn't exist, create it so the `moveItem` will succeed.
          try fileManager.createDirectory(at: cachedFrameworkRoot,
                                          withIntermediateDirectories: true,
                                          attributes: nil)
        }

        // Move the newly built framework to the cache directory.
        try fileManager.moveItem(at: frameworkDir, to: cachedFrameworkDir)
        return cachedFrameworkDir
      } catch {
        fatalError("Could not move built frameworks into the cached frameworks directory: \(error)")
      }
    }
  }

  // MARK: - Private Helpers

  /// This runs a command and immediately returns a Shell result.
  /// NOTE: This exists in conjunction with the `Shell.execute...` due to issues with different
  ///       `.bash_profile` environment variables. This should be consolidated in the future.
  private func syncExec(command: String, args: [String] = []) -> Shell.Result {
    let task = Process()
    task.launchPath = command
    task.arguments = args
    task.launch()
    task.waitUntilExit()

    // Normally we'd use a pipe to retrieve the output, but for whatever reason it slows things down
    // tremendously for xcodebuild.
    let output = "The task completed."
    guard (task.terminationStatus == 0) else {
      return .error(code: task.terminationStatus, output: output)
    }

    return .success(output: output)
  }

  /// Uses `xcodebuild` to build a framework for a specific architecture slice.
  ///
  /// - Parameters:
  ///   - framework: Name of the framework being built.
  ///   - arch: Architecture slice to build.
  ///   - logRoot: Root directory where all logs should be written.
  /// - Returns: A URL to the thin library that was built.
  private func buildThin(framework: String, arch: Architecture, logRoot: URL) -> URL {
    let buildDir = projectDir.appendingPathComponent(arch.rawValue)
    let platform = arch.platform
    let workspacePath = projectDir.appendingPathComponent("FrameworkMaker.xcworkspace").path
    let standardOptions = [ "build",
                            "-configuration", "release",
                            "-workspace", workspacePath,
                            "-scheme", framework,
                            "GCC_GENERATE_DEBUGGING_SYMBOLS=No",
                            "ARCHS=\(arch.rawValue)",
                            "BUILD_DIR=\(buildDir.path)",
                            "-sdk", platform.rawValue]
    let args = standardOptions + platform.extraArguments()
    print("""
      Compiling \(framework) for \(arch.rawValue) with command:
      /usr/bin/xcodebuild \(args.joined(separator: " "))
      """)

    // Regardless if it succeeds or not, we want to write the log to file in case we need to inspect
    // things further.
    let logFileName = "\(framework)-\(arch.rawValue)-\(platform.rawValue).txt"
    let logFile = logRoot.appendingPathComponent(logFileName)

    let result = syncExec(command: "/usr/bin/xcodebuild", args: args)
    switch result {
    case let .error(code, output):
      // Write output to disk and print the location of it. Force unwrapping here since it's going
      // to crash anyways, and at this point the root log directory exists, we know it's UTF8, so it
      // should pass every time. Revisit if that's not the case.
      try! output.write(to: logFile, atomically: true, encoding: .utf8)
      fatalError("Error building \(framework) for \(arch.rawValue). Code: \(code). See the build " +
                 "log at \(logFile)")

    case .success(let output):
      // Try to write the output to the log file but if it fails it's not a huge deal since it was
      // a successful build.
      try? output.write(to: logFile, atomically: true, encoding: .utf8)

      // Use the Xcode-generated path to return the path to the compiled library.
      let libPath = buildDir.appendingPathComponents(["Release-\(platform.rawValue)",
        framework,
        "lib\(framework).a"])
      return libPath
    }
  }

  // Extract the framework and library dependencies for a framework from
  // Pods/Target Support Files/{framework}/{framework}.xcconfig.
  private func getModuleDependencies(forFramework framework: String) ->
    (frameworks: [String], libraries: [String]) {
      let xcconfigFile = podsDir.appendingPathComponents(["Target Support Files",
                                                          framework,
                                                          "\(framework).xcconfig"])
      do {
        let text = try String(contentsOf: xcconfigFile)
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
          if (line.hasPrefix("OTHER_LDFLAGS =")) {
            var dependencyFrameworks: [String] = []
            var dependencyLibraries: [String] = []
            let tokens = line.components(separatedBy: " ")
            var addNext = false
            for token in tokens {
              if addNext {
                dependencyFrameworks.append(token)
                addNext = false
              } else if token == "-framework" {
                addNext = true
              } else if token.hasPrefix("-l") {
                let index = token.index(token.startIndex, offsetBy: 2)
                dependencyLibraries.append(String(token[index...]))
              }
            }
            
            return (dependencyFrameworks, dependencyLibraries)
          }
        }
      } catch {
        fatalError("Failed to open \(xcconfigFile): \(error)")
      }
      return ([], [])
  }

  private func makeModuleMap(baseDir: URL, framework: String, dir: URL) {
    let dependencies = getModuleDependencies(forFramework: framework)
    let moduleDir = dir.appendingPathComponent("Modules")
    do {
      try FileManager.default.createDirectory(at: moduleDir,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
    } catch {
      fatalError("Could not create Modules directory for framework: \(framework). \(error)")
    }

    let modulemap = moduleDir.appendingPathComponent("module.modulemap")
    // The base of the module map. The empty line at the end is intentional, do not remove it.
    var content = """
    framework module \(framework) {
    umbrella header "\(framework).h"
    export *
    module * { export * }

    """
    for framework in dependencies.frameworks {
      content += "  link framework " + framework + "\n"
    }
    for library in dependencies.libraries {
      content += "  link " + library + "\n"
    }
    content += "}\n"

    do {
      try content.write(to: modulemap, atomically: true, encoding: .utf8)
    } catch {
      fatalError("Could not write modulemap to disk for \(framework): \(error)")
    }
  }


  /// Compiles the framework passed in in a temporary directory and writes the build logs to file.
  /// This will compile all architectures and use the lipo command to create a "fat archive".
  ///
  /// - Parameter framework: The name of the framework to be built.
  /// - Returns: A path to the newly compiled framework.
  private func compileFramework(withName framework: String) -> URL {
    let fileManager = FileManager.default
    let outputDir = fileManager.temporaryDirectory(withName: "frameworkBeingBuilt")
    let logsDir = fileManager.temporaryDirectory(withName: "buildLogs")
    do {
      // Remove the compiled frameworks directory, this isn't the cache we're using.
      if fileManager.directoryExists(at: outputDir) {
        try fileManager.removeItem(at: outputDir)
      }

      try fileManager.createDirectory(at: outputDir,
                                      withIntermediateDirectories: true,
                                      attributes: nil)

      // Create our logs directory if it doesn't exist.
      if !fileManager.directoryExists(at: logsDir) {
        try fileManager.createDirectory(at: logsDir,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
      }
    } catch {
      fatalError("Failure creating temporary directory while building \(framework): \(error)")
    }

    // Build every architecture and save the locations in an array to be assembled.
    // TODO: Pass in supported architectures here, for those that don't support individual
    // architectures (MLKit).
    var thinArchives = [URL]()
    for arch in Architecture.allCases() {
      let thinArchive = buildThin(framework: framework, arch: arch, logRoot: logsDir)
      thinArchives.append(thinArchive)
    }

    // Create the framework directory in the filesystem for the thin archives to go.
    let frameworkDir = outputDir.appendingPathComponent("\(framework).framework")
    do {
      try fileManager.createDirectory(at: frameworkDir,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
    } catch {
      fatalError("Could not create framework directory while building framework \(framework). " +
        "\(error)")
    }

    // Build the fat archive using the `lipo` command. We need the full archive path and the list of
    // thin paths (as Strings, not URLs).
    let thinPaths = thinArchives.map({ $0.path })
    let fatArchive = frameworkDir.appendingPathComponent(framework)
    let result = syncExec(command:"/usr/bin/lipo", args:["-create", "-output", fatArchive.path] + thinPaths)
    switch result {
    case let .error(code, output):
      fatalError("""
        lipo command exited with \(code) when trying to build \(framework). Output:
        \(output)
        """)
    case .success(_):
      print("lipo command for \(framework) succeeded.")
    }

    // Remove the temporary thin archives.
    for thinArchive in thinArchives {
      do {
        try FileManager.default.removeItem(at: thinArchive)
      } catch {
        // Just log a warning instead of failing, since this doesn't actually affect the build
        // itself. This should only be shown to help users clean up their disk afterwards.
        print("""
          WARNING: Failed to remove temporary thin archive at \(thinArchive). This should be
          removed from your system to save disk space. \(error). You should be able to remove the
          archive from Terminal with:
          rm \(thinArchive)
          """)
      }
    }

    // Verify Firebase headers include an explicit umbrella header for Firebase.h
    let headersDir = podsDir.appendingPathComponents(["Headers", "Public", framework])
    if framework.hasPrefix("Firebase") {
      let frameworkHeader = headersDir.appendingPathComponent("\(framework).h")
      guard fileManager.fileExists(atPath: frameworkHeader.path) else {
        fatalError("Missing explicit umbrella header for \(framework).")
      }
    }

    // Copy the public headers into the new framework.
    do {
      try fileManager.copyItem(at: headersDir, to: frameworkDir.appendingPathComponent("Headers"))
    } catch {
      fatalError("Could not copy headers from \(headersDir) to Headers directory in " +
        "\(frameworkDir): \(error)")
    }

    // Move all the .bundle directories in the contentsDir to the Resources directory.
    let contentsDir = thinArchives[0].deletingLastPathComponent()
    let resourceDir = frameworkDir.appendingPathComponent("Resources")
    do {
      try ResourcesManager.moveAllBundles(inDirectory: contentsDir, to: resourceDir)
    } catch {
      fatalError("Could not move bundles into Resources directory while building \(framework): " +
                 "\(error)")
    }

    makeModuleMap(baseDir: outputDir, framework: framework, dir: frameworkDir)
    return frameworkDir
  }
}
