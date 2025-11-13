// Copyright 2025 Google LLC
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

/// The model sent a message that the SDK failed to parse.
///
/// This may indicate that the SDK version needs updating, a model is too old for the current SDK
/// version, or that the model is just
/// not supported.
///
/// Check the `NSUnderlyingErrorKey` entry in ``LiveSessionUnsupportedMessageError/errorUserInfo``
/// for the error that caused this.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct LiveSessionUnsupportedMessageError: Error, Sendable, CustomNSError {
  let underlyingError: Error

  init(underlyingError: Error) {
    self.underlyingError = underlyingError
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "Failed to parse a live message from the model. Cause: \(underlyingError.localizedDescription)",
      NSUnderlyingErrorKey: underlyingError,
    ]
  }
}

/// The live session was closed, because the network connection was lost.
///
/// Check the `NSUnderlyingErrorKey` entry in ``LiveSessionLostConnectionError/errorUserInfo`` for
/// the error that caused this.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct LiveSessionLostConnectionError: Error, Sendable, CustomNSError {
  let underlyingError: Error

  init(underlyingError: Error) {
    self.underlyingError = underlyingError
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "The live session lost connection to the server. Cause: \(underlyingError.localizedDescription)",
      NSUnderlyingErrorKey: underlyingError,
    ]
  }
}

/// The live session was closed, but not for a reason the SDK expected.
///
/// Check the `NSUnderlyingErrorKey` entry in ``LiveSessionUnexpectedClosureError/errorUserInfo``
/// for the error that caused this.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct LiveSessionUnexpectedClosureError: Error, Sendable, CustomNSError {
  let underlyingError: WebSocketClosedError

  init(underlyingError: WebSocketClosedError) {
    self.underlyingError = underlyingError
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "The live session was closed for some unexpected reason. Cause: \(underlyingError.localizedDescription)",
      NSUnderlyingErrorKey: underlyingError,
    ]
  }
}

/// The model refused our request to setup a live session.
///
/// This can occur due to the model not supporting the requested response modalities, the project
/// not having access to the model, the model being invalid,  or some internal error.
///
/// Check the `NSUnderlyingErrorKey` entry in ``LiveSessionSetupError/errorUserInfo`` for the error
/// that caused this.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct LiveSessionSetupError: Error, Sendable, CustomNSError {
  let underlyingError: Error

  init(underlyingError: Error) {
    self.underlyingError = underlyingError
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "The model did not accept the live session request. Reason: \(underlyingError.localizedDescription)",
      NSUnderlyingErrorKey: underlyingError,
    ]
  }
}
