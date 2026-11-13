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
import Testing
@testable import ZipBuilder

struct ShellTests {
  @Test func returnsStandardOutput() async throws {
    #expect(try await shell("echo", ["hello", "world"]) == "hello world\n")
  }

  @Test func runsInADirectory() async throws {
    #expect(try await shell("pwd", [], in: "/usr") == "/usr\n")
  }

  @Test func runToolWritesBothStreamsToTheLogFile() async throws {
    let log = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/\(UUID().uuidString).log")
    try FileManager.default.createDirectory(at: log.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try Data("an old log\n".utf8).write(to: log)
    // More than a pipe buffer on both streams at once, so the two writers interleave.
    let result = try await runTool(
      "sh",
      ["-c", "yes o | head -c 200000; yes e | head -c 200000 >&2"],
      logFile: log.path
    )
    #expect(result.status == 0)
    #expect(result.standardOutput.isEmpty && result.standardError.isEmpty)
    let text = try String(contentsOf: log, encoding: .utf8)
    #expect(text.count == 400_000) // the old log is gone and no chunk overwrote another
    #expect(text.filter { $0 == "o" }.count == 100_000)
    #expect(text.filter { $0 == "e" }.count == 100_000)
  }

  @Test func failureIncludesCommandExitCodeAndStandardError() async throws {
    let error = await #expect(throws: ShellError.self) {
      try await shell("sh", ["-c", "echo oops >&2; exit 3"])
    }
    #expect(error?.exitCode == 3)
    #expect(error?.standardError == "oops\n")
    #expect(error?.commandLine == "sh -c 'echo oops >&2; exit 3'")
    #expect(error?.description.contains("exit code 3") == true)
  }

  @Test func handlesLargeOutput() async throws {
    // More than a pipe buffer on both streams, to catch deadlocks.
    let output = try await shell("sh", ["-c", "yes | head -c 200000; yes | head -c 200000 >&2"])
    #expect(output.count == 200_000)
  }

  @Test func runToolReturnsAFailingStatusWithBothStreams() async throws {
    let result = try await runTool("sh", ["-c", "echo out; echo err >&2; exit 4"])
    #expect(result.status == 4)
    #expect(result.standardOutput == "out\n" && result.standardError == "err\n")
  }

  @Test func runToolReportsAToolThatDoesntStart() async throws {
    await #expect(throws: (any Error).self) {
      try await runTool("sh", [], in: "/nonexistent/directory")
    }
  }

  @Test func manyConcurrentRunsFinish() async throws {
    // `waitUntilExit` used to hang here when many tools ran at once; `runTool` must not.
    let outputs = try await concurrentMap(Array(0 ..< 64), limit: 16) {
      try await shell("echo", ["\($0)"])
    }
    #expect(outputs == (0 ..< 64).map { "\($0)\n" })
  }

  @Test(arguments: [
    ("plain", "plain"),
    ("-scheme", "-scheme"),
    ("/tmp/out/Firebase.xcodeproj", "/tmp/out/Firebase.xcodeproj"),
    ("COMPILATION_CACHE_ENABLE_CACHING=YES", "COMPILATION_CACHE_ENABLE_CACHING=YES"),
    ("generic/platform=iOS Simulator", "'generic/platform=iOS Simulator'"),
    ("it's", #"'it'\''s'"#),
    ("$HOME", "'$HOME'"),
    ("", "''"),
  ])
  func quotesArgumentsForTheShell(argument: String, quoted: String) {
    #expect(shellQuoted(argument) == quoted)
  }

  @Test func commandLinesCanBeCopiedIntoAShell() {
    #expect(commandLine(
      "xcodebuild",
      ["archive", "-destination", "generic/platform=macOS,variant=Mac Catalyst"]
    )
      == "xcodebuild archive -destination 'generic/platform=macOS,variant=Mac Catalyst'")
  }

  /// The `--verbose` "Running:" line adds the working directory and log file, both quoted.
  @Test func displayedCommandLinesShowTheDirectoryAndLogFile() {
    #expect(displayedCommandLine("ls", ["-la"], in: nil, logFile: nil) == "ls -la")
    #expect(displayedCommandLine("ls", [], in: "/tmp/My Dir", logFile: nil)
      == "cd '/tmp/My Dir' && ls")
    #expect(displayedCommandLine("ls", [], in: nil, logFile: "/tmp/out.log")
      == "ls > /tmp/out.log 2>&1")
    #expect(displayedCommandLine(
      "xcodebuild", ["archive", "-scheme", "A B"], in: "/work", logFile: "/logs/it's.log"
    ) == #"cd /work && xcodebuild archive -scheme 'A B' > '/logs/it'\''s.log' 2>&1"#)
  }
}
