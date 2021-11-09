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
public struct HeartbeatsPayload: Codable, HTTPHeaderRepresentable {
  struct UserAgentPayload: Codable {
    let agent: String
    let dates: [String]
  }

  let payload: [UserAgentPayload]
  let version: Int

  static let version: Int = 0

  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "YYYY-MM-dd"
    return formatter
  }()

  static func makePayload(heartbeatInfo: HeartbeatInfo?) -> HeartbeatsPayload {
    guard let heartbeatInfo = heartbeatInfo else {
      // TODO: Revisit `version` handling.
      return HeartbeatsPayload(payload: [], version: version)
    }

    let agentsAndDates = heartbeatInfo.buffer.map { heartbeat in
      (heartbeat.agent, [heartbeat.date])
    }

    let payload: [UserAgentPayload] = [String: [Date]]
      .init(agentsAndDates, uniquingKeysWith: +)
      .map { agent, dates in
        UserAgentPayload(
          agent: agent,
          dates: dates.map(dateFormatter.string(from:))
        )
      }

    // TODO: Revisit `version` handling.
    return HeartbeatsPayload(payload: payload, version: version)
  }

  // MARK: - HTTPHeaderRepresentable

  public func headerValue() -> String {
    // TODO: Evaluate if it makes sense to return empty string when payload is empty.
    guard !payload.isEmpty else {
      return "" // Return empty string if `payload` value is empty.
    }

    let encodeResult = Result { try JSONCoder().encode(self) }

    switch encodeResult {
    case let .success(data): return data.base64EncodedString()
    case .failure: return "" // Return empty string if encoding failed.
    }
  }
}
