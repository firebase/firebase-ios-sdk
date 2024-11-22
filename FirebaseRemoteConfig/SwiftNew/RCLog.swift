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

import FirebaseCoreExtension
import Foundation

enum RCLog {
  static func info(_ code: String, _ message: String) {
    log(level: .info, code: code, message: message)
  }

  static func debug(_ code: String, _ message: String) {
    log(level: .debug, code: code, message: message)
  }

  static func notice(_ code: String, _ message: String) {
    log(level: .notice, code: code, message: message)
  }

  static func warning(_ code: String, _ message: String) {
    log(level: .warning, code: code, message: message)
  }

  static func error(_ code: String, _ message: String) {
    log(level: .error, code: code, message: message)
  }

  private static func log(level: FirebaseLoggerLevel, code: String, message: String) {
    FirebaseLogger.log(
      level: level,
      service: "[FirebaseRemoteConfig]",
      code: code,
      message: message
    )
  }
}
