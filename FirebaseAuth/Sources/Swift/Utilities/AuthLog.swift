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

import FirebaseCoreExtension
import Foundation

enum AuthLog {
  static func logInfo(code: String, message: String) {
    FirebaseLogger.log(level: .info, service: "[FirebaseAuth]", code: code, message: message)
  }

  static func logDebug(code: String, message: String) {
    FirebaseLogger.log(level: .debug, service: "[FirebaseAuth]", code: code, message: message)
  }

  static func logNotice(code: String, message: String) {
    FirebaseLogger.log(level: .notice, service: "[FirebaseAuth]", code: code, message: message)
  }

  static func logWarning(code: String, message: String) {
    FirebaseLogger.log(level: .warning, service: "[FirebaseAuth]", code: code, message: message)
  }

  static func logError(code: String, message: String) {
    FirebaseLogger.log(level: .error, service: "[FirebaseAuth]", code: code, message: message)
  }

  private static func log(level: FirebaseLoggerLevel, code: String, message: String) {
    FirebaseLogger.log(level: level, service: "[FirebaseAuth]", code: code, message: message)
  }
}
