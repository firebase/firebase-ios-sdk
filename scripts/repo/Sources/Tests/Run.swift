/*
 * Copyright 2025 Google LLC
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

extension Tests {
  /// Command for running the integration tests of a given SDK.
  struct Run: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
      abstract: "Run the integration tests for a given SDK.",
      usage: """
        tests run [--overwrite] [--secrets <file_path>] [--xcode <version_or_path>] [--platforms <platforms> ...] [<sdk>]

        tests run --xcode Xcode_16.4.0 --platforms iOS --platforms macOS AI
        tests run --xcode "/Applications/Xcode_15.0.0.app" --platforms tvOS Storage
        tests run --overwrite --secrets ./scripts/secrets/AI.json AI
      """,
      discussion: """
          If multiple Xcode versions are installed, you must specify an Xcode version manually via the
          'xcode' option. If you run the script without doing so, the script will log an error message
          that contains all the Xcode versions installed, telling you to manually specify the 'xcode' option.

          Note that Xcode versions can be specified as either the application name, or a full path. For
          example, the following are both valid:
          "Xcode_16.4.0" and "/Applications/Xcode_16.4.0.app".

          If your tests have encrypted secret files, you can pass a json file to the script via the
          'secrets' option. The script will automatically decrypt them before running the tests, and
          delete them after running the tests. You'll also need to provide the password that the secret
          files were encrypted with via the 'secrets_passphrase' environment variable. The json file
          should be an array of json elements in the format of:
          { encrypted: <path-to-encrypted-file>, destination: <where-to-output-decrypted-file> }

          If you pass a secret file, but decrypted files already exist at the destination, the script
          will NOT overwrite them. The script will also not delete these files either. If you want
          the script to overwrite and delete secret files, regardless if they existed before the script
          ran, you can pass the 'overwrite' flag.
      """,
    )

    @Option(
      help:
      """
      Xcode version to run tests against. \
      Can be either the application name, or a full path (eg; "Xcode_16.4.0" or "/Applications/Xcode_16.4.0.app").
      By default, the script will look for your local Xcode installation.
      """
    )
    var xcode: String = ""

    @Option(help: "Platforms to run rests on.")
    var platforms: [Platform] = [.iOS]

    @Option(help: "Path to a json file containing an array of secret files to use, if any.")
    var secrets: String? = nil

    @Flag(help: "Overwrite existing decrypted secret files.")
    var overwrite: Bool = false

    @Argument(
      help: """
      The SDK to run integration tests for.
      There should be a build target for the SDK that follows the format "Firebase{SDK}Integration"
      """
    )
    var sdk: String

    static let log: Logger = .init(label: "Tests::Run")
    private var log: Logger { Self.log }

    /// A path to the Xcode to use.
    ///
    /// Only populated after `validate()` runs.
    private var xcodePath: String = ""

    mutating func validate() throws {
      if xcode.isEmpty {
        try findAndValidateXcodeOnDisk()
      } else {
        try validateProvidedXcode()
      }
    }

    /// When the `xcode` option isn't provided, try to find an installation on disk.
    private mutating func findAndValidateXcodeOnDisk() throws {
      let xcodes = try findXcodeVersions()
      guard xcodes.count == 1 else {
        let formattedXcodes = xcodes.map { $0.path(percentEncoded: false) }
        log.error(
          "Multiple Xcode versions found.",
          metadata: ["versions": "\(formattedXcodes)"]
        )

        throw ValidationError(
          "Multiple Xcode installations found. Explicitly pass the 'xcode' option to specify which to use."
        )
      }
      xcodePath = xcodes[0].path()
      log.debug("Found Xcode installation", metadata: ["path": "\(xcodePath)"])
    }

    /// When the `xcode` option is provided, ensure it exists.
    ///
    /// The `xcode` argument can be either a full path to the application, or just the application
    /// name.
    private mutating func validateProvidedXcode() throws {
      if xcode.hasSuffix(".app") {
        // it's a full path to the Xcode, just ensure it exists
        guard FileManager.default.fileExists(atPath: xcode) else {
          throw ValidationError("Xcode application not found at path: \(xcode)")
        }
        xcodePath = URL(filePath: xcode).path()
      } else {
        // it's the application name, find an Xcode installation that matches
        let xcodes = try findXcodeVersions()
        guard
          let match = xcodes.first(where: {
            $0.path(percentEncoded: false).contains("\(xcode).app")
          })
        else {
          let formattedXcodes = xcodes.map { $0.path(percentEncoded: false) }
          log.error("Invalid Xcode specified.",
                    metadata: ["versions": "\(formattedXcodes)"])
          throw ValidationError(
            "Failed to find an Xcode installation that matches: \(xcode)"
          )
        }
        xcodePath = match.path()
        log.debug("Found matching Xcode", metadata: ["path": "\(xcodePath)"])
      }
    }

    private func findXcodeVersions() throws -> [URL] {
      let applicationDirs = FileManager.default.urls(
        for: .applicationDirectory, in: .allDomainsMask
      ).filter { url in
        // file manager lists application dirs that CAN exist, so we should check if they actually
        // do exist before trying to get their contents
        let exists = FileManager.default.fileExists(atPath: url.path())
        if !exists {
          log.debug(
            "Application directory doesn't exists, so we're skipping it.",
            metadata: ["directory": "\(url.path())"]
          )
        }
        return exists
      }

      log.debug(
        "Searching application directories for Xcode installations.",
        metadata: ["directories": "\(applicationDirs)"]
      )

      let allApplications = try applicationDirs.flatMap { URL in
        try FileManager.default.contentsOfDirectory(
          at: URL, includingPropertiesForKeys: nil
        )
      }

      let xcodes = allApplications.filter { file in
        let isXcode = file.lastPathComponent.contains(/Xcode.*\.app/)
        if !isXcode {
          log.debug(
            "Application isn't an Xcode installation, so we're skipping it.",
            metadata: ["application": "\(file.lastPathComponent)"]
          )
        }
        return isXcode
      }
      guard !xcodes.isEmpty else {
        throw ValidationError(
          "Failed to find any Xcode versions installed. Please install Xcode."
        )
      }

      log.debug("Found Xcode installations.", metadata: ["installations": "\(xcodes)"])
      return xcodes
    }

    mutating func run() throws {
      var secretFiles: [SecretFile] = []

      defer {
        // ensure secret files are deleted, regardless of test result
        for file in secretFiles {
          do {
            log.debug("Deleting secret file", metadata: ["file": "\(file.destination)"])
            try FileManager.default.removeItem(atPath: file.destination)
          } catch {
            log.error(
              "Failed to delete secret file.",
              metadata: [
                "file": "\(file.destination)",
                "error": "\(error.localizedDescription)",
              ]
            )
          }
        }
      }

      // decrypt secrets if we need to
      if let secrets {
        var args = ["--json"]
        if overwrite {
          args.append("--overwrite")
        }
        args.append(secrets)
        var decrypt = try Decrypt.parse(args)
        try decrypt.validate()

        // save the secret files to delete later
        secretFiles = decrypt.files

        try decrypt.run()
      }

      let buildScript = URL(filePath: "scripts/build.sh", relativeTo: URL.currentDirectory())
      for platform in platforms {
        log.info(
          "Running integration tests",
          metadata: ["sdk": "\(sdk)", "platform": "\(platform)"]
        )

        // instead of using xcode-select (which requires sudo), we can use the env variable
        // `DEVELOPER_DIR` to point to our target xcode
        let build = Process(
          buildScript.path(percentEncoded: false),
          env: ["DEVELOPER_DIR": "\(xcodePath)/Contents/Developer"],
          inheritEnvironment: true
        )

        let exitCode = try build.runWithSignals([
          "Firebase\(sdk)Integration", "\(platform)",
        ])
        guard exitCode == 0 else {
          log.error(
            "Failed to run integration tests.",
            metadata: ["sdk": "\(sdk)", "platform": "\(platform)"]
          )
          throw ExitCode(exitCode)
        }
      }
    }
  }
}

/// Apple platforms that tests can be ran under.
enum Platform: String, Codable, ExpressibleByArgument, CaseIterable {
  case iOS
  case iPad
  case macOS
  case tvOS
  case watchOS
  case visionOS
}
