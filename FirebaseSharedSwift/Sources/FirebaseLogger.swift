// Copyright 2024 Google LLC
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

import FirebaseCore
import Foundation
import os

@_implementationOnly import FirebaseCoreExtension

public class FirebaseLogger {
  let category: String
  let categoryIdentifier: String

  /// Initializes a `FirebaseLogger`.
  ///
  /// - Parameters:
  ///   - category: The product or component name to use as an OSLog category to differentiate logs
  ///     within the Firebase subsystem.
  ///   - categoryIdentifier: A three-character identifier for the `category` that is unique within
  ///     Firebase, e.g., "COR" for the "FirebaseCore" category.
  public init(category: String, categoryIdentifier: String) {
    self.category = category
    self.categoryIdentifier = categoryIdentifier
  }

  // MARK: - Logging Methods

  /// Writes a log message with the log level `notice`.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  ///   - message: The message to log; may be a format string.
  ///   - arguments: A comma-separated list of arguments to substitute into `message`, if it is a
  /// format string.
  public func notice(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .notice, messageID: messageID, message, arguments)
  }

  /// Writes a log message with the log level `info`.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  ///   - message: The message to log; may be a format string.
  ///   - arguments: A comma-separated list of arguments to substitute into `message`, if it is a
  /// format string.
  public func info(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .info, messageID: messageID, message, arguments)
  }

  /// Writes a log message with the log level `debug`.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  ///   - message: The message to log; may be a format string.
  ///   - arguments: A comma-separated list of arguments to substitute into `message`, if it is a
  /// format string.
  public func debug(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .debug, messageID: messageID, message, arguments)
  }

  /// Writes a log message with the log level `warning`.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  ///   - message: The message to log; may be a format string.
  ///   - arguments: A comma-separated list of arguments to substitute into `message`, if it is a
  /// format string.
  public func warning(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .warning, messageID: messageID, message, arguments)
  }

  /// Writes a log message with the log level `error`.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  ///   - message: The message to log; may be a format string.
  ///   - arguments: A comma-separated list of arguments to substitute into `message`, if it is a
  /// format string.
  public func error(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .error, messageID: messageID, message, arguments)
  }

  // MARK: - Manual Logging Helpers

  /// Returns true if the specified logging level should be logged.
  ///
  /// - Parameters:
  ///   - level: The logging level to check.
  public func isLoggableLevel(_ level: FirebaseLoggerLevel) -> Bool {
    FIRIsLoggableLevel(level, false)
  }

  /// Returns the prefix that should be prepended to log messages when using OSLog directly.
  ///
  /// - Important: This prefix is added automatically when using the logging methods `notice`,
  ///   `info`, etc., in this class and should not be added manually to avoid duplication.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  public func messagePrefix(messageID: Int) -> String {
    let code = FIRLogMessageCode(categoryIdentifier, messageID)
    return FIRLogPrefix(category, categoryIdentifier, code)
  }

  /// Returns the log object that should be used when using OSLog directly.
  public func logObject() -> OSLog {
    return FIRLogOSLogObject(category)
  }

  // MARK: - Private Helpers

  private func log(level: FirebaseLoggerLevel, messageID: Int, _ message: String,
                   _ arguments: any CVarArg...) {
    withVaList(arguments) { va_list in
      let code = FIRLogMessageCode(self.categoryIdentifier, messageID)
      FIRLogBasic(level, category, code, message, va_list)
    }
  }
}
