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
import os.log

@_implementationOnly import FirebaseCoreExtension

/// Enum of log messages.
enum LoggerMessageCode: Int {
  case unknown = 0
  case verboseLoggingEnabled
  case verboseLoggingDisabled
  case firebaseMLAPIDisabled
  case generativeModelInitialized
  case generativeAIServiceNonHTTPResponse
  case loadRequestResponseError
  case loadRequestResponseErrorPayload
  case loadRequestStreamResponseError
  case loadRequestStreamResponseErrorPayload
  case loadRequestStreamResponseLine
  case loadRequestParseResponseFailedJSON
  case loadRequestParseResponseFailedJSONError
  case generateContentResponseNoCandidates
  case generateContentResponseNoText
  case generateContentResponseUnrecognizedFinishReason
  case generateContentResponseUnrecognizedBlockReason
  case generateContentResponseUnrecognizedBlockThreshold
  case generateContentResponseUnrecognizedHarmProbability
  case generateContentResponseUnrecognizedHarmCategory
  case appCheckTokenFetchFailed
}

enum Logging {
  /// Log identifier.
  static let service = "[FirebaseVertexAI]"

  /// Subsystem that should be used for all Loggers.
  static let subsystem = "com.google.firebase"

  static let logObject = OSLog(subsystem: subsystem, category: service)

  /// The argument required to enable additional logging.
  static let enableArgumentKey = "-FIRDebugEnabled"

  static func logEvent(level: FirebaseLoggerLevel, message: String,
                       messageCode: LoggerMessageCode) {
    let code = String(format: "I-VTX%06d", messageCode.rawValue)
    FirebaseLogger.log(level: level, service: Logging.service, code: code, message: message)
  }

  /// Returns `true` if additional logging has been enabled via a launch argument.
  static func additionalLoggingEnabled() -> Bool {
    return ProcessInfo.processInfo.arguments.contains(enableArgumentKey)
  }
}
