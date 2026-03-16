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

struct Tests: ParsableCommand {
  nonisolated(unsafe) static var configuration = CommandConfiguration(
    abstract: "Commands for running and interacting with integration tests.",
    discussion: """
      A note on logging: by default, only log levels "info" and above are logged. For further \
      debugging, you can set the "LOG_LEVEL" environment variable to a different minimum level \
      (eg; "debug").
    """,
    subcommands: [Decrypt.self, Run.self],
    defaultSubcommand: Run.self
  )
}

LoggingSystem.bootstrap { label in
  var handler = StreamLogHandler.standardOutput(label: label)
  if let level = ProcessInfo.processInfo.environment["LOG_LEVEL"] {
    if let parsedLevel = Logger.Level(rawValue: String(level)) {
      handler.logLevel = parsedLevel
      return handler
    } else {
      print(
        """
        [WARNING]: Unrecognized log level "\(level)"; defaulting to "info".
        Valid values: \(Logger.Level.allCases.map(\.rawValue))
        """
      )
    }
  }

  handler.logLevel = .info
  return handler
}

Tests.main()
