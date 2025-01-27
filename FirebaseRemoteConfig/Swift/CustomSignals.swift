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
#if SWIFT_PACKAGE
  @_exported import FirebaseRemoteConfigInternal
#endif // SWIFT_PACKAGE

/// Represents a value associated with a key in a custom signal, restricted to the allowed data
/// types : String, Int, Double.
public struct CustomSignalValue {
  private enum Kind {
    case string(String)
    case integer(Int)
    case double(Double)
  }

  private let kind: Kind

  private init(kind: Kind) {
    self.kind = kind
  }

  /// Returns a string backed custom signal.
  /// - Parameter string: The given string to back the custom signal with.
  /// - Returns: A string backed custom signal.
  public static func string(_ string: String) -> Self {
    Self(kind: .string(string))
  }

  /// Returns an integer backed custom signal.
  /// - Parameter integer: The given integer to back the custom signal with.
  /// - Returns: An integer backed custom signal.
  public static func integer(_ integer: Int) -> Self {
    Self(kind: .integer(integer))
  }

  /// Returns an floating-point backed custom signal.
  /// - Parameter double: The given floating-point value to back the custom signal with.
  /// - Returns: An floating-point backed custom signal
  public static func double(_ double: Double) -> Self {
    Self(kind: .double(double))
  }

  fileprivate func toNSObject() -> NSObject {
    switch kind {
    case let .string(string):
      return string as NSString
    case let .integer(int):
      return int as NSNumber
    case let .double(double):
      return double as NSNumber
    }
  }
}

extension CustomSignalValue: ExpressibleByStringInterpolation {
  public init(stringLiteral value: String) {
    self = .string(value)
  }
}

extension CustomSignalValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self = .integer(value)
  }
}

extension CustomSignalValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .double(value)
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public extension RemoteConfig {
  /// Sets custom signals for this Remote Config instance.
  /// - Parameter customSignals: A dictionary mapping string keys to custom
  /// signals to be set for the app instance.
  ///
  /// When a new key is provided, a new key-value pair is added to the custom signals.
  /// If an existing key is provided with a new value, the corresponding signal is updated.
  /// If the value for a key is `nil`, the signal associated with that key is removed.
  func setCustomSignals(_ customSignals: [String: CustomSignalValue?]) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      let customSignals = customSignals.mapValues { $0?.toNSObject() ?? NSNull() }
      self.__setCustomSignals(customSignals) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }
}
