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

/// A type that can be represented as an HTTP header.
public protocol HTTPHeaderRepresentable {
  func headerValue() -> String
}

// TODO: Add documentation.
public struct HeartbeatsPayload: Codable {
  static let version: Int = 2

  struct UserAgentPayload: Codable {
    let agent: String
    let dates: [Date]
  }

  let heartbeats: [UserAgentPayload]
  let version: Int

  init(heartbeats: [UserAgentPayload], version: Int = version) {
    self.heartbeats = heartbeats
    self.version = version
  }
}

// MARK: - HTTPHeaderRepresentable

extension HeartbeatsPayload: HTTPHeaderRepresentable {
  public func headerValue() -> String {
    // TODO: Should we return empty string when payload is empty?
    guard !heartbeats.isEmpty else {
      return ""
    }

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .formatted(Self.dateFormatter)

    if let data = try? encoded(using: encoder) {
      return data.base64EncodedString()
    } else {
      return "" // Return empty string if encoding failed.
    }
  }
}

// MARK: - Defaults

extension HeartbeatsPayload {
  static let emptyPayload = HeartbeatsPayload(heartbeats: [])

  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "YYYY-MM-dd"
    return formatter
  }()
}

// MARK: - Equatable

extension HeartbeatsPayload: Equatable {}
extension HeartbeatsPayload.UserAgentPayload: Equatable {}
