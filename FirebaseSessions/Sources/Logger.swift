//
// Copyright 2022 Google LLC
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

internal import FirebaseCoreExtension

///
/// Logger is responsible for printing console logs
///
enum Logger {
  private static let logServiceTag = "[FirebaseSessions]"
  private static let logCode = "I-SES000000"

  static func logInfo(_ message: String) {
    FirebaseLogger.log(
      level: .info,
      service: logServiceTag,
      code: logCode,
      message: message
    )
  }

  static func logDebug(_ message: String) {
    FirebaseLogger.log(
      level: .debug,
      service: logServiceTag,
      code: logCode,
      message: message
    )
  }

  static func logWarning(_ message: String) {
    FirebaseLogger.log(
      level: .warning,
      service: logServiceTag,
      code: logCode,
      message: message
    )
  }

  static func logError(_ message: String) {
    FirebaseLogger.log(
      level: .error,
      service: logServiceTag,
      code: logCode,
      message: message
    )
  }
}
