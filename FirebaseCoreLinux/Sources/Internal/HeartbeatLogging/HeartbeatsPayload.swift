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

/// A type that provides a string representation for use in an HTTP header.
public protocol HTTPHeaderRepresentable {
  func headerValue() -> String
}

public struct HeartbeatsPayload: Codable, Sendable {
  static let version: Int = 2

  struct UserAgentPayload: Codable, Equatable {
    let agent: String
    let dates: [Date]
  }

  let userAgentPayloads: [UserAgentPayload]
  let version: Int

  enum CodingKeys: String, CodingKey {
    case userAgentPayloads = "heartbeats"
    case version
  }

  init(userAgentPayloads: [UserAgentPayload] = [], version: Int = version) {
    self.userAgentPayloads = userAgentPayloads
    self.version = version
  }

  public var isEmpty: Bool {
    userAgentPayloads.isEmpty
  }
}

// MARK: - HTTPHeaderRepresentable

extension HeartbeatsPayload: HTTPHeaderRepresentable {
  public func headerValue() -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .formatted(Self.dateFormatter)
    #if DEBUG
      encoder.outputFormatting = .sortedKeys
    #endif

    guard let data = try? encoder.encode(self) else {
      return Self.emptyPayload.headerValue()
    }

    // GZIP compression removed for Linux compatibility (no GULNSData dependency).
    // Using simple Base64 URL encoding.
    return data.base64URLEncodedString()
  }
}

// MARK: - Static Defaults

extension HeartbeatsPayload {
  static let emptyPayload = HeartbeatsPayload()

  public static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()
}

// MARK: - Equatable

extension HeartbeatsPayload: Equatable {}

// MARK: - Data

public extension Data {
  func base64URLEncodedString(options: Data.Base64EncodingOptions = []) -> String {
    base64EncodedString()
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "=", with: "")
  }
}
