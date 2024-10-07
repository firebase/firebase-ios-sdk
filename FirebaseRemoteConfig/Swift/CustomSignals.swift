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

// TODO: Document.
public struct CustomSignal {
  private enum Kind {
    case string(String)
    case integer(Int)
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

  fileprivate func toNSObject() -> NSObject {
    switch kind {
    case let .string(string):
      return string as NSString
    case let .integer(int):
      return int as NSNumber
    }
  }
}

extension CustomSignal: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .string(value)
  }
}

extension CustomSignal: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self = .integer(value)
  }
}

public extension RemoteConfig {
  /// Sets custom signals for this Remote Config instance.
  /// - Parameter customSignals: A dictionary mapping string keys to custom
  /// signals to be set for the app instance.
  func setCustomSignals(_ customSignals: [String: CustomSignal]) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      let customSignals = customSignals.mapValues { $0.toNSObject() }
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
