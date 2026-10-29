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
import Logging
import Synchronization
import Testing
@testable import ZipBuilder

struct LoggingTests {
  @Test func linesHaveTheTimeLevelLabelAndLocation() throws {
    let lines = Mutex<[String]>([])
    let logger = Logger(label: "zip-builder") { label in
      var handler = ZipBuilderLogHandler(label: label)
      handler.write = { line in lines.withLock { $0.append(line) } }
      return handler
    }
    logger.warning("Something happened", metadata: ["framework": "FirebaseCore"])
    let line = try #require(lines.withLock { $0.first })
    #expect(line.wholeMatch(of: #/
      \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4}            # local date and time
      \ warning\ zip-builder:\ framework=FirebaseCore
      \ \[ZipBuilderTests/LoggingTests.swift:\d+\]\ Something\ happened\n
    /#) != nil, "\(line)")
  }

  @Test func warningsComeFromTheCallSite() {
    let warnings = Warnings()
    Warnings.$collected.withValue(warnings) { warn("careful") }
    #expect(warnings.all == ["careful"])
  }

  @Test(arguments: [
    ([], Logger.Level.info),
    (["--quiet"], .warning),
    (["-q"], .warning),
    (["--verbose"], .debug),
    (["-v"], .debug),
  ])
  func flagsSetTheLevel(arguments: [String], level: Logger.Level) throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot(["plan"] + arguments)
      as? PlanCommand)
    #expect(command.logging.level == level)
  }

  /// `apply()` sets the shared level. One test for every flag, restoring the level afterward:
  /// separate parallel tests would race on it. Commands run by other tests also call `apply()`,
  /// so each check reads the level right after applying it.
  @Test func applySetsTheMinimumLevel() throws {
    let previous = minimumLogLevel.withLock { $0 }
    defer { minimumLogLevel.withLock { $0 = previous } }
    for (flags, level) in [
      (["--quiet"], Logger.Level.warning),
      (["--verbose"], .debug),
      ([], .info),
    ] {
      let command = try #require(try ZipBuilderCommand.parseAsRoot(["plan"] + flags)
        as? PlanCommand)
      command.logging.apply()
      #expect(minimumLogLevel.withLock { $0 } == level, "\(flags)")
    }
  }

  @Test func quietAndVerboseConflict() {
    #expect(throws: (any Error).self) {
      try ZipBuilderCommand.parseAsRoot(["diff", "a", "b", "--quiet", "--verbose"])
    }
  }
}
