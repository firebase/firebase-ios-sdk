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

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
struct Logging {
  /// Subsystem that should be used for all Loggers.
  static let subsystem = "com.google.generative-ai"

  /// Default category used for most loggers, unless specialized.
  static let defaultCategory = ""

  /// The argument required to enable additional logging.
  static let enableArgumentKey = "-GoogleGenerativeAIDebugLogEnabled"

  // No initializer available.
  @available(*, unavailable)
  private init() {}

  /// The default logger that is visible for all users. Note: we shouldn't be using anything lower
  /// than `.notice`.
  static var `default` = Logger(subsystem: subsystem, category: defaultCategory)

  /// A non default
  static var network: Logger = {
    if ProcessInfo.processInfo.arguments.contains(enableArgumentKey) {
      return Logger(subsystem: subsystem, category: "NetworkResponse")
    } else {
      // Return a valid logger that's using `OSLog.disabled` as the logger, hiding everything.
      return Logger(.disabled)
    }
  }()

  ///
  static var verbose: Logger = {
    if ProcessInfo.processInfo.arguments.contains(enableArgumentKey) {
      return Logger(subsystem: subsystem, category: defaultCategory)
    } else {
      // Return a valid logger that's using `OSLog.disabled` as the logger, hiding everything.
      return Logger(.disabled)
    }
  }()
}
