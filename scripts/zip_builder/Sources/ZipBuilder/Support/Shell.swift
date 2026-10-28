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

import Foundation

/// A command-line tool that exited with a non-zero status.
struct ShellError: Error, CustomStringConvertible {
  var commandLine: String
  var exitCode: Int32
  var standardError: String

  var description: String {
    "`\(commandLine)` failed with exit code \(exitCode):\n\(standardError)"
  }
}

/// Runs `tool` (looked up on `PATH`) with `arguments` and returns its standard output.
@discardableResult
func shell(_ tool: String, _ arguments: [String],
           in directory: Path? = nil) async throws -> String {
  let result = try await runTool(tool, arguments, in: directory)
  guard result.status == 0 else {
    throw ShellError(commandLine: commandLine(tool, arguments), exitCode: result.status,
                     standardError: result.standardError)
  }
  return result.standardOutput
}

/// `tool` and `arguments` as a shell command line you can copy and run: arguments with spaces or
/// other special characters are single-quoted.
func commandLine(_ tool: String, _ arguments: [String]) -> String {
  ([tool] + arguments).map(shellQuoted).joined(separator: " ")
}

/// `argument`, single-quoted when the shell would otherwise split or expand it.
func shellQuoted(_ argument: String) -> String {
  let plain = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./=:,+@%"))
  let isPlain = !argument.isEmpty && argument.unicodeScalars.allSatisfy(plain.contains)
  if isPlain {
    return argument
  }
  // Inside single quotes nothing is special except `'` itself: close the quote, add an escaped
  // quote, and reopen (`it's` → `'it'\''s'`).
  return "'" + argument.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
}

/// The command line `runTool` logs with `--verbose`, including its working directory and log
/// file: `cd <directory> && <tool> <arguments> > <log file> 2>&1`.
func displayedCommandLine(_ tool: String, _ arguments: [String], in directory: Path?,
                          logFile: Path?) -> String {
  var line = commandLine(tool, arguments)
  if let directory {
    line = "cd \(shellQuoted(directory)) && " + line
  }
  if let logFile {
    line += " > \(shellQuoted(logFile)) 2>&1"
  }
  return line
}

/// A finished tool's exit status and output.
struct ToolResult: Sendable {
  var status: Int32
  var standardOutput: String
  var standardError: String
}

/// Runs `tool` like `shell`, but returns a non-zero status instead of throwing, for checks where
/// failing is a result. With `logFile`, both streams are written to that file instead of being
/// kept, so the returned output is empty.
///
/// With `--verbose`, the command line is logged first, as a shell command you can copy and run.
///
/// It waits for the exit with `terminationHandler`: `waitUntilExit` hung when many tools ran at
/// once from Swift concurrency.
func runTool(_ tool: String, _ arguments: [String], in directory: Path? = nil,
             logFile: Path? = nil) async throws -> ToolResult {
  logger.debug("Running: \(displayedCommandLine(tool, arguments, in: directory, logFile: logFile))")
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = [tool] + arguments
  if let directory {
    process.currentDirectoryURL = URL(fileURLWithPath: directory)
  }
  let outputPipe = Pipe(), errorPipe = Pipe()
  process.standardOutput = outputPipe
  process.standardError = errorPipe
  let log = try logFile.map(LogFile.init)

  async let stdout = readAll(outputPipe, into: log)
  async let stderr = readAll(errorPipe, into: log)
  let status: Int32
  do {
    status = try await withCheckedThrowingContinuation { continuation in
      process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
      do { try process.run() } catch { continuation.resume(throwing: error) }
    }
  } catch {
    // The tool never started: close the write ends so the reads above finish.
    try? outputPipe.fileHandleForWriting.close()
    try? errorPipe.fileHandleForWriting.close()
    _ = await (stdout, stderr)
    throw error
  }
  let (outputData, errorData) = await (stdout, stderr)
  return ToolResult(status: status,
                    standardOutput: String(decoding: outputData, as: UTF8.self),
                    standardError: String(decoding: errorData, as: UTF8.self))
}

/// A log file that both of a tool's output streams write to, from two threads. Writes are
/// serialized, and the file is opened for appending, so chunks never overwrite each other.
private final class LogFile: @unchecked Sendable {
  private let handle: FileHandle
  private let lock = NSLock()

  /// Creates (or empties) the file at `path`.
  init(_ path: Path) throws {
    let descriptor = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_APPEND, 0o644)
    guard descriptor >= 0 else {
      throw ZipBuilderError("Couldn't create the log file \(path).")
    }
    handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
  }

  func write(_ data: Data) {
    lock.withLock { handle.write(data) }
  }
}

/// Reads `pipe` until it closes, on a dispatch thread so the blocking reads stay off the
/// concurrency pool. With `log`, chunks go to the log instead of being kept.
private func readAll(_ pipe: Pipe, into log: LogFile?) async -> Data {
  await withCheckedContinuation { continuation in
    DispatchQueue.global().async {
      var data = Data()
      while true {
        let chunk = pipe.fileHandleForReading.availableData
        if chunk.isEmpty {
          break // the write end closed: the tool exited, or never started
        }
        if let log {
          log.write(chunk)
        } else {
          data.append(chunk)
        }
      }
      continuation.resume(returning: data)
    }
  }
}
