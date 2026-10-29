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
import Logging

/// How much every command logs to standard error.
struct LoggingOptions: ParsableArguments {
  @Flag(name: .shortAndLong, help: "Only log warnings and errors.")
  var quiet = false

  @Flag(name: .shortAndLong, help: "Also log debug details, including every command the tool runs.")
  var verbose = false

  func validate() throws {
    if quiet, verbose {
      throw ValidationError("--quiet and --verbose can't be used together.")
    }
  }

  /// The level these flags ask for.
  var level: Logger.Level {
    if quiet {
      return .warning
    }
    if verbose {
      return .debug
    }
    return .info
  }

  /// Sets the logger's level; every command calls this first.
  func apply() {
    minimumLogLevel.withLock { $0 = level }
  }
}
