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
  /// Command for decrypting the secret files needed for a test run.
  struct Decrypt: ParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
      abstract: "Decrypt the secret files for a test run.",
      usage: """
        tests decrypt [--json] [--overwrite] [<json-file>]
        tests decrypt [--password <password>] [--overwrite] [<secret-files> ...]

        tests decrypt --json secret_files.json
        tests decrypt --json --overwrite secret_files.json
        tests decrypt --password "super_secret" \\
          scripts/gha-encrypted/FirebaseAI/TestApp-GoogleService-Info.plist.gpg:FirebaseAI/Tests/TestApp/Resources/GoogleService-Info.plist \\
          scripts/gha-encrypted/FirebaseAI/TestApp-GoogleService-Info-Spark.plist.gpg:FirebaseAI/Tests/TestApp/Resources/GoogleService-Info-Spark.plist
      """,
      discussion: """
        The happy path usage is saving the secret passphrase in the environment variable \
      'secrets_passphrase', and passing a json file to the command. Although, you can also \
      pass everything inline via options.

        When using a json file, it's expected that the json file is an array of json elements \
      in the format of:
        { encrypted: <path-to-encrypted-file>, destination: <where-to-output-decrypted-file> }
      """,
    )

    @Argument(
      help: """
      An array of secret files to decrypt. \
      The files should be in the format "encrypted:destination", where "encrypted" is a path to \
      the encrypted file and "destination" is a path to where the decrypted file should be saved.
      """
    )
    var secretFiles: [String] = []

    @Option(
      help: """
      The secret to use when decrypting the files. \
      Defaults to the environment variable 'secrets_passphrase'.
      """
    )
    var password: String = ""

    @Flag(help: "Overwrite existing decrypted secret files.")
    var overwrite: Bool = false

    @Flag(
      help: """
      Use a json file of secret file mappings instead. \
      When this flag is enabled, <secret-files> should be a single json file.
      """
    )
    var json: Bool = false

    /// The parsed version of ``secretFiles``.
    ///
    /// Only populated after `validate()` runs.
    var files: [SecretFile] = []

    static let log = Logger(label: "Tests::Decrypt")
    private var log: Logger { Decrypt.log }

    mutating func validate() throws {
      try validatePassword()

      if json {
        try validateJSON()
      } else {
        try validateFileString()
      }

      if !overwrite {
        log.info("Overwrite is disabled, so we're skipping generation for existing files.")
        files = files.filter { file in
          let exists = FileManager.default.fileExists(atPath: file.destination)
          if !exists {
            log.debug(
              "Skipping generation for existing file",
              metadata: ["destination": "\(file.destination)"]
            )
          }
          return exists
        }
      }

      for file in files {
        guard FileManager.default.fileExists(atPath: file.encrypted) else {
          throw ValidationError("Encrypted secret file does not exist: \(file.encrypted)")
        }
      }
    }

    private mutating func validatePassword() throws {
      if password.isEmpty {
        // when a password isn't provided, try to load one from the environment variable
        guard
          let secrets_passphrase = ProcessInfo.processInfo.environment["secrets_passphrase"]
        else {
          throw ValidationError(
            "Either provide a passphrase via the password option or set the environvment variable 'secrets_passphrase' to the passphrase."
          )
        }
        password = secrets_passphrase
      }
    }

    private mutating func validateJSON() throws {
      guard let jsonPath = secretFiles.first else {
        throw ValidationError("Missing path to json file for secret files")
      }

      let fileURL = URL(
        filePath: jsonPath, directoryHint: .notDirectory,
        relativeTo: URL.currentDirectory()
      )

      files = try SecretFile.parseArrayFrom(file: fileURL)
      guard !files.isEmpty else {
        throw ValidationError("Missing secret files in json file: \(jsonPath)")
      }
    }

    private mutating func validateFileString() throws {
      guard !secretFiles.isEmpty else {
        throw ValidationError("Missing paths to secret files")
      }
      for string in secretFiles {
        try files.append(SecretFile(string: string))
      }
    }

    mutating func run() throws {
      log.info("Decrypting files...")

      for file in files {
        let gpg = Process("gpg", inheritEnvironment: true)
        let result = try gpg.runWithSignals([
          "--quiet",
          "--batch",
          "--yes",
          "--decrypt",
          "--passphrase=\(password)",
          "--output",
          file.destination,
          file.encrypted,
        ])

        guard result == 0 else {
          log.error("Failed to decrypt file", metadata: ["file": "\(file.encrypted)"])
          throw ExitCode(result)
        }

        log.debug(
          "File encrypted",
          metadata: ["file": "\(file.encrypted)", "destination": "\(file.destination)"]
        )
      }

      log.info("Files decrypted")
    }
  }
}
