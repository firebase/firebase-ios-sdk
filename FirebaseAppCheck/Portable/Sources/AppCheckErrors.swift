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

public import Foundation

/// **[Experimental]** The Firebase App Check error domain.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public let AppCheckErrorDomain: String = "com.firebase.appCheck"

/// **[Experimental]** Error codes returned by Firebase App Check.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public enum AppCheckErrorCode: Int, Error, Sendable, CustomNSError {
  /// **[Experimental]** An unknown or non-actionable error.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case unknown = 0

  /// **[Experimental]** A network connection error.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case serverUnreachable = 1

  /// **[Experimental]** Invalid configuration error.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case invalidConfiguration = 2

  /// **[Experimental]** System keychain access error.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case keychain = 3

  /// **[Experimental]** Selected app attestation provider is not supported on the current platform
  /// or OS version.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case unsupported = 4

  /// **[Experimental]** The domain of the error.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public static var errorDomain: String {
    AppCheckErrorDomain
  }

  /// **[Experimental]** The error code within the given domain.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var errorCode: Int {
    rawValue
  }

  /// **[Experimental]** The user-info dictionary for the error.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var errorUserInfo: [String: Any] {
    [:]
  }
}

/// Internal utilities for constructing `FirebaseAppCheck` errors.
package enum AppCheckErrorUtil {
  /// Creates an `NSError` in `AppCheckErrorDomain` with the specified code and description.
  package static func error(code: AppCheckErrorCode,
                            message: String,
                            underlyingError: (any Error)? = nil) -> NSError {
    var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return NSError(domain: AppCheckErrorDomain, code: code.rawValue, userInfo: userInfo)
  }
}
