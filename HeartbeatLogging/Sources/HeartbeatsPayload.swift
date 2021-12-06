// Copyright 2021 Google LLC
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

/// A type that provides a string representation for use in an HTTP header.
public protocol HTTPHeaderRepresentable {
  func headerValue() -> String
}

/// A value type representing a payload of heartbeat data intended for sending in network requests.
///
/// This type's structure is optimized for type-safe encoding into a HTTP payload format.
/// The intended encoding format for the current version is as follows:
///
///     {
///       "version": 2,
///       "heartbeats": [
///         {
///           "agent": "dummy_agent_1",
///           "dates": ["2021-11-01", "2021-11-02"]
///         },
///         {
///           "agent": "dummy_agent_2",
///           "dates": ["2021-11-03"]
///         }
///       ]
///     }
///
public struct HeartbeatsPayload: Codable {
  /// The version of the payload. See go/firebase-apple-heartbeats for details regarding current version.
  static let version: Int = 2

  /// A payload component composed of a user agent and array of dates (heartbeats).
  struct UserAgentPayload: Codable {
    /// An anonymous agent string.
    let agent: String
    // TODO: Check that backend makes no assumptions about ordering.
    /// An array of dates where each date represents a "heartbeat".
    let dates: [Date]
  }

  /// An array of user agent payloads.
  let userAgentPayloads: [UserAgentPayload]
  /// The version of the payload structure.
  let version: Int

  /// Alternative keys for properties so encoding follows platform-wide payload structure.
  enum CodingKeys: String, CodingKey {
    case userAgentPayloads = "heartbeats"
    case version
  }

  // TODO: Decide on version testing strategy.
  /// Designated initializer.
  /// - Parameters:
  ///   - userAgentPayloads: An array of payloads containing heartbeat data corresponding to a
  ///   given user agent.
  ///   - version: A  version of the payload. Defaults to the static default.
  init(userAgentPayloads: [UserAgentPayload] = [], version: Int = version) {
    self.userAgentPayloads = userAgentPayloads
    self.version = version
  }
}

// MARK: - HTTPHeaderRepresentable

extension HeartbeatsPayload: HTTPHeaderRepresentable {
  /// Returns a processed payload string intended for use in a HTTP header.
  /// - Returns: A string value from the heartbeats payload.
  public func headerValue() -> String {
    if userAgentPayloads.isEmpty {
      return ""
    }

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .formatted(Self.dateFormatter)

    guard let data = try? encoder.encode(self) else {
      // Return empty string if encoding failed.
      return ""
    }

    // TODO: Compress the payload before base64 encoding.
    // TODO: Confirm in e2e test if base64 URL safe string is needed.
    return data.base64EncodedString()
  }
}

// MARK: - Static Defaults

extension HeartbeatsPayload {
  /// Convenience instance that represents an empty payload.
  static let emptyPayload = HeartbeatsPayload()

  /// A default date formatter that uses `YYYY-MM-dd` format.
  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "YYYY-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()
}

// MARK: - Equatable

extension HeartbeatsPayload: Equatable {}
extension HeartbeatsPayload.UserAgentPayload: Equatable {}
