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

import Common
import Foundation
import Logging
import Testing
@testable import ZipBuilderCLI

struct LoggingTests {
  @Test
  func loggingConfigBootstrapIdempotency() {
    LoggingConfig.bootstrap()
    LoggingConfig.bootstrap()
  }

  @Test
  func zipBuilderValidationBootstrapsLogging() throws {
    var zipBuilder = ZipBuilder()
    try zipBuilder.validate()
  }

  @Test
  func logLevelParsing() {
    let levels = ["trace", "debug", "info", "notice", "warning", "error", "critical"]
    for level in levels {
      let parsed = Logger.Level(rawValue: level.lowercased()) ?? Logger.Level(rawValue: level)
      #expect(parsed != nil)
      #expect(parsed?.rawValue == level)
    }

    let upperLevel = "DEBUG"
    let upperParsed = Logger.Level(rawValue: upperLevel.lowercased()) ?? Logger
      .Level(rawValue: upperLevel)
    #expect(upperParsed == .debug)

    let invalidLevel = "invalid_level_value"
    let invalidParsed = Logger.Level(rawValue: invalidLevel.lowercased()) ?? Logger
      .Level(rawValue: invalidLevel)
    #expect(invalidParsed == nil)
  }

  @Test
  func processRunnerFormatCommandLineSimple() {
    let cmd = ProcessRunner.formatCommandLine(executable: "xcodebuild", arguments: ["-version"])
    #expect(cmd == "xcodebuild -version")
  }

  @Test
  func processRunnerFormatCommandLineEscapesSpacesAndQuotes() {
    let cmd = ProcessRunner.formatCommandLine(
      executable: "xcodebuild",
      arguments: [
        "archive",
        "-project",
        "/path with spaces/project.xcodeproj",
        "ARCHS=arm64 x86_64",
        "it's a quote",
        "",
      ]
    )
    #expect(cmd ==
      "xcodebuild archive -project '/path with spaces/project.xcodeproj' 'ARCHS=arm64 x86_64' 'it'\\''s a quote' ''")
  }

  @Test
  func processRunnerFormatCommandLineWithEnvironmentAndWorkingDirectory() {
    let cmd = ProcessRunner.formatCommandLine(
      executable: "xcodebuild",
      arguments: ["-version"],
      workingDirectory: URL(filePath: "/tmp/working dir"),
      environment: ["LOG_LEVEL": "debug", "MY_VAR": "hello world"]
    )
    #expect(cmd ==
      "cd '/tmp/working dir' && LOG_LEVEL=debug MY_VAR='hello world' xcodebuild -version")
  }

  @Test
  func processRunnerRunAsyncCapturesStdoutStderrAndExitCode() async throws {
    let successOutput = try await ProcessRunner.runAsync(
      "sh",
      arguments: ["-c", "printf 'hello out'; printf 'hello err' >&2"]
    )
    #expect(successOutput.isSuccess)
    #expect(successOutput.exitCode == 0)
    #expect(successOutput.standardOutput == "hello out")
    #expect(successOutput.standardError == "hello err")

    let failureOutput = try await ProcessRunner.runAsync(
      "sh",
      arguments: ["-c", "printf 'fail err' >&2; exit 42"]
    )
    #expect(!failureOutput.isSuccess)
    #expect(failureOutput.exitCode == 42)
    #expect(failureOutput.standardError == "fail err")
  }

  @Test
  func processRunnerRunAsyncExecutesConcurrently() async throws {
    let taskCount = 8
    let results = try await withThrowingTaskGroup(
      of: (Int, ProcessRunner.ProcessResult).self
    ) { group in
      for index in 0 ..< taskCount {
        group.addTask {
          let output = try await ProcessRunner.runAsync(
            "sh",
            arguments: ["-c", "printf 'task-\(index)'"]
          )
          return (index, output)
        }
      }

      var collected: [(Int, ProcessRunner.ProcessResult)] = []
      for try await result in group {
        collected.append(result)
      }
      return collected.sorted { $0.0 < $1.0 }
    }

    #expect(results.count == taskCount)
    for (index, output) in results {
      #expect(output.isSuccess)
      #expect(output.standardOutput == "task-\(index)")
    }
  }
}
