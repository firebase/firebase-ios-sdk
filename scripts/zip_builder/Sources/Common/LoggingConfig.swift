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

/// Provides centralized logging configuration and initialization for ZipBuilder.
public enum LoggingConfig {
  private static let lock = NSLock()
  private nonisolated(unsafe) static var isBootstrapped = false

  /// Bootstraps the swift-log logging system with standard output and LOG_LEVEL configuration.
  ///
  /// Safe to call multiple times across subcommands; subsequent calls are no-ops.
  public static func bootstrap() {
    lock.lock()
    defer { lock.unlock() }

    guard !isBootstrapped else { return }
    isBootstrapped = true

    LoggingSystem.bootstrap { label in
      var handler = StreamLogHandler.standardOutput(label: label)
      if let level = ProcessInfo.processInfo.environment["LOG_LEVEL"] {
        if let parsedLevel = Logger.Level(rawValue: level.lowercased()) ?? Logger
          .Level(rawValue: level) {
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
  }
}
