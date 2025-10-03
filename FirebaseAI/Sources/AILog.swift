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

import Foundation
import os.log

internal import FirebaseCoreExtension

enum AILog {
  /// Log message codes for the Firebase AI SDK
  ///
  /// These codes should ideally not be re-used in order to facilitate matching error codes in
  /// support requests to lines in the SDK. These codes should range between 0 and 999999 to avoid
  /// being truncated in log messages.
  enum MessageCode: Int {
    // Logging Configuration
    case verboseLoggingDisabled = 100
    case verboseLoggingEnabled = 101

    // API Enablement Errors
    case vertexAIInFirebaseAPIDisabled = 200

    // Generative Model Configuration
    case generativeModelInitialized = 1000
    case unsupportedGeminiModel = 1001
    case invalidSchemaFormat = 1002

    // Imagen Model Configuration
    case unsupportedImagenModel = 1200
    case imagenInvalidJPEGCompressionQuality = 1201

    // Network Errors
    case generativeAIServiceNonHTTPResponse = 2000
    case loadRequestResponseError = 2001
    case loadRequestResponseErrorPayload = 2002
    case loadRequestStreamResponseError = 2003
    case loadRequestStreamResponseErrorPayload = 2004

    // Parsing Errors
    case loadRequestParseResponseFailedJSON = 3000
    case loadRequestParseResponseFailedJSONError = 3001
    case generateContentResponseUnrecognizedFinishReason = 3002
    case generateContentResponseUnrecognizedBlockReason = 3003
    case generateContentResponseUnrecognizedBlockThreshold = 3004
    case generateContentResponseUnrecognizedHarmProbability = 3005
    case generateContentResponseUnrecognizedHarmCategory = 3006
    case generateContentResponseUnrecognizedHarmSeverity = 3007
    case decodedInvalidProtoDateYear = 3008
    case decodedInvalidProtoDateMonth = 3009
    case decodedInvalidProtoDateDay = 3010
    case decodedInvalidCitationPublicationDate = 3011
    case generateContentResponseUnrecognizedContentModality = 3012
    case decodedUnsupportedImagenPredictionType = 3013
    case decodedUnsupportedPartData = 3014
    case codeExecutionResultUnrecognizedOutcome = 3015
    case executableCodeUnrecognizedLanguage = 3016
    case fallbackValueUsed = 3017
    case urlMetadataUnrecognizedURLRetrievalStatus = 3018
    case liveSessionUnsupportedMessage = 3019
    case liveSessionUnsupportedMessagePayload = 3020
    case liveSessionFailedToEncodeClientMessage = 3021
    case liveSessionFailedToEncodeClientMessagePayload = 3022
    case liveSessionFailedToSendClientMessage = 3023
    case liveSessionUnexpectedResponse = 3024
    case liveSessionGoingAwaySoon = 3025
    case liveSessionClosedDuringSetup = 3026
    case decodedMissingProtoDurationSuffix = 3027
    case decodedInvalidProtoDurationString = 3028
    case decodedInvalidProtoDurationSeconds = 3029
    case decodedInvalidProtoDurationNanoseconds = 3030

    // SDK State Errors
    case generateContentResponseNoCandidates = 4000
    case generateContentResponseNoText = 4001
    case appCheckTokenFetchFailed = 4002
    case generateContentResponseEmptyCandidates = 4003
    case invalidWebsocketURL = 4004
    case duplicateLiveSessionSetupComplete = 4005

    // SDK Debugging
    case loadRequestStreamResponseLine = 5000
  }

  /// Subsystem that should be used for all Loggers.
  static let subsystem = "com.google.firebase"

  /// Log identifier for the AI SDK.
  ///
  /// > Note: This corresponds to the `category` in `OSLog`.
  static let service = "[FirebaseAI]"

  /// The raw `OSLog` log object.
  ///
  /// > Important: This is only needed for direct `os_log` usage.
  static let logObject = OSLog(subsystem: subsystem, category: service)

  /// The argument required to enable additional logging.
  static let enableArgumentKey = "-FIRDebugEnabled"

  static func log(level: FirebaseLoggerLevel, code: MessageCode, _ message: String) {
    let messageCode = String(format: "I-VTX%06d", code.rawValue)
    FirebaseLogger.log(
      level: level,
      service: AILog.service,
      code: messageCode,
      message: message
    )
  }

  static func error(code: MessageCode, _ message: String) {
    log(level: .error, code: code, message)
  }

  static func warning(code: MessageCode, _ message: String) {
    log(level: .warning, code: code, message)
  }

  static func notice(code: MessageCode, _ message: String) {
    log(level: .notice, code: code, message)
  }

  static func info(code: MessageCode, _ message: String) {
    log(level: .info, code: code, message)
  }

  static func debug(code: MessageCode, _ message: String) {
    log(level: .debug, code: code, message)
  }

  /// Returns `true` if additional logging has been enabled via a launch argument.
  static func additionalLoggingEnabled() -> Bool {
    return ProcessInfo.processInfo.arguments.contains(enableArgumentKey)
  }

  /// Returns the unwrapped optional value if non-nil or returns the fallback value and logs.
  ///
  /// This convenience method is intended for use in place of `optionalValue ?? fallbackValue` with
  /// the addition of logging on use of the fallback value.
  ///
  /// - Parameters:
  ///   - optionalValue: The value to unwrap.
  ///   - fallbackValue: The fallback (default) value to return when `optionalValue` is `nil`.
  ///   - level: The logging level to use for fallback messages; defaults to
  ///     `FirebaseLoggerLevel.warning`.
  ///   - code: The message code to use for fallback messages; defaults to
  ///     `MessageCode.fallbackValueUsed`.
  ///   - caller: The name of the unwrapped value; defaults to the name of the computed property or
  ///     function name from which the unwrapping occurred.
  static func safeUnwrap<T>(_ optionalValue: T?,
                            fallback fallbackValue: T,
                            level: FirebaseLoggerLevel = .warning,
                            code: MessageCode = .fallbackValueUsed,
                            caller: String = #function) -> T {
    guard let unwrappedValue = optionalValue else {
      AILog.log(level: level, code: code, """
      No value specified for '\(caller)' (\(T.self)); using fallback value '\(fallbackValue)'.
      """)
      return fallbackValue
    }
    return unwrappedValue
  }
}
