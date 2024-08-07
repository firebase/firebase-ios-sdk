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
  ///     format string.
  public func notice(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .notice, messageID: messageID, message, arguments)
  }

  /// Writes a log message with the log level `info`.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  ///   - message: The message to log; may be a format string.
  ///   - arguments: A comma-separated list of arguments to substitute into `message`, if it is a
  ///     format string.
  public func info(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .info, messageID: messageID, message, arguments)
  }

  /// Writes a log message with the log level `debug`.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  ///   - message: The message to log; may be a format string.
  ///   - arguments: A comma-separated list of arguments to substitute into `message`, if it is a
  ///   format string.
  public func debug(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .debug, messageID: messageID, message, arguments)
  }

  /// Writes a log message with the log level `warning`.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  ///   - message: The message to log; may be a format string.
  ///   - arguments: A comma-separated list of arguments to substitute into `message`, if it is a
  ///     format string.
  public func warning(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .warning, messageID: messageID, message, arguments)
  }

  /// Writes a log message with the log level `error`.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  ///   - message: The message to log; may be a format string.
  ///   - arguments: A comma-separated list of arguments to substitute into `message`, if it is a
  ///     format string.
  public func error(messageID: Int, _ message: String, _ arguments: any CVarArg...) {
    log(level: .error, messageID: messageID, message, arguments)
  }

  // MARK: - Manual Logging Helpers

  /// Returns true if the specified logging level should be logged.
  ///
  /// - Parameters:
  ///   - level: The logging level to check.
  public static func isLoggableLevel(_ level: FirebaseLoggerLevel) -> Bool {
    FIRIsLoggableLevel(level, false)
  }

  /// Returns the `OSLogType` equivalent of the specified `FirebaseLoggerLevel`.
  ///
  /// - Parameters:
  ///   - level: The desired Firebase logging level.
  public static func osLogType(_ level: FirebaseLoggerLevel) -> OSLogType {
    return FIRLoggerLevelToOSLogType(level)
  }

  /// Returns the prefix that should be prepended to log messages when using OSLog directly.
  ///
  /// - Important: This prefix is added automatically when using the logging methods `notice`,
  ///   `info`, etc., in this class and should not be added manually to avoid duplication.
  ///
  /// - Parameters:
  ///   - messageID: A six digit integer message identifier that is unique within the category.
  public func messagePrefix(messageID: Int) -> String {
    return FIRLogPrefix(category, categoryIdentifier, messageID)
  }

  /// Returns the log object that may be used when using OSLog directly.
  ///
  /// ## Example Usage
  /// ```swift
  /// // Create a FirebaseLogger for the product.
  /// let logger = FirebaseLogger(category: "FirebaseProduct", categoryIdentifier: "FBP")
  ///
  /// // Check if messages with the chosen log level (severity) should be logged.
  /// if FirebaseLogger.isLoggableLevel(FirebaseLoggerLevel.debug) {
  ///   os_log(
  ///     // Get the equivalent OSLogType for the chosen log level.
  ///     FirebaseLogger.osLogType(FirebaseLoggerLevel.debug),
  ///     // Write to the OSLog log object for your FirebaseLogger.
  ///     log: logger.logObject(),
  ///     // Add the standard Firebase log message prefix with `%{public}@` since the contents of
  ///     // dynamic strings are redacted by default.
  ///     "%{public}@ Logged in - User name: %@, ID: %{private}ld, admin: %{BOOL}d",
  ///     // The standard Firebase log message prefix does not contain sensitive user data but
  ///     // dynamic string values are redacted by default; use the `%{public}@` format specifier to
  ///     // prevent redacting.
  ///     logger.messagePrefix(messageID: 1),
  ///     // The user name is sensitive user data but is redacted by default; the `%@` format
  ///     // specifier is sufficient.
  ///     getUserName(),
  ///     // The user ID is sensitive user data but integer values are not redacted by default;
  ///     // redact using the `%{private}ld` format specifier.
  ///     getUserID(),
  ///     // The user's administrator status is not sensitive user data and is not redacted by
  ///     // default; the `%{BOOL}d` format specifier is sufficient.
  ///     getUserAdmin()
  ///   )
  /// }
  /// ```
  ///
  /// - Important: When writing log messages that **do not** contain sensitive data, it is
  ///   preferable to use the convenience logging methods ``notice(messageID:_:_:)``,
  ///   ``info(messageID:_:_:)``, ``debug(messageID:_:_:)``, ``warning(messageID:_:_:)`` or
  ///   ``error(messageID:_:_:)``; these methods default to `OSLogPrivacy.public`.
  ///
  /// - Tip: The `Logger` struct returned by ``osLogger()`` provides a nicer API for SDKs
  ///   targeting iOS 14+ and equivalent.
  public func logObject() -> OSLog {
    return FIRLogOSLogObject(category)
  }

  /// Returns a Swift Logger struct that may be used when using OSLog directly.
  @available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
  public func osLogger() -> Logger {
    return Logger(logObject())
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
