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

import Dispatch
import Foundation
import Logging

/// Utility for launching and capturing output from child shell processes.
public enum ProcessRunner {
  private static let logger = Logger(label: "zip-builder.process")

  /// Characters that can appear unquoted in a POSIX shell token without triggering word splitting,
  /// variable expansion, globbing, or redirection.
  ///
  /// Built from `CharacterSet.alphanumerics` (`a-z`, `A-Z`, `0-9`, and Unicode letters/digits)
  /// unioned with the specific shell-inert punctuation and symbol characters commonly used in
  /// CLI flags, file paths, key-value build settings, and Xcode destinations (`-_./:=@%+,`).
  private static let shellSafeCharacters = CharacterSet.alphanumerics
    .union(CharacterSet(charactersIn: "-_./:=@%+,"))

  /// The outcome of an executed process including exit code, standard output, and standard error.
  public struct ProcessResult: Sendable {
    /// The termination exit status of the process (0 indicates success).
    public let exitCode: Int32
    /// UTF-8 decoded standard output stream captured from the process.
    public let standardOutput: String
    /// UTF-8 decoded standard error stream captured from the process.
    public let standardError: String

    /// Returns `true` if the process terminated normally with exit code 0.
    public var isSuccess: Bool {
      exitCode == 0
    }
  }

  /// Formats an executable, arguments, environment overrides, and working directory into a
  /// copy-pasteable shell command string.
  ///
  /// - Parameters:
  ///   - executable: Executable binary or tool name.
  ///   - arguments: Command line arguments passed to the executable.
  ///   - workingDirectory: Optional directory to execute the command within.
  ///   - environment: Optional environment variable overrides.
  /// - Returns: A fully quoted, copy-pasteable command line string.
  public static func formatCommandLine(executable: String,
                                       arguments: [String] = [],
                                       workingDirectory: URL? = nil,
                                       environment: [String: String] = [:]) -> String {
    func shellEscape(_ str: String) -> String {
      guard !str.isEmpty else {
        return "''"
      }

      if str.unicodeScalars.allSatisfy(shellSafeCharacters.contains) {
        return str
      }

      let escaped = str.replacingOccurrences(of: "'", with: "'\\''")
      return "'\(escaped)'"
    }

    var components: [String] = []

    for (k, v) in environment.sorted(by: { $0.key < $1.key }) {
      components.append("\(k)=\(shellEscape(v))")
    }

    components.append(shellEscape(executable))
    components.append(contentsOf: arguments.map(shellEscape))

    let command = components.joined(separator: " ")
    if let workingDirectory {
      return "cd \(shellEscape(workingDirectory.path)) && \(command)"
    }

    return command
  }

  /// Executes an external command synchronously via `/usr/bin/env` and captures its streams.
  ///
  /// - Parameters:
  ///   - executable: Executable binary or tool name (e.g. `xcodebuild`, `ditto`, `codesign`).
  ///   - arguments: Command line arguments passed to the executable.
  ///   - workingDirectory: Optional directory to execute the command within.
  ///   - environment: Optional environment variable overrides.
  ///   - logOutput: When `true`, streams output directly to the logger.
  /// - Returns: `ProcessResult` containing termination status and output.
  /// - Throws: An error if the process fails to launch.
  @discardableResult
  public static func run(_ executable: String,
                         arguments: [String] = [],
                         workingDirectory: URL? = nil,
                         environment: [String: String] = [:],
                         logOutput: Bool = false) throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/env")
    process.arguments = [executable] + arguments
    if let workingDirectory {
      process.currentDirectoryURL = workingDirectory
    }

    var env = ProcessInfo.processInfo.environment
    process.environment = env.combineWith(environment)

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    nonisolated(unsafe) var stdoutData = Data()
    nonisolated(unsafe) var stderrData = Data()

    let group = DispatchGroup()
    let stdoutQueue = DispatchQueue(label: "zip-builder.process.stdout")
    let stderrQueue = DispatchQueue(label: "zip-builder.process.stderr")

    group.enter()
    stdoutQueue.async {
      stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
      group.leave()
    }

    group.enter()
    stderrQueue.async {
      stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
      group.leave()
    }

    let commandLine = formatCommandLine(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment
    )

    logger.debug(
      "Executing command: \(commandLine)",
      metadata: [
        "command": "\(commandLine)",
        "executable": "\(executable)",
      ]
    )

    try process.run()
    process.waitUntilExit()
    group.wait()

    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

    logger.debug(
      "Command finished",
      metadata: [
        "executable": "\(executable)",
        "exitCode": "\(process.terminationStatus)",
      ]
    )

    if logOutput {
      if !stdout.isEmpty {
        logger.info("Process stdout", metadata: ["output": "\(stdout)"])
      }
      if !stderr.isEmpty {
        logger.error("Process stderr", metadata: ["error": "\(stderr)"])
      }
    } else if process.terminationStatus != 0 && !stderr.isEmpty {
      logger.debug("Process stderr", metadata: ["error": "\(stderr)"])
    }

    return ProcessResult(
      exitCode: process.terminationStatus,
      standardOutput: stdout,
      standardError: stderr
    )
  }

  /// Executes an external command asynchronously without blocking the calling cooperative thread.
  ///
  /// - Parameters:
  ///   - executable: Executable binary or tool name (e.g. `xcodebuild`, `ditto`, `codesign`).
  ///   - arguments: Command line arguments passed to the executable.
  ///   - workingDirectory: Optional directory to execute the command within.
  ///   - environment: Optional environment variable overrides.
  ///   - logOutput: When `true`, streams output directly to the logger.
  /// - Returns: `ProcessResult` containing termination status and output.
  /// - Throws: An error if the process fails to launch.
  @discardableResult
  public static func runAsync(_ executable: String,
                              arguments: [String] = [],
                              workingDirectory: URL? = nil,
                              environment: [String: String] = [:],
                              logOutput: Bool = false) async throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/env")
    process.arguments = [executable] + arguments
    if let workingDirectory {
      process.currentDirectoryURL = workingDirectory
    }

    var env = ProcessInfo.processInfo.environment
    process.environment = env.combineWith(environment)

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let commandLine = formatCommandLine(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment
    )

    logger.debug(
      "Executing command (async): \(commandLine)",
      metadata: [
        "command": "\(commandLine)",
        "executable": "\(executable)",
      ]
    )

    return try await withCheckedThrowingContinuation { continuation in
      nonisolated(unsafe) var stdoutData = Data()
      nonisolated(unsafe) var stderrData = Data()

      let group = DispatchGroup()
      let stdoutQueue = DispatchQueue(label: "zip-builder.process.stdout.async")
      let stderrQueue = DispatchQueue(label: "zip-builder.process.stderr.async")

      group.enter()
      stdoutQueue.async {
        stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        group.leave()
      }

      group.enter()
      stderrQueue.async {
        stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        group.leave()
      }

      group.enter()
      process.terminationHandler = { _ in
        group.leave()
      }

      do {
        try process.run()
      } catch {
        try? stdoutPipe.fileHandleForWriting.close()
        try? stderrPipe.fileHandleForWriting.close()
        process.terminationHandler = nil
        group.leave()
        continuation.resume(throwing: error)
        return
      }

      group.notify(queue: DispatchQueue.global()) {
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let status = process.terminationStatus

        logger.debug(
          "Command finished (async)",
          metadata: [
            "executable": "\(executable)",
            "exitCode": "\(status)",
          ]
        )

        if logOutput {
          if !stdout.isEmpty {
            logger.info("Process stdout", metadata: ["output": "\(stdout)"])
          }
          if !stderr.isEmpty {
            logger.error("Process stderr", metadata: ["error": "\(stderr)"])
          }
        } else if status != 0 && !stderr.isEmpty {
          logger.debug("Process stderr", metadata: ["error": "\(stderr)"])
        }

        continuation.resume(returning: ProcessResult(
          exitCode: status,
          standardOutput: stdout,
          standardError: stderr
        ))
      }
    }
  }
}

extension Dictionary where Key: Hashable {
  /// Merges `other` into `self` and returns the mutated dictionary.
  mutating func combineWith(_ other: Dictionary) -> Self {
    for (k, v) in other {
      self[k] = v
    }
    return self
  }
}
