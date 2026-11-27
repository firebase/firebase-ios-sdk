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

import FirebaseCore
import Foundation

#if SWIFT_PACKAGE
  import FirebaseAppCheck
#endif // SWIFT_PACKAGE

internal import AppCheckCore
internal import FirebaseCoreExtension

/// App Check log message codes.
enum AppCheckMessageCode: String {
  // AppCheck
  case providerFactoryIsMissing = "I-FAA002001"
  case providerIsMissing = "I-FAA002002"

  // AppCheckDebugProvider
  case debugProviderIncompleteFIROptions = "I-FAA004001"
  case debugTokenExchangeFailed = "I-FAA004002"
  case debugTokenFromConfigStore = "I-FAA004003"
  case configStoreDebugTokenExchangeFailed = "I-FAA004004"
  case debugToken = "I-FAA005001"

  // DebugTokenConfigStore
  case debugTokenConfigStoreUnreadable = "I-FAA004005"

  // DeviceCheckProvider
  case deviceCheckProviderIncompleteFIROptions = "I-FAA006001"

  // RecaptchaProvider
  case recaptchaProviderIncompleteFIROptions = "I-FAA007001"
  case recaptchaProviderMissingSiteKey = "I-FAA007002"
  case recaptchaProviderMissingRecaptchaEnterpriseSDK = "I-FAA007003"

  // DefaultProviderFactory
  case deviceCheckProviderUnavailable = "I-FAA008002"
}

enum AppCheckLogger {
  /// The Firebase logger service of App Check.
  static let service = "[FirebaseAppCheck]"

  static func log(_ level: FirebaseLoggerLevel, _ code: AppCheckMessageCode, _ message: String) {
    FirebaseLogger.log(level: level, service: service, code: code.rawValue, message: message)
  }

  /// Returns the App Check Core log level that is equivalent to a Firebase log level.
  static func appCheckCoreLogLevel(for loggerLevel: FirebaseLoggerLevel = FIRGetLoggerLevel())
    -> AppCheckCoreLogLevel {
    switch loggerLevel {
    case .error:
      return .error
    case .warning, .notice:
      return .warning
    case .info:
      return .info
    case .debug:
      return .debug
    @unknown default:
      return .warning
    }
  }
}
