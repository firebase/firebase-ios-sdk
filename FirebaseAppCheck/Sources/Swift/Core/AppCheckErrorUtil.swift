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

import Foundation

#if SWIFT_PACKAGE
  import FirebaseAppCheck
#endif // SWIFT_PACKAGE

internal import AppCheckCore

enum AppCheckErrorUtil {
  /// Converts an error to an error in the public `AppCheckErrorDomain`.
  ///
  /// App Check Core errors are converted to the public error with the same code. Errors that are
  /// already in the public domain are returned as is. Other errors are wrapped in an
  /// `AppCheckErrorCode.unknown` error.
  static func publicDomainError(_ error: Error) -> NSError {
    let error = error as NSError
    if error.domain == AppCheckCoreErrorDomain {
      return publicDomainError(appCheckCoreError: error)
    } else if error.domain == AppCheckErrorDomain {
      return error
    }
    return unknownError(error)
  }

  /// Converts an App Check Core error (`"com.google.app_check_core"`) to a public error
  /// (`AppCheckErrorDomain`).
  private static func publicDomainError(appCheckCoreError: NSError) -> NSError {
    let code: AppCheckErrorCode.Code
    switch AppCheckCoreErrorCode(rawValue: appCheckCoreError.code) {
    case .unknown:
      code = .unknown
    case .serverUnreachable:
      code = .serverUnreachable
    case .invalidConfiguration:
      code = .invalidConfiguration
    case .keychain:
      code = .keychain
    case .unsupported:
      code = .unsupported
    default:
      return unknownError(appCheckCoreError)
    }
    return NSError(domain: AppCheckErrorDomain, code: code.rawValue,
                   userInfo: appCheckCoreError.userInfo)
  }

  private static func unknownError(_ error: NSError) -> NSError {
    var userInfo: [String: Any] = [NSUnderlyingErrorKey: error]
    userInfo[NSLocalizedFailureReasonErrorKey] = error.userInfo[NSLocalizedFailureReasonErrorKey]
    return NSError(domain: AppCheckErrorDomain, code: AppCheckErrorCode.unknown.rawValue,
                   userInfo: userInfo)
  }
}
