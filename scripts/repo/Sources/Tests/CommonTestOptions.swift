/*
 * Copyright 2026 Google LLC
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
import Logging
import Util

/// Shared options for build and test commands.
struct CommonTestOptions: ParsableArguments {
  @Option(
    help:
    """
    Xcode version to run tests against. \
    Can be either the application name, or a full path (eg; "Xcode_16.4.0" or "/Applications/Xcode_16.4.0.app").
    By default, the script will look for your local Xcode installation.
    """
  )
  var xcode: String = ""

  @Option(help: "Platforms to run tests on.")
  var platforms: [Platform] = [.iOS]

  @Option(help: "Path to a json file containing an array of secret files to use, if any.")
  var secrets: String? = nil

  @Flag(help: "Overwrite existing decrypted secret files.")
  var overwrite: Bool = false

  @Argument(
    help: """
    The SDK to build or run integration tests for.
    There should be a build target for the SDK that follows the format "Firebase{SDK}Integration"
    """
  )
  var sdk: String

  /// Resolves and returns the path to the validated Xcode installation.
  func resolveXcodePath(logger: Logger) throws -> String {
    if xcode.isEmpty {
      return try findAndValidateXcodeOnDisk(logger: logger)
    } else {
      return try validateProvidedXcode(logger: logger)
    }
  }

  /// Decrypts secrets and executes a block, ensuring decrypted files are deleted afterwards.
  func withDecryptedSecrets<T>(logger: Logger, _ operation: () throws -> T) throws -> T {
    var secretFiles: [SecretFile] = []

    defer {
      for file in secretFiles {
        guard FileManager.default.fileExists(atPath: file.destination) else { continue }
        do {
          logger.debug("Deleting secret file", metadata: ["file": "\(file.destination)"])
          try FileManager.default.removeItem(atPath: file.destination)
        } catch {
          logger.error(
            "Failed to delete secret file.",
            metadata: [
              "file": "\(file.destination)",
              "error": "\(error.localizedDescription)",
            ]
          )
        }
      }
    }

    if let secrets {
      var args = ["--json"]
      if overwrite {
        args.append("--overwrite")
      }
      args.append(secrets)
      var decrypt = try Decrypt.parse(args)
      try decrypt.validate()
      secretFiles = decrypt.files
      try decrypt.run()
    }

    return try operation()
  }

  /// Runs `scripts/build.sh` for each specified platform with the given method and extra arguments.
  func runBuildScript(method: String,
                      actionDescription: String,
                      xcodePath: String,
                      extraArguments: [String] = [],
                      logger: Logger) throws {
    let buildScript = URL(filePath: "scripts/build.sh", relativeTo: URL.currentDirectory())

    for platform in platforms {
      logger.info(
        "\(actionDescription)",
        metadata: ["sdk": "\(sdk)", "platform": "\(platform)"]
      )

      let build = Process(
        buildScript.path(percentEncoded: false),
        env: ["DEVELOPER_DIR": "\(xcodePath)/Contents/Developer"],
        inheritEnvironment: true
      )

      let exitCode = try build.runWithSignals([
        "Firebase\(sdk)Integration",
        "\(platform)",
        method,
      ] + extraArguments)
      guard exitCode == 0 else {
        logger.error(
          "Failed to \(actionDescription.lowercased()).",
          metadata: ["sdk": "\(sdk)", "platform": "\(platform)"]
        )
        throw ExitCode(exitCode)
      }
    }
  }

  private func findAndValidateXcodeOnDisk(logger: Logger) throws -> String {
    let xcodes = try findXcodeVersions(logger: logger)
    guard xcodes.count == 1 else {
      let formattedXcodes = xcodes.map { $0.path(percentEncoded: false) }
      logger.error(
        "Multiple Xcode versions found.",
        metadata: ["versions": "\(formattedXcodes)"]
      )
      throw ValidationError(
        "Multiple Xcode installations found. Explicitly pass the 'xcode' option to specify which to use."
      )
    }
    let xcodePath = xcodes[0].path(percentEncoded: false)
    logger.debug("Found Xcode installation", metadata: ["path": "\(xcodePath)"])
    return xcodePath
  }

  private func validateProvidedXcode(logger: Logger) throws -> String {
    if xcode.hasSuffix(".app") {
      guard FileManager.default.fileExists(atPath: xcode) else {
        throw ValidationError("Xcode application not found at path: \(xcode)")
      }
      return URL(filePath: xcode).path(percentEncoded: false)
    } else {
      let xcodes = try findXcodeVersions(logger: logger)
      guard
        let match = xcodes.first(where: {
          $0.path(percentEncoded: false).contains("\(xcode).app")
        })
      else {
        let formattedXcodes = xcodes.map { $0.path(percentEncoded: false) }
        logger.error("Invalid Xcode specified.", metadata: ["versions": "\(formattedXcodes)"])
        throw ValidationError("Failed to find an Xcode installation that matches: \(xcode)")
      }
      let xcodePath = match.path(percentEncoded: false)
      logger.debug("Found matching Xcode", metadata: ["path": "\(xcodePath)"])
      return xcodePath
    }
  }

  private func findXcodeVersions(logger: Logger) throws -> [URL] {
    let applicationDirs = FileManager.default.urls(
      for: .applicationDirectory, in: .allDomainsMask
    ).filter { url in
      let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
      if !exists {
        logger.debug(
          "Application directory doesn't exist, so we're skipping it.",
          metadata: ["directory": "\(url.path(percentEncoded: false))"]
        )
      }
      return exists
    }

    logger.debug(
      "Searching application directories for Xcode installations.",
      metadata: ["directories": "\(applicationDirs)"]
    )

    let allApplications = try applicationDirs.flatMap { url in
      try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }

    let xcodes = allApplications.filter { file in
      let isXcode = file.lastPathComponent.contains(/Xcode.*\.app/)
      if !isXcode {
        logger.debug(
          "Application isn't an Xcode installation, so we're skipping it.",
          metadata: ["application": "\(file.lastPathComponent)"]
        )
      }
      return isXcode
    }
    guard !xcodes.isEmpty else {
      throw ValidationError("Failed to find any Xcode versions installed. Please install Xcode.")
    }

    logger.debug("Found Xcode installations.", metadata: ["installations": "\(xcodes)"])
    return xcodes
  }
}

/// Apple platforms that tests can be run under.
enum Platform: String, Codable, ExpressibleByArgument, CaseIterable {
  case iOS
  case iPad
  case macOS
  case tvOS
  case watchOS
  case visionOS
}
