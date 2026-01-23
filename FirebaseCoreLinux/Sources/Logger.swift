// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// The log levels used by internal logging.
public enum FirebaseLoggerLevel: Int {
  /// Error level.
  case error = 3
  /// Warning level.
  case warning = 4
  /// Notice level.
  case notice = 5
  /// Info level.
  case info = 6
  /// Debug level.
  case debug = 7
  /// Minimum log level.
  case min = 3
  /// Maximum log level.
  case max = 7
}

/// A wrapper for Firebase logging.
public class FirebaseLogger {
  /// Logs a given message at a given log level.
  ///
  /// - Parameters:
  ///   - level: The log level to use.
  ///   - service: The service name.
  ///   - code: The message code.
  ///   - message: The message string.
  public static func log(level: FirebaseLoggerLevel,
                         service: String,
                         code: String,
                         message: String) {
    // TODO: Integrate with GULLogger if available or needed.
    // For Linux, simple print to stderr/stdout is often sufficient or using standard Logger (SwiftLog).

    let levelStr: String
    switch level {
    case .error: levelStr = "ERROR"
    case .warning: levelStr = "WARNING"
    case .notice: levelStr = "NOTICE"
    case .info: levelStr = "INFO"
    case .debug: levelStr = "DEBUG"
    default: levelStr = "UNKNOWN"
    }

    // Format: [Service] Code - Message
    let output = "[\(levelStr)] \(service) - \(code): \(message)"
    print(output)
  }
}
