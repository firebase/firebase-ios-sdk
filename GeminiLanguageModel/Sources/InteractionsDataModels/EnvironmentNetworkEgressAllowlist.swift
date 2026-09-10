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

package import GeminiSharedDataModels

package struct EnvironmentNetworkEgressAllowlistConfig: Codable, Sendable, Equatable, Hashable {
  package let allowlist: [AllowlistEntry]?
  package init(allowlist: [AllowlistEntry]?) {
    self.allowlist = allowlist
  }
}

/// Outbound networking configuration for the sandbox. Accepts an object with an 'allowlist' array to restrict traffic, or the string 'disabled' to turn off all network access. Omit entirely to allow all outbound traffic with no header injection.
package enum EnvironmentNetworkEgressAllowlist: Codable, Sendable, Equatable, Hashable {

  case allowlist(EnvironmentNetworkEgressAllowlistConfig)
  case disabled(String)

  package init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let val = try? container.decode(EnvironmentNetworkEgressAllowlistConfig.self) {
      self = .allowlist(val)
      return
    }
    if let val = try? container.decode(String.self) {
      self = .disabled(val)
      return
    }
    throw DecodingError.typeMismatch(
      EnvironmentNetworkEgressAllowlist.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription:
          "Failed to decode any of the variants for EnvironmentNetworkEgressAllowlist"
      )
    )
  }

  package func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .allowlist(let val):
      try container.encode(val)
    case .disabled(let val):
      try container.encode(val)
    }
  }
}
