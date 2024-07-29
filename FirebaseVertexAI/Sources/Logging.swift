// Copyright 2023 Google LLC
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
import OSLog

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct Logging {
  /// Subsystem that should be used for all Loggers.
  static let subsystem = "com.google.firebase.vertex-ai"

  /// Default category used for most loggers, unless specialized.
  static let defaultCategory = ""

  /// The argument required to enable additional logging.
  static let enableArgumentKey = "-FIRDebugEnabled"

  /// The argument required to enable additional logging in the Google AI SDK; used for migration.
  ///
  /// To facilitate migration between the SDKs, this launch argument is also accepted to enable
  /// additional logging at this time, though it is expected to be removed in the future.
  static let migrationEnableArgumentKey = "-GoogleGenerativeAIDebugLogEnabled"

  // No initializer available.
  @available(*, unavailable)
  private init() {}

  /// The default logger that is visible for all users. Note: we shouldn't be using anything lower
  /// than `.notice`.
  static var `default` = Logger(subsystem: subsystem, category: defaultCategory)

  /// A non default
  static var network: Logger = {
    if additionalLoggingEnabled() {
      return Logger(subsystem: subsystem, category: "NetworkResponse")
    } else {
      // Return a valid logger that's using `OSLog.disabled` as the logger, hiding everything.
      return Logger(.disabled)
    }
  }()

  ///
  static var verbose: Logger = {
    if additionalLoggingEnabled() {
      return Logger(subsystem: subsystem, category: defaultCategory)
    } else {
      // Return a valid logger that's using `OSLog.disabled` as the logger, hiding everything.
      return Logger(.disabled)
    }
  }()

  /// Returns `true` if additional logging has been enabled via a launch argument.
  static func additionalLoggingEnabled() -> Bool {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains(enableArgumentKey) || arguments.contains(migrationEnableArgumentKey) {
      return true
    }
    return false
  }
}
