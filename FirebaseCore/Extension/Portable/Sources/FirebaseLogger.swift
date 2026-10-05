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

package import FirebaseCore
private import FirebaseCoreInternal
import Foundation

/// Logger wrapper matching Darwin's `FIRLoggerWrapper` (`FirebaseLogger`).
package enum FirebaseLogger {
  /// A closure that receives formatted log events during testing.
  package typealias LogSink = @Sendable (_ level: FirebaseLoggerLevel,
                                         _ service: String,
                                         _ code: String,
                                         _ message: String) -> Void

  private static let customSink = UnfairLock<LogSink?>(nil)

  private static let isDebugArgumentEnabled =
    ProcessInfo.processInfo.arguments.contains("-FIRDebugEnabled")

  /// Installs or clears a custom log sink for unit testing.
  ///
  /// - Parameter sink: A closure invoked whenever a log message passes level filtering, or `nil`
  ///   to restore default stderr logging.
  package static func setSink(_ sink: LogSink?) {
    customSink.withLock { $0 = sink }
  }

  /// Logs a given message at a given log level.
  ///
  /// - Parameters:
  ///   - level: The log level to use (defined by `FirebaseLoggerLevel` enum values).
  ///   - service: The service name (for example, `"[FirebaseAI]"`).
  ///   - code: The message code starting with `"I-"`.
  ///   - message: The formatted log message string.
  package static func log(level: FirebaseLoggerLevel,
                          service: String,
                          code: String,
                          message: String) {
    let configuredLevel = FirebaseConfiguration.shared.loggerLevel()
    let maxLevel: FirebaseLoggerLevel = isDebugArgumentEnabled ? .debug : configuredLevel
    guard level.rawValue <= maxLevel.rawValue else { return }

    if let sink = customSink.value() {
      sink(level, service, code, message)
      return
    }

    let line = "\(FirebaseVersion()) - \(service)[\(code)] \(message)\n"
    if let data = line.data(using: .utf8) {
      FileHandle.standardError.write(data)
    }
  }
}
