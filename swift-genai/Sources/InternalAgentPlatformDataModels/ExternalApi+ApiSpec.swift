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

extension AgentPlatform.ExternalApi {
  /// The API spec that the external API implements.
  public enum ApiSpec: Codable, Sendable, Equatable, Hashable {
    /// Simple search API spec.
    case simpleSearch
    
    /// Elastic search API spec.
    case elasticSearch
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.ExternalApi.ApiSpec: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .simpleSearch: "SIMPLE_SEARCH"
    case .elasticSearch: "ELASTIC_SEARCH"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "SIMPLE_SEARCH": self = .simpleSearch
    case "ELASTIC_SEARCH": self = .elasticSearch
    default: self = .unrecognized(rawValue)
    }
  }
}